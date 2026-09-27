import 'dart:convert';

import 'package:latlong2/latlong.dart';

class RideOffer {
  RideOffer({
    required this.requestId,
    required this.passengerId,
    required this.from,
    required this.to,
    required this.offeredPrice,
    required this.expiresAt,
    this.passengerName = '',
    this.passengerPhone = '',
    this.fromName = '',
    this.toName = '',
    this.driverName = '',
    this.driverVehiclePlate = '',
    this.driverRating = 0,
    this.driverPhone = '',
    this.driverAvatarUrl,
    this.suggestedPrice = 0,
    this.paymentMethod = 'cash',
    this.counterPrice,
    this.negotiationRound = 0,
    this.maxNegotiationRounds = 3,
  });

  final String requestId;
  final String passengerId;
  final LatLng from;
  final LatLng to;
  int offeredPrice;
  final DateTime expiresAt;
  String passengerName;
  String passengerPhone;
  String fromName;
  String toName;
  String driverName;
  String driverVehiclePlate;
  double driverRating;
  String driverPhone;
  String? driverAvatarUrl;
  int suggestedPrice;
  final String paymentMethod;
  int? counterPrice;
  int negotiationRound;
  int maxNegotiationRounds;

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  String get timerLabel {
    final left = remaining;
    if (left == Duration.zero) return '';
    final m = left.inMinutes;
    final s = left.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get displayName {
    if (passengerName.trim().isNotEmpty) return passengerName.trim();
    return 'Passenger';
  }

  String get passengerIdLabel {
    final tail =
        passengerId.contains('_') ? passengerId.split('_').last : passengerId;
    final cleaned = tail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return '—';
    final few = cleaned.length <= 6
        ? cleaned
        : cleaned.substring(cleaned.length - 6);
    return 'PAX-${few.toUpperCase()}';
  }

  factory RideOffer.fromJson(Map<String, dynamic> json) {
    final fromLat = (json['fromLat'] as num?)?.toDouble() ?? 0;
    final fromLng = (json['fromLng'] as num?)?.toDouble() ?? 0;
    final toLat = (json['toLat'] as num?)?.toDouble() ?? 0;
    final toLng = (json['toLng'] as num?)?.toDouble() ?? 0;
    final offer = RideOffer(
      requestId: '${json['requestId'] ?? json['id'] ?? ''}',
      passengerId: '${json['passengerId'] ?? ''}',
      from: LatLng(fromLat, fromLng),
      to: LatLng(toLat, toLng),
      offeredPrice: (json['offeredPrice'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      paymentMethod: '${json['paymentMethod'] ?? 'cash'}',
      driverName: '${json['driverName'] ?? ''}',
      driverVehiclePlate: '${json['vehiclePlate'] ?? ''}',
      driverRating: (json['driverRating'] as num?)?.toDouble() ?? 0,
      driverAvatarUrl: json['driverAvatarUrl']?.toString(),
      negotiationRound: (json['negotiationRound'] as num?)?.toInt() ??
          (json['round'] as num?)?.toInt() ??
          0,
      maxNegotiationRounds: (json['maxNegotiationRounds'] as num?)?.toInt() ??
          (json['maxRounds'] as num?)?.toInt() ??
          3,
    );
    offer._applyComments('${json['comments'] ?? ''}');
    return offer;
  }

  void _applyComments(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return;
    try {
      final map = jsonDecode(trimmed);
      if (map is! Map) return;
      passengerName = '${map['passengerName'] ?? passengerName}';
      passengerPhone = '${map['passengerPhone'] ?? passengerPhone}';
      fromName = '${map['fromName'] ?? fromName}';
      toName = '${map['toName'] ?? toName}';
      suggestedPrice =
          (map['suggestedPrice'] as num?)?.toInt() ?? suggestedPrice;
    } catch (_) {}
  }
}

class ActiveRide {
  const ActiveRide({
    required this.rideId,
    required this.requestId,
    required this.passengerId,
    required this.status,
    required this.fare,
    required this.from,
    required this.to,
    this.driverId = '',
    this.driverName = '',
    this.driverVehiclePlate = '',
    this.driverRating = 0,
    this.driverPhone = '',
    this.paymentMethod = 'cash',
    this.passengerName = '',
    this.passengerPhone = '',
    this.fromName = '',
    this.toName = '',
    this.driverAvatarUrl,
  });

  final String rideId;
  final String requestId;
  final String passengerId;
  final String status;
  final int fare;
  final LatLng from;
  final LatLng to;
  final String driverId;
  final String driverName;
  final String driverVehiclePlate;
  final double driverRating;
  final String driverPhone;
  final String paymentMethod;
  final String passengerName;
  final String passengerPhone;
  final String fromName;
  final String toName;
  final String? driverAvatarUrl;

  bool get isDriving => status == 'in_progress';
  bool get isLocked =>
      status == 'matched' || status == 'en_route' || status == 'arrived';
}

class DriverStats {
  const DriverStats({
    this.total = 0,
    this.trips = 0,
    this.avgRating = 0,
    this.acceptanceRate = 100,
    this.completionRate = 100,
    this.todayEarnings = 0,
    this.goalDaily = 25000,
    this.tier = 'bronze',
    this.commissionPct = 12,
    this.priorityDispatch = false,
  });

  final int total;
  final int trips;
  final double avgRating;
  final int acceptanceRate;
  final int completionRate;
  final int todayEarnings;
  final int goalDaily;
  final String tier;
  final int commissionPct;
  final bool priorityDispatch;

  String get tierLabel {
    switch (tier) {
      case 'platinum':
        return 'Platinum tier';
      case 'gold':
        return 'Gold tier';
      case 'silver':
        return 'Silver tier';
      default:
        return '';
    }
  }

  bool get hasTierBadge =>
      tier == 'silver' || tier == 'gold' || tier == 'platinum';

  double get goalFraction {
    if (goalDaily <= 0) return 0;
    final v = todayEarnings / goalDaily;
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      total: (json['total'] as num?)?.toInt() ??
          (json['weeklyEarnings'] as num?)?.toInt() ??
          0,
      trips: (json['trips'] as num?)?.toInt() ??
          (json['weeklyTrips'] as num?)?.toInt() ??
          0,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      acceptanceRate: (json['acceptanceRate'] as num?)?.toInt() ?? 100,
      completionRate: (json['completionRate'] as num?)?.toInt() ?? 100,
      todayEarnings: (json['todayEarnings'] as num?)?.toInt() ??
          (json['goalProgress'] as num?)?.toInt() ??
          0,
      goalDaily: (json['goalDaily'] as num?)?.toInt() ?? 25000,
      tier: '${json['tier'] ?? 'bronze'}',
      commissionPct: (json['commissionPct'] as num?)?.toInt() ?? 12,
      priorityDispatch: json['priorityDispatch'] == true,
    );
  }
}

class DriverQuest {
  const DriverQuest({
    required this.id,
    required this.title,
    required this.current,
    required this.total,
    required this.reward,
    required this.expires,
    this.completed = false,
  });

  final String id;
  final String title;
  final int current;
  final int total;
  final int reward;
  final DateTime expires;
  final bool completed;

  double get fraction {
    if (total <= 0) return 0;
    final v = current / total;
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  factory DriverQuest.fromJson(Map<String, dynamic> json) {
    return DriverQuest(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      current: (json['current'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 1,
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      expires: DateTime.tryParse('${json['expires'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      completed: json['completed'] == true,
    );
  }
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.from,
    required this.to,
    required this.fare,
    required this.status,
    required this.when,
  });

  final String id;
  final LatLng from;
  final LatLng to;
  final int fare;
  final String status;
  final DateTime when;

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    return TripHistoryItem(
      id: '${json['id'] ?? ''}',
      from: LatLng(
        (json['fromLat'] as num?)?.toDouble() ?? 0,
        (json['fromLng'] as num?)?.toDouble() ?? 0,
      ),
      to: LatLng(
        (json['toLat'] as num?)?.toDouble() ?? 0,
        (json['toLng'] as num?)?.toDouble() ?? 0,
      ),
      fare: (json['fare'] as num?)?.toInt() ?? 0,
      status: '${json['status'] ?? ''}',
      when: DateTime.tryParse('${json['completedAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
    );
  }
}
