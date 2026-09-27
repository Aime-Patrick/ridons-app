class FareEstimate {
  const FareEstimate({
    required this.suggestedPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.distanceKm,
    required this.durationMin,
    required this.surge,
  });

  final int suggestedPrice;
  final int minPrice;
  final int maxPrice;
  final double distanceKm;
  final int durationMin;
  final double surge;

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      suggestedPrice: (json['suggestedPrice'] as num?)?.toInt() ?? 0,
      minPrice: (json['minPrice'] as num?)?.toInt() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      surge: (json['surge'] as num?)?.toDouble() ?? 1,
    );
  }
}
