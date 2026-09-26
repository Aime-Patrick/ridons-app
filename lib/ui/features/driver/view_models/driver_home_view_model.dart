import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/geo_api.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/places_service.dart';
import '../../../../data/services/realtime_client.dart';
import '../../../../data/services/routing_service.dart';
import '../../../../data/services/trip_api.dart';
import '../../../../domain/models/geo_place.dart';
import '../../../../domain/models/fare_policy.dart';
import '../../../../domain/models/ride_offer.dart';
import '../../../../domain/models/session_user.dart';

enum DriverStage { home, locked, arrived, driving }

const _pickupArrivalRadiusM = 60.0;
const _journeyStartSpeedKmh = 5.0;

class DriverHomeViewModel extends ChangeNotifier {
  DriverHomeViewModel({
    required LocationService locationService,
    required PlacesService placesService,
    required RoutingService routingService,
    required GeoApi geoApi,
    required TripApi tripApi,
    required RealtimeClient realtime,
    required AuthRepository authRepository,
    required this.user,
    required this.onSessionRefreshed,
  }) : _location = locationService,
       _places = placesService,
       _routing = routingService,
       _geo = geoApi,
       _trips = tripApi,
       _realtime = realtime,
       _auth = authRepository;

  final LocationService _location;
  final PlacesService _places;
  final RoutingService _routing;
  final GeoApi _geo;
  final TripApi _trips;
  final RealtimeClient _realtime;
  final AuthRepository _auth;
  final SessionUser user;
  final void Function(AuthSession session) onSessionRefreshed;

  DriverStage stage = DriverStage.home;
  bool online = false;
  bool onlineBusy = false;
  bool hideEarnings = true;
  bool busy = false;
  String? errorMessage;
  DriverStats stats = const DriverStats();
  List<DriverQuest> quests = const [];
  List<RideOffer> offers = const [];
  final Map<String, int> localFares = {};
  ActiveRide? ride;
  List<LatLng> routePoints = const [];
  int? etaMinutes;
  LatLng? driverPoint;
  LatLng? passengerPoint;
  double passengerSpeedKmh = 0;
  Position? _fix;

  Timer? _inboxPoll;
  Timer? _pingTimer;
  bool _inboxRefreshing = false;
  bool _statusBusy = false;
  StreamSubscription<Position>? _gps;
  StreamSubscription<RealtimeMessage>? _ws;

  bool get onTrip => stage != DriverStage.home;

  String get etaChip {
    final minutes = etaMinutes;
    if (minutes == null) return 'On the way';
    return '$minutes min to pickup';
  }

  int fareFor(RideOffer offer) =>
      FarePolicy.normalize(localFares[offer.requestId] ?? offer.offeredPrice);

  Future<void> bootstrap() async {
    await _location.ensureLocationPermission();
    _fix =
        await _location.freshPosition() ?? await _location.lastKnownPosition();
    if (_fix != null) {
      driverPoint = LatLng(_fix!.latitude, _fix!.longitude);
    }
    stats = await _trips.stats();
    quests = await _trips.quests();
    final active = await _trips.activeRide();
    if (active != null && active.rideId.isNotEmpty) {
      await _enterRide(active);
    }
    _ws = _realtime.messages.listen(_onRealtime);
    unawaited(_realtime.connect());
    unawaited(_realtime.subscribe('driver:${user.id}'));
    _startGpsTracking(background: onTrip);
    final shouldResumeOnline = await _location.driverOnlineIntent();
    if (shouldResumeOnline) {
      await toggleOnline(true);
    }
    notifyListeners();
  }

  void _startGpsTracking({required bool background}) {
    _gps?.cancel();
    _gps = _location.positionStream(background: background).listen((position) {
      _fix = position;
      driverPoint = LatLng(position.latitude, position.longitude);
      if (online || onTrip) {
        unawaited(
          _geo.ping(
            lat: position.latitude,
            lng: position.longitude,
            headingDeg: position.heading.isFinite ? position.heading : 0,
            speedKmh: position.speed.isFinite ? position.speed * 3.6 : 0,
            rideId: ride?.rideId,
          ),
        );
      }
      _maybeDetectTripProgress(
        position.speed.isFinite ? position.speed * 3.6 : 0,
      );
      notifyListeners();
    });
  }

