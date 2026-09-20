import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/geo_place.dart';

/// Road geometry + metrics from OSRM (OpenStreetMap).
///
/// Optimizations vs the public demo defaults:
/// - Encoded polyline (smaller than GeoJSON)
/// - In-memory TTL cache (rounded coords)
/// - CancelToken to drop stale in-flight requests
/// - Alternatives + turn steps when available
///
/// Profile is **driving** (road ETA). Self-host a Rwanda extract and set
/// [osrmBaseUrl] for production speed; optional motorcycle profile later.
class RoutingService {
  RoutingService({
    Dio? dio,
    String? osrmBaseUrl,
    this.profile = 'driving',
    this.cacheTtl = const Duration(minutes: 8),
    this.maxCacheEntries = 48,
  })  : _osrmBase =
            (osrmBaseUrl ?? defaultOsrmBase).replaceAll(RegExp(r'/+$'), ''),
        _dio = dio ??
            Dio(
              BaseOptions(
                // Public demo often takes 4–8s from emulators; don't cut early.
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 12),
                headers: {
                  'User-Agent': 'Ridons/1.0 (passenger app; https://ridons.app)',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Public OSRM demo — fine for local/dev; replace in prod.
  static const defaultOsrmBase = 'https://router.project-osrm.org';

  final Dio _dio;
  final String _osrmBase;
  final String profile;
  final Duration cacheTtl;
  final int maxCacheEntries;
  static const _distance = Distance();

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  CancelToken? _inflight;

  /// Cancels any in-flight [route] call (e.g. user changed dropoff).
  void cancelInFlight() {
    _inflight?.cancel('stale');
    _inflight = null;
  }

  Future<RouteResult> route(
    GeoPlace from,
    GeoPlace to, {
    bool alternatives = true,
    bool steps = false,
    CancelToken? cancelToken,
  }) async {
    final key = _cacheKey(from, to, alternatives: alternatives, steps: steps);
    final hit = _cache[key];
    if (hit != null && !hit.expired) {
      _cache.remove(key);
      _cache[key] = hit;
      return hit.result;
    }

    cancelInFlight();
    final token = cancelToken ?? CancelToken();
    _inflight = token;

    try {
      final result = await _fetchRoute(
        from,
        to,
        alternatives: alternatives,
        steps: steps,
        token: token,
      );
      if (result != null) {
        _putCache(key, result);
        return result;
      }
      // One retry without alternatives (lighter payload).
      if (alternatives && !token.isCancelled) {
        final retry = await _fetchRoute(
          from,
          to,
          alternatives: false,
          steps: false,
          token: token,
        );
        if (retry != null) {
          _putCache(key, retry);
          return retry;
        }
      }
      return _straight(from, to);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        rethrow;
      }
      debugPrint('OSRM route failed: ${e.type} ${e.message}');
      return _straight(from, to);
    } catch (e) {
      debugPrint('OSRM route error: $e');
      return _straight(from, to);
    } finally {
      if (identical(_inflight, token)) {
        _inflight = null;
      }
    }
  }

  Future<RouteResult?> _fetchRoute(
    GeoPlace from,
    GeoPlace to, {
    required bool alternatives,
    required bool steps,
    required CancelToken token,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_osrmBase/route/v1/$profile/'
      '${_fmt(from.longitude)},${_fmt(from.latitude)};'
      '${_fmt(to.longitude)},${_fmt(to.latitude)}',
      queryParameters: {
        'overview': 'full',
        'geometries': 'polyline',
        'alternatives': alternatives ? 'true' : 'false',
        'steps': steps ? 'true' : 'false',
        'annotations': 'false',
      },
      cancelToken: token,
    );
    final routes = response.data?['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final parsed = <RouteResult>[];
    for (final raw in routes) {
      if (raw is! Map) continue;
      final one = _parseRoute(Map<String, dynamic>.from(raw));
      if (one != null) parsed.add(one);
    }
    if (parsed.isEmpty) return null;

    parsed.sort((a, b) {
      final byTime = a.durationMin.compareTo(b.durationMin);
      if (byTime != 0) return byTime;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return parsed.first.copyWith(
      alternatives: parsed.skip(1).toList(growable: false),
      method: 'osrm_$profile',
    );
  }

  /// Instant estimate while OSRM loads (haversine × 1.25 @ 22 km/h).
  RouteResult estimateQuick(GeoPlace from, GeoPlace to) => _straight(from, to);

  /// Straight-line km (fallback only). Prefer [RouteResult.distanceKm].
  double kilometers(GeoPlace from, GeoPlace to) {
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(from.latitude, from.longitude),
      LatLng(to.latitude, to.longitude),
    );
  }

  /// Suggested offer from **road** km when available.
  int suggestFareFromKm(double distanceKm) {
    final raw = 1500 + distanceKm * 120;
    return ((raw / 50).round() * 50).clamp(800, 50000).toInt();
  }

  /// Sync suggest using haversine — prefer [suggestFareFromKm] after route().
  int suggestFare(GeoPlace from, GeoPlace to) {
    return suggestFareFromKm(kilometers(from, to));
  }

  RouteResult? _parseRoute(Map<String, dynamic> map) {
    final meters = (map['distance'] as num?)?.toDouble();
    final seconds = (map['duration'] as num?)?.toDouble();
    final geometry = map['geometry'];
    List<LatLng>? coords;
    if (geometry is String && geometry.isNotEmpty) {
      coords = decodePolyline(geometry);
    } else if (geometry is Map) {
      coords = ((geometry['coordinates'] as List?) ?? const [])
          .whereType<List>()
          .map(
            (pair) => LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ),
          )
          .toList();
    }
    if (coords == null || coords.length < 2 || meters == null) {
      return null;
    }
    final km = meters / 1000.0;
    final minutes = seconds == null
        ? _minutesFromKm(km)
        : (seconds / 60.0).round().clamp(1, 24 * 60);
    return RouteResult(
      points: coords,
      distanceKm: _roundKm(km),
      durationMin: minutes,
      method: 'osrm_$profile',
      steps: _parseSteps(map['legs']),
    );
  }

  List<RouteStep> _parseSteps(dynamic legs) {
    if (legs is! List) return const [];
    final out = <RouteStep>[];
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final maneuver = step['maneuver'];
        final loc = maneuver is Map ? maneuver['location'] : null;
        LatLng? point;
        if (loc is List && loc.length >= 2) {
          point = LatLng(
            (loc[1] as num).toDouble(),
            (loc[0] as num).toDouble(),
          );
        }
        final type = maneuver is Map ? '${maneuver['type'] ?? ''}' : '';
        final modifier =
            maneuver is Map ? '${maneuver['modifier'] ?? ''}' : '';
        final name = '${step['name'] ?? ''}'.trim();
        final instruction = [
          if (type.isNotEmpty) type,
          if (modifier.isNotEmpty) modifier,
          if (name.isNotEmpty) name,
        ].join(' ').trim();
        out.add(
          RouteStep(
            instruction: instruction.isEmpty ? 'continue' : instruction,
            distanceM: (step['distance'] as num?)?.toDouble() ?? 0,
            durationS: (step['duration'] as num?)?.toDouble() ?? 0,
            location: point,
          ),
        );
      }
    }
    return List.unmodifiable(out);
  }

