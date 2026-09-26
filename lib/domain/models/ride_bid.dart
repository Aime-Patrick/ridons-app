import 'fare_policy.dart';

class RideBid {
  const RideBid({
    required this.bidId,
    required this.requestId,
    required this.driverId,
    required this.price,
    this.isCounter = true,
    this.etaMin = 0,
    this.distanceKm = 0,
  });

  final String bidId;
  final String requestId;
  final String driverId;
  final int price;
  final bool isCounter;
  final int etaMin;
  final double distanceKm;

  String get driverLabel {
    final raw = driverId.trim();
    if (raw.isEmpty) return 'Nearby driver';
    final tail = raw.contains('_') ? raw.split('_').last : raw;
    final cleaned = tail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return 'Nearby driver';
    final suffix = cleaned.length <= 5
        ? cleaned.toUpperCase()
        : cleaned.substring(cleaned.length - 5).toUpperCase();
    return 'Driver $suffix';
  }

  String get proximityLabel {
    if (etaMin > 0) return '$etaMin min away';
    if (distanceKm > 0) return '${distanceKm.toStringAsFixed(1)} km away';
    return 'Nearby driver';
  }

  factory RideBid.fromJson(
    Map<String, dynamic> json, {
    String? requestId,
  }) {
    return RideBid(
      bidId: '${json['bidId'] ?? json['id'] ?? ''}',
      requestId: '${json['requestId'] ?? requestId ?? ''}',
      driverId: '${json['driverId'] ?? ''}',
      price: FarePolicy.normalize((json['price'] as num?)?.toInt() ?? 0),
      isCounter: json['isCounter'] as bool? ?? true,
      etaMin: (json['etaMin'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RideAssignment {
  const RideAssignment({
    required this.rideId,
    required this.requestId,
    required this.driverId,
    required this.status,
    required this.fare,
  });

  final String rideId;
  final String requestId;
  final String driverId;
  final String status;
  final int fare;

  factory RideAssignment.fromJson(
    Map<String, dynamic> json, {
    required String requestId,
  }) {
    return RideAssignment(
      rideId: '${json['rideId'] ?? ''}',
      requestId: '${json['requestId'] ?? requestId}',
      driverId: '${json['driverId'] ?? ''}',
      status: '${json['status'] ?? 'matched'}',
      fare: (json['fare'] as num?)?.toInt() ?? 0,
    );
  }
}
