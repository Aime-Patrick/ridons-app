import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/live_driver.dart';
import 'api_client.dart';

/// Gateway geo + ETA. Positions live in Redis memory, not Postgres.
class GeoApi {
  GeoApi(this._api);

  final ApiClient _api;

  Future<List<LiveMapMarker>> nearby({
    required double lat,
    required double lng,
    double radiusM = 3000,
    int limit = 12,
  }) async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/location/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radiusM': radiusM,
          'limit': limit,
        },
      );
      final drivers = response.data?['drivers'];
      if (drivers is! List) return const [];
      return drivers
          .whereType<Map>()
          .map((raw) {
            final map = Map<String, dynamic>.from(raw);
            final id = (map['driverId'] ?? '').toString();
            final dLat = (map['lat'] as num?)?.toDouble();
            final dLng = (map['lng'] as num?)?.toDouble();
            if (id.isEmpty || dLat == null || dLng == null) {
              return null;
            }
            return LiveMapMarker(
              id: id,
              point: LatLng(dLat, dLng),
              headingDeg: (map['headingDeg'] as num?)?.toDouble() ?? 0,
              speedKmh: (map['speedKmh'] as num?)?.toDouble() ?? 0,
            );
          })
          .whereType<LiveMapMarker>()
          .where((marker) => !marker.id.startsWith('sim_drv'))
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<void> ping({
    required double lat,
    required double lng,
    double headingDeg = 0,
    double speedKmh = 0,
    String? rideId,
  }) async {
    try {
      await _api.dio.post<Map<String, dynamic>>(
        '/location/ping',
        data: {
          'coords': [lat, lng],
          'headingDeg': headingDeg,
          'speedKmh': speedKmh,
          if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
        },
      );
    } on DioException {
      // Unauthenticated or location down — map still works from nearby.
    }
  }

  Future<EtaQuote?> eta({
    required LatLng from,
    required LatLng to,
    double? speedKmh,
    String? rideId,
  }) {
    return _postEta('/eta', {
      'from': [from.latitude, from.longitude],
      'to': [to.latitude, to.longitude],
      if (speedKmh != null) 'speedKmh': speedKmh.toString(),
      if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
    });
  }

  Future<EtaQuote?> pickupEta({
    required LatLng driver,
    required LatLng pickup,
    double? speedKmh,
    String? rideId,
  }) {
    return _postEta('/eta/pickup', {
      'driver': [driver.latitude, driver.longitude],
      'pickup': [pickup.latitude, pickup.longitude],
      if (speedKmh != null) 'speedKmh': speedKmh.toString(),
      if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
    });
  }

  Future<EtaQuote?> _postEta(String path, Map<String, dynamic> body) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      final data = response.data;
      final minutes = (data?['minutes'] as num?)?.toInt();
      if (minutes == null) return null;
      return EtaQuote(
        minutes: minutes,
        distanceKm: (data?['distanceKm'] as num?)?.toDouble() ?? 0,
        method: (data?['method'] ?? 'haversine_v1').toString(),
      );
    } on DioException {
      return null;
    }
  }

  Future<bool> setOnline({
    required bool online,
    double? lat,
    double? lng,
  }) async {
    try {
      await _api.dio.post<Map<String, dynamic>>(
        '/driver/online',
        data: {
          'online': online,
          if (lat != null && lng != null) 'location': [lat, lng],
        },
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
