import 'package:latlong2/latlong.dart';

import '../../domain/models/coverage_decision.dart';
import 'api_client.dart';

class CoverageApi {
  CoverageApi(this._api);

  final ApiClient _api;
  List<String>? _enabledMarketCodes;
  DateTime? _enabledMarketsLoadedAt;
  Future<List<String>>? _enabledMarketsRequest;

  Future<List<String>> enabledMarketCodes() {
    final cached = _enabledMarketCodes;
    final loadedAt = _enabledMarketsLoadedAt;
    if (cached != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5)) {
      return Future.value(cached);
    }
    return _enabledMarketsRequest ??= _loadEnabledMarketCodes();
  }

  Future<List<String>> _loadEnabledMarketCodes() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/coverage/markets/enabled',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const FormatException('Enabled markets response is invalid.');
      }
      final codes = data
          .whereType<String>()
          .map((code) => code.trim().toUpperCase())
          .where((code) => RegExp(r'^[A-Z]{2}$').hasMatch(code))
          .toSet()
          .toList(growable: false);
      _enabledMarketCodes = codes;
      _enabledMarketsLoadedAt = DateTime.now();
      return codes;
    } finally {
      _enabledMarketsRequest = null;
    }
  }

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
