import 'package:latlong2/latlong.dart';

import '../../domain/models/fare_estimate.dart';
import 'api_client.dart';

class PricingApi {
  PricingApi(this._api);

  final ApiClient _api;

  Future<FareEstimate> estimate({
    required LatLng from,
    required LatLng to,
    double? roadDistanceKm,
    int? routeDurationMin,
    String vehicleType = 'boda',
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/rides/estimate',
      data: {
        'from': [from.latitude, from.longitude],
        'to': [to.latitude, to.longitude],
        'vehicleType': vehicleType,
        if (roadDistanceKm != null) 'roadDistanceKm': roadDistanceKm,
        if (routeDurationMin != null) 'routeDurationMin': routeDurationMin,
      },
    );
    return FareEstimate.fromJson(response.data ?? const {});
  }
}
