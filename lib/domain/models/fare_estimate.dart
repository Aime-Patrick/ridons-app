import 'fare_pricing_config.dart';

class FareEstimate {
  const FareEstimate({
    required this.suggestedPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.distanceKm,
    required this.durationMin,
    required this.surge,
    this.fareMultiplier = 1,
    this.vehicleType = 'boda',
    this.pricingConfig,
    this.isProvisional = false,
  });

  final int suggestedPrice;
  final int minPrice;
  final int maxPrice;
  final double distanceKm;
  final int durationMin;
  final double surge;
  final double fareMultiplier;
  final String vehicleType;
  final FarePricingConfig? pricingConfig;
  final bool isProvisional;

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      suggestedPrice: (json['suggestedPrice'] as num?)?.toInt() ?? 0,
      minPrice: (json['minPrice'] as num?)?.toInt() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      surge: (json['surge'] as num?)?.toDouble() ?? 1,
      fareMultiplier: (json['fareMultiplier'] as num?)?.toDouble() ?? 1,
      vehicleType: json['vehicleType'] as String? ?? 'boda',
      pricingConfig: json['pricingConfig'] is Map<String, dynamic>
          ? FarePricingConfig.fromJson(
              json['pricingConfig'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
