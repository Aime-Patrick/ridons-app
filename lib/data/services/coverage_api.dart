import 'package:latlong2/latlong.dart';

import '../../domain/models/coverage_decision.dart';
import 'api_client.dart';

class CoverageApi {
  CoverageApi(this._api);

  final ApiClient _api;

  Future<CoverageDecision> checkPickup({
    required LatLng location,
    String service = 'boda',
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/coverage/check-pickup',
      data: {
        'service': service,
        'location': {'lat': location.latitude, 'lng': location.longitude},
      },
    );
    return _decisionFromResponse(response.data);
  }

  Future<CoverageDecision> evaluate({
    required LatLng pickup,
    required LatLng destination,
    String service = 'boda',
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/coverage/evaluate',
      data: {
        'service': service,
        'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
      },
    );
    return _decisionFromResponse(response.data);
  }

  CoverageDecision _decisionFromResponse(Map<String, dynamic>? data) {
    final result = data?['data'];
    if (result is! Map) {
      throw const FormatException('Coverage response has no decision.');
    }
    return CoverageDecision.fromJson(Map<String, dynamic>.from(result));
  }
}
