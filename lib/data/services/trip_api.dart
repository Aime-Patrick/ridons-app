import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/geo_place.dart';
import '../../domain/models/ride_offer.dart';
import 'api_client.dart';

class RideRequestCreated {
  const RideRequestCreated({
    required this.requestId,
    required this.candidateCount,
  });

  final String requestId;
  final int candidateCount;
}

class TripApi {
  TripApi(this._api);

  final ApiClient _api;

  Future<RideRequestCreated> createRequest({
    required GeoPlace pickup,
    required GeoPlace dropoff,
    required int offeredPrice,
    int suggestedPrice = 0,
    String paymentMethod = 'cash',
    String passengerName = '',
    int offerTtlSec = 60,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/rides/request',
      data: {
        'from': [pickup.latitude, pickup.longitude],
        'to': [dropoff.latitude, dropoff.longitude],
        'fromName': pickup.name,
        'toName': dropoff.name,
        'passengerName': passengerName,
        'offeredPrice': offeredPrice,
        'suggestedPrice': suggestedPrice,
        'paymentMethod': paymentMethod.toLowerCase(),
        'vehicleType': 'bike',
        'offerTtlSec': offerTtlSec,
      },
    );
    final data = response.data ?? const {};
    return RideRequestCreated(
      requestId: '${data['requestId'] ?? ''}',
      candidateCount: (data['candidateCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> cancelRequest(String requestId) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$requestId/cancel',
    );
  }

  Future<List<RideOffer>> inbox() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/driver/requests/inbox',
      );
      final raw = response.data?['requests'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => RideOffer.fromJson(Map<String, dynamic>.from(item)))
          .where((offer) => offer.requestId.isNotEmpty)
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<ActiveRide> accept(String requestId) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/driver/requests/$requestId/accept',
    );
    final data = response.data ?? const {};
    return ActiveRide(
      rideId: '${data['rideId'] ?? ''}',
      requestId: requestId,
      passengerId: '${data['passengerId'] ?? ''}',
      status: '${data['status'] ?? 'matched'}',
      fare: (data['fare'] as num?)?.toInt() ?? 0,
      from: const LatLng(0, 0),
      to: const LatLng(0, 0),
    );
  }

  Future<void> counter(String requestId, int price) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/driver/requests/$requestId/counter',
      data: {'price': price},
    );
  }

  Future<void> decline(String requestId) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/driver/requests/$requestId/decline',
      data: {'reason': 'skipped'},
    );
  }

  Future<void> updateStatus(String rideId, String status) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$rideId/status',
      data: {'status': status},
    );
  }

  Future<void> cancelRide(String rideId) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$rideId/cancel',
      data: {'reason': 'driver_cancelled'},
    );
  }

  Future<ActiveRide?> activeRide() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/driver/rides/active',
      );
      final rideMap = response.data?['ride'];
      if (rideMap is! Map) return null;
      final ride = Map<String, dynamic>.from(rideMap);
      final reqRaw = response.data?['request'];
      final req = reqRaw is Map
          ? Map<String, dynamic>.from(reqRaw)
          : <String, dynamic>{};
      final offer = req.isEmpty ? null : RideOffer.fromJson(req);
      return ActiveRide(
        rideId: '${ride['rideId'] ?? ride['id'] ?? ''}',
        requestId: '${ride['requestId'] ?? offer?.requestId ?? ''}',
        passengerId: '${ride['passengerId'] ?? offer?.passengerId ?? ''}',
        status: '${ride['status'] ?? ''}',
        fare: (ride['fare'] as num?)?.toInt() ?? 0,
        from: LatLng(
          (ride['fromLat'] as num?)?.toDouble() ?? offer?.from.latitude ?? 0,
          (ride['fromLng'] as num?)?.toDouble() ?? offer?.from.longitude ?? 0,
        ),
        to: LatLng(
          (ride['toLat'] as num?)?.toDouble() ?? offer?.to.latitude ?? 0,
          (ride['toLng'] as num?)?.toDouble() ?? offer?.to.longitude ?? 0,
        ),
        paymentMethod: offer?.paymentMethod ?? 'cash',
        passengerName: offer?.passengerName ?? '',
        passengerPhone: offer?.passengerPhone ?? '',
        fromName: offer?.fromName ?? '',
        toName: offer?.toName ?? '',
      );
    } on DioException {
      return null;
    }
  }

  Future<DriverStats> stats() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>('/driver/stats');
      return DriverStats.fromJson(response.data ?? const {});
    } on DioException {
      return const DriverStats();
    }
  }

  Future<List<DriverQuest>> quests() async {
    try {
      final response = await _api.dio.get<dynamic>('/driver/quests');
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['quests'] as List? ?? const []) : const []);
      return list
          .whereType<Map>()
          .map((item) => DriverQuest.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<DriverStats> earnings({String period = 'today'}) async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/driver/earnings',
      queryParameters: {'period': period},
    );
    return DriverStats.fromJson(response.data ?? const {});
  }

  Future<List<TripHistoryItem>> myTrips({String period = 'all'}) async {
    final response = await _api.dio.get<dynamic>(
      '/me/trips',
      queryParameters: {'period': period},
    );
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map ? (raw['trips'] as List? ?? const []) : const []);
    return list
        .whereType<Map>()
        .map((item) => TripHistoryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
