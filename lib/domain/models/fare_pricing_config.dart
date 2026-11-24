import 'fare_estimate.dart';

class FarePricingConfig {
  const FarePricingConfig({
    required this.version,
    required this.updatedAt,
    this.lastSyncedAt,
    required this.baseFareRwf,
    required this.perKmRwf,
    required this.minFareRwf,
    required this.maxMultiplier,
    required this.bodaSpeedKmh,
    required this.vehicleType,
    required this.fareMultiplier,
  });

  final String version;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final int baseFareRwf;
  final int perKmRwf;
  final int minFareRwf;
  final double maxMultiplier;
  final double bodaSpeedKmh;
  final String vehicleType;
  final double fareMultiplier;

  factory FarePricingConfig.fromJson(Map<String, dynamic> json) {
    return FarePricingConfig(
      version: json['version'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
      baseFareRwf: (json['baseFareRwf'] as num?)?.toInt() ?? 0,
      perKmRwf: (json['perKmRwf'] as num?)?.toInt() ?? 0,
      minFareRwf: (json['minFareRwf'] as num?)?.toInt() ?? 0,
      maxMultiplier: (json['maxMultiplier'] as num?)?.toDouble() ?? 1,
      bodaSpeedKmh: (json['bodaSpeedKmh'] as num?)?.toDouble() ?? 22,
      vehicleType: json['vehicleType'] as String? ?? 'boda',
      fareMultiplier: (json['fareMultiplier'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    'baseFareRwf': baseFareRwf,
    'perKmRwf': perKmRwf,
    'minFareRwf': minFareRwf,
    'maxMultiplier': maxMultiplier,
    'bodaSpeedKmh': bodaSpeedKmh,
    'vehicleType': vehicleType,
    'fareMultiplier': fareMultiplier,
  };

  FarePricingConfig copyWith({DateTime? lastSyncedAt}) {
    return FarePricingConfig(
      version: version,
      updatedAt: updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      baseFareRwf: baseFareRwf,
      perKmRwf: perKmRwf,
      minFareRwf: minFareRwf,
      maxMultiplier: maxMultiplier,
      bodaSpeedKmh: bodaSpeedKmh,
      vehicleType: vehicleType,
      fareMultiplier: fareMultiplier,
    );
  }

  FareEstimate estimate({
    required double roadDistanceKm,
    required int routeDurationMin,
  }) {
    final distance = roadDistanceKm < 0.3 ? 0.3 : roadDistanceKm;
    final duration = routeDurationMin > 0
        ? routeDurationMin
        : (distance / (bodaSpeedKmh <= 0 ? 22 : bodaSpeedKmh) * 60)
              .round()
              .clamp(3, 24 * 60)
              .toInt();
    final base = (baseFareRwf + perKmRwf * distance).round();
    var baseSuggested = _round100(base);
    if (baseSuggested < minFareRwf) baseSuggested = _round100(minFareRwf);
    var baseMin = _round100(baseSuggested * 0.75);
    if (baseMin < minFareRwf) baseMin = minFareRwf;
    final baseMax = _round100(baseSuggested * maxMultiplier);
    final suggested = _round100(baseSuggested * fareMultiplier);
    final minPrice = _round100(baseMin * fareMultiplier);
    final maxPrice = _round100(baseMax * fareMultiplier);

    return FareEstimate(
      suggestedPrice: suggested,
      minPrice: minPrice,
      maxPrice: maxPrice,
      distanceKm: (distance * 10).round() / 10,
      durationMin: duration,
      surge: 1,
      fareMultiplier: fareMultiplier,
      vehicleType: vehicleType,
      pricingConfig: this,
      isProvisional: true,
    );
  }

  int _round100(num value) => (value / 100).round() * 100;
}
