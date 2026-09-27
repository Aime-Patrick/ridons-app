import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/geo_place.dart';
import '../../domain/models/fare_policy.dart';
import '../../domain/models/ride_bid.dart';
import '../../domain/models/ride_offer.dart';
import '../../domain/models/received_rating.dart';
import 'api_client.dart';

class RideRequestCreated {
  const RideRequestCreated({
    required this.requestId,
    required this.candidateCount,
    required this.offerTtlSec,
    required this.offeredPrice,
  });

  final String requestId;
  final int candidateCount;
  final int offerTtlSec;
  final int offeredPrice;
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
    int? offerTtlSec,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/rides/request',
      data: {
        'from': [pickup.latitude, pickup.longitude],
        'to': [dropoff.latitude, dropoff.longitude],
        'fromName': pickup.name,
        'toName': dropoff.name,
        'passengerName': passengerName,
        'offeredPrice': FarePolicy.normalize(offeredPrice),
        'suggestedPrice': FarePolicy.normalize(
          suggestedPrice,
          minimum: FarePolicy.suggestedMinRwf,
        ),
        'paymentMethod': paymentMethod.toLowerCase(),
        'vehicleType': 'bike',
        if (offerTtlSec != null) 'offerTtlSec': offerTtlSec,
      },
    );
    final data = response.data ?? const {};
    return RideRequestCreated(
      requestId: '${data['requestId'] ?? ''}',
      candidateCount: (data['candidateCount'] as num?)?.toInt() ?? 0,
      offerTtlSec: (data['offerTtlSec'] as num?)?.toInt() ?? 0,
      offeredPrice: (data['offeredPrice'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> cancelRequest(String requestId) async {
    await _api.dio.post<Map<String, dynamic>>('/rides/$requestId/cancel');
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

  Future<ActiveRide> accept(
    String requestId, {
    String driverName = '',
    String vehiclePlate = '',
    double driverRating = 0,
    String? driverAvatarUrl,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/driver/requests/$requestId/accept',
      data: {
        if (driverName.trim().isNotEmpty) 'driverName': driverName.trim(),
        if (vehiclePlate.trim().isNotEmpty) 'vehiclePlate': vehiclePlate.trim(),
        if (driverRating > 0) 'driverRating': driverRating,
        if (driverAvatarUrl?.trim().isNotEmpty == true)
          'driverAvatarUrl': driverAvatarUrl!.trim(),
      },
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

  Future<void> counter(
    String requestId,
    int price, {
    String driverName = '',
    String vehiclePlate = '',
    double driverRating = 0,
    String? driverAvatarUrl,
  }) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/driver/requests/$requestId/counter',
      data: {
        'price': FarePolicy.normalize(price),
        if (driverName.trim().isNotEmpty) 'driverName': driverName.trim(),
        if (vehiclePlate.trim().isNotEmpty) 'vehiclePlate': vehiclePlate.trim(),
        if (driverRating > 0) 'driverRating': driverRating,
        if (driverAvatarUrl?.trim().isNotEmpty == true)
          'driverAvatarUrl': driverAvatarUrl!.trim(),
      },
    );
  }

  Future<void> counterBid({
    required String requestId,
    required String bidId,
    required int price,
  }) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$requestId/counter',
      data: {'bidId': bidId, 'price': FarePolicy.normalize(price)},
    );
  }

  Future<RideAssignment> acceptBid({
    required String requestId,
    required String bidId,
    String driverName = '',
    String vehiclePlate = '',
    double driverRating = 0,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/rides/$requestId/accept-bid',
      data: {
        'bidId': bidId,
        if (driverName.trim().isNotEmpty) 'driverName': driverName.trim(),
        if (vehiclePlate.trim().isNotEmpty) 'vehiclePlate': vehiclePlate.trim(),
        if (driverRating > 0) 'driverRating': driverRating,
      },
    );
    return RideAssignment.fromJson(
      response.data ?? const {},
      requestId: requestId,
    );
  }

  Future<void> rejectBid({
    required String requestId,
    required String bidId,
  }) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$requestId/reject-bid',
      data: {'bidId': bidId},
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
        driverId: '${ride['driverId'] ?? ''}',
        driverName: '${ride['driverName'] ?? offer?.driverName ?? ''}',
        driverVehiclePlate:
            '${ride['vehiclePlate'] ?? offer?.driverVehiclePlate ?? ''}',
        driverRating: (ride['driverRating'] as num?)?.toDouble() ??
            offer?.driverRating ??
            0,
        driverPhone: '${ride['driverPhone'] ?? ''}',
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
        driverAvatarUrl: offer?.driverAvatarUrl,
      );
    } on DioException {
      return null;
    }
  }

  Future<String> createShareLink(String rideId) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/rides/$rideId/share',
    );
    final url = '${response.data?['url'] ?? ''}'.trim();
    if (url.isEmpty) {
      throw StateError('The trip share link was not returned.');
    }
    return url;
  }

  Future<void> rateRide(
    String rideId, {
    required int rating,
    String comment = '',
    List<String> tags = const [],
  }) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/rides/$rideId/rate',
      data: {
        'rating': rating,
        'comment': comment.trim(),
        'tags': tags,
      },
    );
  }

  Future<ActiveRide?> passengerActiveRide() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/passenger/rides/active',
      );
      final rideRaw = response.data?['ride'];
      if (rideRaw is! Map) return null;
      final ride = Map<String, dynamic>.from(rideRaw);
      final requestRaw = response.data?['request'];
      final request = requestRaw is Map
          ? Map<String, dynamic>.from(requestRaw)
          : <String, dynamic>{};
      final offer = request.isEmpty ? null : RideOffer.fromJson(request);
      return ActiveRide(
        rideId: '${ride['rideId'] ?? ride['id'] ?? ''}',
        requestId: '${ride['requestId'] ?? offer?.requestId ?? ''}',
        passengerId: '${ride['passengerId'] ?? ''}',
        driverId: '${ride['driverId'] ?? ''}',
        driverName: '${ride['driverName'] ?? offer?.driverName ?? ''}',
        driverVehiclePlate:
            '${ride['vehiclePlate'] ?? offer?.driverVehiclePlate ?? ''}',
        driverRating: (ride['driverRating'] as num?)?.toDouble() ??
            offer?.driverRating ??
            0,
        driverPhone: '${response.data?['driverPhone'] ?? ride['driverPhone'] ?? ''}',
        status: '${ride['status'] ?? ''}',
        fare: (ride['fare'] as num?)?.toInt() ?? offer?.offeredPrice ?? 0,
        from: LatLng(
          (ride['fromLat'] as num?)?.toDouble() ?? offer?.from.latitude ?? 0,
          (ride['fromLng'] as num?)?.toDouble() ?? offer?.from.longitude ?? 0,
        ),
        to: LatLng(
          (ride['toLat'] as num?)?.toDouble() ?? offer?.to.latitude ?? 0,
          (ride['toLng'] as num?)?.toDouble() ?? offer?.to.longitude ?? 0,
        ),
        paymentMethod: offer?.paymentMethod ?? 'cash',
        fromName: offer?.fromName ?? '',
        toName: offer?.toName ?? '',
        driverAvatarUrl: ride['driverAvatarUrl']?.toString() ??
            offer?.driverAvatarUrl,
      );
    } on DioException {
      return null;
    }
  }

  Future<DriverStats> stats() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/driver/stats',
      );
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

  Future<List<ReceivedRating>> receivedRatings() async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/driver/ratings',
    );
    final raw = response.data?['ratings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ReceivedRating.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
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
        .map(
          (item) => TripHistoryItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}
