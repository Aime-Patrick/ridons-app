import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../domain/models/geo_place.dart';
import 'api_client.dart';

/// Dropoff / pickup search around the device, via the places service.
class PlacesService {
  PlacesService({ApiClient? apiClient, Dio? dio})
      : _api = apiClient,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': 'Ridons/1.0 (passenger app; https://ridons.app)',
                  'Accept-Language': 'en',
                },
              ),
            );

  final ApiClient? _api;
  final Dio _dio;
  final Map<String, GeoPlace> _reverseCache = {};

  Future<List<GeoPlace>> search({
    String query = '',
    double? latitude,
    double? longitude,
  }) async {
    final fromGateway = await _searchGateway(
      query: query,
      latitude: latitude,
      longitude: longitude,
    );
    if (fromGateway.isNotEmpty) return fromGateway;

    if (query.trim().isEmpty) {
      return _photonNearby(latitude, longitude);
    }
    return _photonSearch(query, latitude, longitude);
  }

  Future<List<GeoPlace>> nearby({
    required double latitude,
    required double longitude,
  }) {
    return search(latitude: latitude, longitude: longitude);
  }

  Future<GeoPlace> reverse(double latitude, double longitude) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'json',
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      final json = response.data ?? const <String, dynamic>{};
      final parsed = _fromNominatim(json);
      final poiName = _poiName(json);
      if (poiName != null) {
        final snapped = await _searchNamedNear(poiName, latitude, longitude);
        if (snapped != null) return snapped;
      }
      if (parsed != null && !_isRoad(json, parsed.name)) {
        return parsed;
      }
      final photon = await _photonReverse(latitude, longitude);
      if (photon != null) return photon;
      if (parsed != null) return parsed;
    } catch (_) {}

    return GeoPlace(
      name: 'My current location',
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Fast label for a map pin. Photon first, short timeout, cached.
  /// Does not snap the coordinates — the pin stays where the user tapped.
  Future<GeoPlace?> reverseFast(double latitude, double longitude) async {
    final key = _cellKey(latitude, longitude);
    final cached = _reverseCache[key];
    if (cached != null) return cached;

    final photon = await _photonReverseAny(latitude, longitude);
    if (photon != null) {
      _rememberReverse(key, photon);
      return photon;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'json',
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final parsed = _fromNominatim(response.data ?? const {});
      if (parsed != null) {
        _rememberReverse(key, parsed);
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  Future<List<GeoPlace>> _searchGateway({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    final api = _api;
    if (api == null) return const [];
    if (query.trim().isEmpty && (latitude == null || longitude == null)) {
      return const [];
    }
    try {
      final response = await api.dio.get<dynamic>(
        '/places/search',
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lng': longitude,
        },
      );
      return _fromGateway(response.data);
    } catch (_) {
      return const [];
    }
  }

  List<GeoPlace> _fromGateway(dynamic data) {
    final rows = data is List ? data : const [];
    final out = <GeoPlace>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final coords = map['coords'];
      if (coords is! List || coords.length < 2) continue;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      final name = '${map['name'] ?? ''}'.trim();
      if (lat == null || lng == null || name.isEmpty) continue;
      final subtitle = '${map['subtitle'] ?? ''}'.trim();
      out.add(
        GeoPlace(
          name: name,
          subtitle: subtitle,
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    return out;
  }

  Future<List<GeoPlace>> _photonSearch(
    String query,
    double? latitude,
    double? longitude,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q': query.trim(),
          'limit': 12,
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lon': longitude,
        },
      );
      return _photonFeatures(response.data, latitude, longitude);
    } catch (_) {
      return const [];
    }
  }

  Future<List<GeoPlace>> _photonNearby(
    double? latitude,
    double? longitude,
  ) async {
    if (latitude == null || longitude == null) return const [];
    const terms = [
      'supermarket',
      'hospital',
      'school',
      'station',
      'hotel',
      'park',
      'bank',
      'restaurant',
    ];
    final bundles = await Future.wait(
      terms.map((term) => _photonSearch(term, latitude, longitude)),
    );
    return _dedupeByName(
      bundles.expand((list) => list),
      latitude,
      longitude,
    );
  }

  Future<GeoPlace?> _photonReverse(double latitude, double longitude) async {
    final place = await _photonReverseAny(latitude, longitude);
    if (place == null) return null;
    if (_meters(latitude, longitude, place.latitude, place.longitude) > 160) {
      return null;
    }
    return place;
  }

  Future<GeoPlace?> _photonReverseAny(double latitude, double longitude) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://photon.komoot.io/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      final data = response.data;
      final features = data?['features'];
      if (features is! List || features.isEmpty) return null;
      final raw = features.first;
      if (raw is! Map) return null;
      final props = raw['properties'];
      final geometry = raw['geometry'];
      if (props is! Map || geometry is! Map) return null;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) return null;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final map = Map<String, dynamic>.from(props);
      final name = '${map['name'] ?? ''}'.trim();
      final street = '${map['street'] ?? map['district'] ?? ''}'.trim();
      final label = name.isNotEmpty ? name : street;
      if (label.isEmpty) return null;
      return GeoPlace(
        name: label,
        subtitle: _photonSubtitle(map),
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
      return null;
    }
  }

  String _cellKey(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  void _rememberReverse(String key, GeoPlace place) {
    if (_reverseCache.length >= 40) {
      _reverseCache.remove(_reverseCache.keys.first);
    }
    _reverseCache[key] = place;
  }

  List<GeoPlace> _photonFeatures(
    Map<String, dynamic>? data,
    double? latitude,
    double? longitude,
  ) {
    final features = data?['features'];
    if (features is! List) return const [];
    final out = <GeoPlace>[];
    for (final raw in features) {
      if (raw is! Map) continue;
      final props = raw['properties'];
      final geometry = raw['geometry'];
      if (props is! Map || geometry is! Map) continue;
      final name = '${props['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      out.add(
        GeoPlace(
          name: name,
          subtitle: _photonSubtitle(Map<String, dynamic>.from(props)),
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    if (latitude == null || longitude == null) return out;
    return _dedupeByName(out, latitude, longitude);
  }

  String _photonSubtitle(Map<String, dynamic> props) {
    final parts = <String>[];
    for (final key in ['city', 'state', 'country']) {
      final value = '${props[key] ?? ''}'.trim();
      if (value.isNotEmpty) parts.add(value);
    }
    if (parts.isNotEmpty) return parts.join(', ');
    final street = '${props['street'] ?? props['district'] ?? ''}'.trim();
    return street;
  }

  Future<GeoPlace?> _searchNamedNear(
    String name,
    double latitude,
    double longitude,
  ) async {
    try {
      final delta = 0.0015;
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': name,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
          'bounded': 1,
          'viewbox':
              '${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}',
        },
      );
      GeoPlace? best;
      var bestMeters = 160.0;
      for (final raw in response.data ?? const []) {
        if (raw is! Map<String, dynamic>) continue;
        final place = _fromNominatim(raw);
        if (place == null) continue;
        final meters = _meters(
          latitude,
          longitude,
          place.latitude,
          place.longitude,
        );
        if (meters < bestMeters) {
          best = place;
          bestMeters = meters;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  GeoPlace? _fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) return null;
    final poi = _poiName(json);
    final display = '${json['display_name'] ?? ''}';
    final name = (poi ?? display.split(',').first).trim();
    if (name.isEmpty) return null;
    final subtitle = display.contains(',')
        ? display.split(',').skip(1).take(2).join(',').trim()
        : '';
    return GeoPlace(
      name: name,
      subtitle: subtitle,
      latitude: lat,
      longitude: lon,
    );
  }

  String? _poiName(Map<String, dynamic> json) {
    final named = '${json['name'] ?? ''}'.trim();
    final osmClass = '${json['class'] ?? ''}'.toLowerCase();
    if (named.isNotEmpty && osmClass != 'highway' && osmClass != 'railway') {
      return named;
    }
    final address = json['address'];
    if (address is! Map) return null;
    const keys = [
      'shop',
      'amenity',
      'building',
      'office',
      'tourism',
      'craft',
      'healthcare',
      'leisure',
    ];
    for (final key in keys) {
      final value = '${address[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  bool _isRoad(Map<String, dynamic> json, String name) {
    final osmClass = '${json['class'] ?? ''}'.toLowerCase();
    if (osmClass == 'highway' || osmClass == 'railway') return true;
    final lower = name.toLowerCase();
    return lower.contains(' road') ||
        lower.contains(' street') ||
        lower.startsWith('kn ') ||
        lower.contains(' avenue') ||
        lower.contains(' highway');
  }

  List<GeoPlace> _dedupeByName(
    Iterable<GeoPlace> places,
    double latitude,
    double longitude,
  ) {
    final seen = <String>{};
    final unique = <GeoPlace>[];
    for (final place in places) {
      final key = place.name.toLowerCase();
      if (!seen.add(key)) continue;
      unique.add(place);
    }
    unique.sort((a, b) {
      final da = _meters(latitude, longitude, a.latitude, a.longitude);
      final db = _meters(latitude, longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });
    if (unique.length <= 12) return unique;
    return unique.take(12).toList();
  }
}

double _meters(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earth * math.asin(math.sqrt(a));
}