  Future<void> toggleOnline(bool value) async {
    if (onlineBusy || value == online) return;
    final previous = online;
    onlineBusy = true;
    online = value;
    errorMessage = null;
    notifyListeners();
    try {
      if (value) {
        final backgroundReady = await _location.ensureLocationPermission(
          background: true,
        );
        if (!backgroundReady) {
          online = previous;
          errorMessage = 'Allow background location to stay online.';
          return;
        }
        await _location.requestNotifications();
      }
      // Do not go online using the bootstrap/last-known fix when a fresh GPS
      // reading is available. The first presence coordinate is user-visible.
      final fix = await _location.freshPosition() ?? _fix;
      if (value && fix == null) {
        online = previous;
        errorMessage = 'Turn on location to go online.';
        return;
      }
      var error = await _geo.setOnline(
        online: value,
        lat: fix?.latitude,
        lng: fix?.longitude,
      );

      // If verification required, try refreshing the token — documents may
      // have been approved since the current JWT was issued.
      if (error == 'verification_required' && value) {
        final refreshed = await _auth.refreshSession();
        if (refreshed != null) {
          onSessionRefreshed(refreshed);
          error = await _geo.setOnline(
            online: value,
            lat: fix?.latitude,
            lng: fix?.longitude,
          );
        }
      }

      if (error != null) {
        online = previous;
        switch (error) {
          case 'verification_required':
            errorMessage = 'Your documents need admin approval.';
            break;
          case 'unauthorized':
            errorMessage = 'Session expired. Please log in again.';
            break;
          default:
            errorMessage = 'Could not update online status.';
        }
        notifyListeners();
        return;
      }
      online = value;
      errorMessage = null;
      await _location.setDriverOnlineIntent(value);
      _startGpsTracking(background: value || onTrip);
      if (online) {
        _inboxPoll?.cancel();
        _inboxPoll = Timer.periodic(const Duration(seconds: 4), (_) {
          unawaited(refreshInbox());
        });
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          final pos = _fix;
          if (pos == null) return;
          unawaited(
            _geo.ping(
              lat: pos.latitude,
              lng: pos.longitude,
              headingDeg: pos.heading.isFinite ? pos.heading : 0,
              speedKmh: pos.speed.isFinite ? pos.speed * 3.6 : 0,
              rideId: ride?.rideId,
            ),
          );
        });
        unawaited(refreshInbox());
      } else {
        _inboxPoll?.cancel();
        _pingTimer?.cancel();
        offers = const [];
      }
    } finally {
      onlineBusy = false;
      notifyListeners();
    }
  }

  void toggleEarningsHidden() {
    hideEarnings = !hideEarnings;
    notifyListeners();
  }

  Future<void> refreshInbox() async {
    if (!online || onTrip || _inboxRefreshing) return;
    _inboxRefreshing = true;
    try {
      final next = await _trips.inbox();
      for (final offer in next) {
        if (offer.fromName.isEmpty) {
          final place = await _places.reverse(
            offer.from.latitude,
            offer.from.longitude,
          );
          offer.fromName = place.name;
        }
        if (offer.toName.isEmpty) {
          final place = await _places.reverse(
            offer.to.latitude,
            offer.to.longitude,
          );
          offer.toName = place.name;
        }
        if (offer.suggestedPrice <= 0) {
          offer.suggestedPrice = _routing.suggestFare(
            GeoPlace(
              name: offer.fromName,
              latitude: offer.from.latitude,
              longitude: offer.from.longitude,
            ),
            GeoPlace(
              name: offer.toName,
              latitude: offer.to.latitude,
              longitude: offer.to.longitude,
            ),
          );
        }
      }
      offers = next;
    } catch (_) {
      if (online && !onTrip) {
        errorMessage = 'Could not load offers. We will keep trying.';
      }
    } finally {
      _inboxRefreshing = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: clear sticky errors and reload stats / offers / active ride.
  Future<void> reload() async {
    errorMessage = null;
    notifyListeners();
    try {
      stats = await _trips.stats();
      quests = await _trips.quests();
      final active = await _trips.activeRide();
      if (active != null && active.rideId.isNotEmpty) {
        await _enterRide(active);
        return;
      }
      if (online) {
        await refreshInbox();
      }
    } catch (_) {
      errorMessage = 'Could not refresh. Pull down to try again.';
    }
    notifyListeners();
  }

  void adjustFare(RideOffer offer, int delta) {
    final current = fareFor(offer);
    localFares[offer.requestId] = FarePolicy.normalize(current + delta);
    notifyListeners();
  }

  Future<void> skip(RideOffer offer) async {
    await _trips.decline(offer.requestId);
    offers = offers.where((item) => item.requestId != offer.requestId).toList();
    notifyListeners();
  }

  Future<void> accept(RideOffer offer) async {
    if (busy) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final price = fareFor(offer);
      if (price > offer.offeredPrice) {
        await _trips.counter(
          offer.requestId,
          price,
          driverName: user.displayName,
          vehiclePlate: user.vehiclePlate ?? '',
          driverRating: stats.avgRating,
        );
        busy = false;
        errorMessage = 'Counter sent. Waiting for the passenger.';
        notifyListeners();
        return;
      }
      final locked = await _trips.accept(
        offer.requestId,
        driverName: user.displayName,
        vehiclePlate: user.vehiclePlate ?? '',
        driverRating: stats.avgRating,
      );
      if (locked.rideId.isEmpty) {
        throw StateError('missing ride');
      }
      await _enterRide(
        ActiveRide(
          rideId: locked.rideId,
          requestId: offer.requestId,
          passengerId: offer.passengerId,
          status: locked.status,
          fare: locked.fare == 0 ? offer.offeredPrice : locked.fare,
          from: offer.from,
          to: offer.to,
          paymentMethod: offer.paymentMethod,
          passengerName: offer.displayName,
          passengerPhone: offer.passengerPhone,
          fromName: offer.fromName,
          toName: offer.toName,
        ),
      );
    } catch (_) {
      errorMessage = 'Offer was taken or expired.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> startTrip() async {
    final current = ride;
    if (current == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      if (stage == DriverStage.driving) return;
      await _setRideStatus(
        stage == DriverStage.arrived ? 'in_progress' : 'en_route',
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> cancelTrip() async {
    final current = ride;
    if (current == null) return;
    await _trips.cancelRide(current.rideId);
    ride = null;
    stage = DriverStage.home;
    routePoints = const [];
    if (online) await refreshInbox();
    notifyListeners();
  }

  Future<void> _enterRide(ActiveRide next) async {
    ride = next;
    passengerPoint = null;
    passengerSpeedKmh = 0;
    offers = const [];
    stage = next.isDriving ? DriverStage.driving : DriverStage.locked;
    if (next.status == 'matched') {
      try {
        await _trips.updateStatus(next.rideId, 'en_route');
        ride = _withStatus(next, 'en_route');
      } catch (_) {}
    }
    await _realtime.subscribe('ride:${next.rideId}');
    await _refreshRoute(toDropoff: next.isDriving);
    final origin = driverPoint ?? next.from;
    final dest = next.isDriving ? next.to : next.from;
    final quote = await _geo.pickupEta(driver: origin, pickup: dest);
    etaMinutes = quote?.minutes;
  }

  Future<void> _refreshRoute({required bool toDropoff}) async {
    final current = ride;
    if (current == null) return;
    final start = driverPoint ?? current.from;
    final end = toDropoff ? current.to : current.from;
    final result = await _routing.route(
      GeoPlace(
        name: 'You',
        latitude: start.latitude,
        longitude: start.longitude,
      ),
      GeoPlace(
        name: toDropoff ? current.toName : current.fromName,
        latitude: end.latitude,
        longitude: end.longitude,
      ),
    );
    routePoints = result.points;
    if (result.durationMin > 0) {
      etaMinutes = result.durationMin;
    }
    notifyListeners();
  }

  void _onRealtime(RealtimeMessage message) {
    if (message.event == 'incoming_request' && online && !onTrip) {
      unawaited(refreshInbox());
    }
    if (message.event == 'status') {
      final status = '${message.data['status'] ?? ''}';
      final current = ride;
      if (current != null && (status == 'arrived' || status == 'in_progress')) {
        ride = _withStatus(current, status);
        stage = status == 'in_progress'
            ? DriverStage.driving
            : DriverStage.arrived;
        if (status == 'in_progress') {
          unawaited(_refreshRoute(toDropoff: true));
        }
        notifyListeners();
      }
      if (status == 'cancelled') {
        ride = null;
        stage = DriverStage.home;
        notifyListeners();
      }
    }
    if (message.event == 'location' &&
        '${message.data['role'] ?? ''}'.toLowerCase() == 'passenger') {
      final current = ride;
      if (current == null ||
          '${message.data['rideId'] ?? ''}' != current.rideId) {
        return;
      }
      final coords = message.data['coords'];
      if (coords is! List || coords.length < 2) return;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      passengerPoint = LatLng(lat, lng);
      passengerSpeedKmh = (message.data['speedKmh'] as num?)?.toDouble() ?? 0;
      final driverSpeed = _fix?.speed;
      _maybeDetectTripProgress(
        driverSpeed != null && driverSpeed.isFinite ? driverSpeed * 3.6 : 0,
      );
      notifyListeners();
    }
  }

  Future<void> _maybeDetectTripProgress(double speedKmh) async {
    final current = ride;
    final driver = driverPoint;
    final passenger = passengerPoint;
    if (current == null || driver == null || passenger == null || _statusBusy) {
      return;
    }
    final distance = _distanceMeters(driver, passenger);
    if (stage == DriverStage.locked &&
        current.status == 'en_route' &&
        distance <= _pickupArrivalRadiusM) {
      await _setRideStatus('arrived');
      return;
    }
    if (stage == DriverStage.arrived &&
        speedKmh >= _journeyStartSpeedKmh &&
        passengerSpeedKmh >= _journeyStartSpeedKmh) {
      await _setRideStatus('in_progress');
    }
  }

  Future<void> _setRideStatus(String status) async {
    final current = ride;
    if (current == null || _statusBusy) return;
    _statusBusy = true;
    try {
      await _trips.updateStatus(current.rideId, status);
      ride = _withStatus(current, status);
      stage = status == 'in_progress'
          ? DriverStage.driving
          : status == 'arrived'
          ? DriverStage.arrived
          : DriverStage.locked;
      if (status == 'in_progress') {
        await _refreshRoute(toDropoff: true);
      }
      notifyListeners();
    } finally {
      _statusBusy = false;
    }
  }

  ActiveRide _withStatus(ActiveRide current, String status) {
    return ActiveRide(
      rideId: current.rideId,
      requestId: current.requestId,
      passengerId: current.passengerId,
      status: status,
      fare: current.fare,
      from: current.from,
      to: current.to,
      paymentMethod: current.paymentMethod,
      passengerName: current.passengerName,
      passengerPhone: current.passengerPhone,
      fromName: current.fromName,
      toName: current.toName,
    );
  }

  @override
  void dispose() {
    _inboxPoll?.cancel();
    _pingTimer?.cancel();
    _gps?.cancel();
    _ws?.cancel();
    if (online) {
      unawaited(_geo.setOnline(online: false));
    }
    unawaited(_location.setDriverOnlineIntent(false));
    super.dispose();
  }
}

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadiusM = 6371000.0;
  const degreesToRadians = 3.141592653589793 / 180;
  final dLat = (b.latitude - a.latitude) * degreesToRadians;
  final dLng = (b.longitude - a.longitude) * degreesToRadians;
  final lat1 = a.latitude * degreesToRadians;
  final lat2 = b.latitude * degreesToRadians;
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(h));
}