  RouteResult _straight(GeoPlace from, GeoPlace to) {
    final km = kilometers(from, to);
    final roadish = km * 1.25;
    return RouteResult(
      points: [
        LatLng(from.latitude, from.longitude),
        LatLng(to.latitude, to.longitude),
      ],
      distanceKm: _roundKm(roadish),
      durationMin: _minutesFromKm(roadish),
      method: 'haversine_fallback',
    );
  }

  int _minutesFromKm(double km) {
    const speedKmh = 22.0;
    return (km / speedKmh * 60).round().clamp(1, 24 * 60);
  }

  double _roundKm(double km) => (km * 10).round() / 10.0;

  String _fmt(double v) => v.toStringAsFixed(6);

  String _cacheKey(
    GeoPlace from,
    GeoPlace to, {
    required bool alternatives,
    required bool steps,
  }) {
    // ~11 m grid — enough for cache hits while dragging the pin slightly.
    String q(double v) => (v * 1e4).round().toString();
    return '$profile|'
        '${q(from.latitude)},${q(from.longitude)}|'
        '${q(to.latitude)},${q(to.longitude)}|'
        'a${alternatives ? 1 : 0}s${steps ? 1 : 0}';
  }

  void _putCache(String key, RouteResult result) {
    _cache.remove(key);
    _cache[key] = _CacheEntry(result, DateTime.now().add(cacheTtl));
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Geographic point halfway along [points] by road length.
  static LatLng? midpointAlong(List<LatLng> points) {
    if (points.length < 2) return null;
    const distance = Distance();
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += distance(points[i - 1], points[i]);
    }
    if (total <= 0) return points[points.length ~/ 2];
    final half = total / 2;
    var acc = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final seg = distance(a, b);
      if (acc + seg >= half) {
        final t = seg <= 0 ? 0.0 : (half - acc) / seg;
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      acc += seg;
    }
    return points.last;
  }

  /// Google-encoded polyline → [LatLng] list (OSRM default encoding).
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class _CacheEntry {
  _CacheEntry(this.result, this.expiresAt);

  final RouteResult result;
  final DateTime expiresAt;

  bool get expired => DateTime.now().isAfter(expiresAt);
}

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    this.location,
  });

  final String instruction;
  final double distanceM;
  final double durationS;
  final LatLng? location;
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    this.method = 'osrm_driving',
    this.steps = const [],
    this.alternatives = const [],
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  final String method;
  final List<RouteStep> steps;
  final List<RouteResult> alternatives;

  int get suggestedFare {
    final raw = 1500 + distanceKm * 120;
    return ((raw / 50).round() * 50).clamp(800, 50000).toInt();
  }

  LatLng? get midpoint => RoutingService.midpointAlong(points);

  RouteResult copyWith({
    List<LatLng>? points,
    double? distanceKm,
    int? durationMin,
    String? method,
    List<RouteStep>? steps,
    List<RouteResult>? alternatives,
  }) {
    return RouteResult(
      points: points ?? this.points,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      method: method ?? this.method,
      steps: steps ?? this.steps,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}
