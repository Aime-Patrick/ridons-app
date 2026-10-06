import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OS location + notification prompts for the passenger home map.
///
/// Never invents a city. Uses the device/emulator GPS fix, with an optional
/// last-known cache so cold start is not blank while a fresh fix arrives.
class LocationService {
  static const _latKey = 'ridons.last_lat';
  static const _lngKey = 'ridons.last_lng';
  static const _driverOnlineKey = 'ridons.driver_online_intent';

  /// Returns the best available speed for a GPS fix.
  ///
  /// Some devices report 0 even while moving. In that case derive speed from
  /// the previous fix, but reject stale fixes and GPS jitter.
  static double speedKmh(Position current, Position? previous) {
    final reported = current.speed;
    if (reported.isFinite && reported > 0.5) {
      return (reported * 3.6).clamp(0.0, 160.0).toDouble();
    }
    if (previous == null) return 0;
    if (!current.accuracy.isFinite ||
        !previous.accuracy.isFinite ||
        current.accuracy > 100 ||
        previous.accuracy > 100) {
      return 0;
    }

    final seconds =
        current.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (seconds <= 0 || seconds > 30) return 0;

    final distanceKm = _haversineKm(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final derived = distanceKm / seconds * 3600;
    if (derived < 0.5) return 0;
    return math.min(derived, 160.0);
  }

  Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureLocationPermission({bool background = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return false;
      }
      if (background && permission != LocationPermission.always) {
        final always = await Permission.locationAlways.request();
        if (!always.isGranted) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotifications() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isProvisional;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> lastKnownPosition() async {
    try {
      final live = await Geolocator.getLastKnownPosition();
      if (live != null) {
        await remember(live.latitude, live.longitude);
        return live;
      }
    } catch (_) {}
    return _cachedPosition();
  }

  Future<Position?> currentPosition({bool allowLastKnown = true}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings(timeLimit: const Duration(seconds: 15)),
      );
      await remember(position.latitude, position.longitude);
      return position;
    } catch (_) {
      return allowLastKnown ? lastKnownPosition() : null;
    }
  }

  /// Returns only a fresh OS fix. Callers that need a visual fallback should
  /// request [lastKnownPosition] explicitly so stale coordinates are never
  /// mistaken for a live position.
  Future<Position?> freshPosition() => currentPosition(allowLastKnown: false);

  Stream<Position> positionStream({bool background = false}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(
        distanceFilter: background ? 5 : 1,
        background: background,
      ),
    ).map((position) {
      // Persistence must not delay the live location stream delivered to the
      // map and presence publisher.
      unawaited(remember(position.latitude, position.longitude));
      return position;
    });
  }

  Future<void> remember(double latitude, double longitude) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, latitude);
      await prefs.setDouble(_lngKey, longitude);
    } catch (_) {}
  }

  Future<void> setDriverOnlineIntent(bool online) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_driverOnlineKey, online);
    } catch (_) {}
  }

  Future<bool> driverOnlineIntent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_driverOnlineKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> _cachedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      if (lat == null || lng == null) return null;
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 50,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return null;
    }
  }

  LocationSettings _settings({
    Duration? timeLimit,
    int distanceFilter = 0,
    bool background = false,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        intervalDuration: Duration(seconds: background ? 4 : 1),
        forceLocationManager: false,
        timeLimit: timeLimit,
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Ridons driver mode',
                notificationText:
                    'Your live location is active while you are online.',
                notificationChannelName: 'Ridons driver location',
                enableWakeLock: true,
                enableWifiLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final radians = math.pi / 180;
    final dLat = (lat2 - lat1) * radians;
    final dLng = (lng2 - lng1) * radians;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * radians) *
            math.cos(lat2 * radians) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(a));
  }
}
