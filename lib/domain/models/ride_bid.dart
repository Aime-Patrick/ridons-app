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
    this.driverName = '',
    this.vehiclePlate = '',
    this.driverRating = 0,
    this.driverPhone = '',
    this.driverAvatarUrl,
    this.negotiationRound = 0,
    this.maxNegotiationRounds = 3,
  });

  final String bidId;
  final String requestId;
  final String driverId;
  final int price;
  final bool isCounter;
  final int etaMin;
  final double distanceKm;
  final String driverName;
  final String vehiclePlate;
  final double driverRating;
  final String driverPhone;
  final String? driverAvatarUrl;
  final int negotiationRound;
  final int maxNegotiationRounds;

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

  factory RideBid.fromJson(Map<String, dynamic> json, {String? requestId}) {
    final round = (json['round'] as num?)?.toInt() ??
        (json['negotiationRound'] as num?)?.toInt() ??
        0;
    final maxRounds = (json['maxRounds'] as num?)?.toInt() ??
        (json['maxNegotiationRounds'] as num?)?.toInt() ??
        3;
    return RideBid(
      bidId: '${json['bidId'] ?? json['id'] ?? ''}',
      requestId: '${json['requestId'] ?? requestId ?? ''}',
      driverId: '${json['driverId'] ?? ''}',
      price: FarePolicy.normalize((json['price'] as num?)?.toInt() ?? 0),
      isCounter: json['isCounter'] as bool? ?? true,
      etaMin: (json['etaMin'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      driverName: '${json['driverName'] ?? ''}',
      vehiclePlate: '${json['vehiclePlate'] ?? ''}',
      driverRating: (json['driverRating'] as num?)?.toDouble() ?? 0,
      driverPhone: '${json['driverPhone'] ?? ''}',
      driverAvatarUrl: json['driverAvatarUrl']?.toString(),
      negotiationRound: round,
      maxNegotiationRounds: maxRounds,
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
    this.driverName = '',
    this.vehiclePlate = '',
    this.driverRating = 0,
    this.driverPhone = '',
    this.driverAvatarUrl,
  });

  final String rideId;
  final String requestId;
  final String driverId;
  final String status;
  final int fare;
  final String driverName;
  final String vehiclePlate;
  final double driverRating;
  final String driverPhone;
  final String? driverAvatarUrl;

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
      driverName: '${json['driverName'] ?? ''}',
      vehiclePlate: '${json['vehiclePlate'] ?? ''}',
      driverRating: (json['driverRating'] as num?)?.toDouble() ?? 0,
      driverPhone: '${json['driverPhone'] ?? ''}',
      driverAvatarUrl: json['driverAvatarUrl']?.toString(),
    );
  }
}
