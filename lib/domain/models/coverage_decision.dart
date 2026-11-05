class CoverageDecision {
  const CoverageDecision({
    required this.allowed,
    required this.reasonCode,
    required this.message,
    this.market,
    this.pickupArea,
    this.destinationArea,
  });

  final bool allowed;
  final String reasonCode;
  final String message;
  final String? market;
  final String? pickupArea;
  final String? destinationArea;

  String get messageKey => switch (reasonCode) {
    'PICKUP_OUTSIDE_MARKET' => 'coverage_pickup_outside_market',
    'DESTINATION_OUTSIDE_MARKET' => 'coverage_destination_outside_market',
    'CROSS_BORDER_NOT_SUPPORTED' => 'coverage_cross_border_not_supported',
    'PICKUP_OUTSIDE_COVERAGE' => 'coverage_pickup_outside_coverage',
    'DESTINATION_OUTSIDE_COVERAGE' => 'coverage_destination_outside_coverage',
    _ => allowed ? 'coverage_route_supported' : 'coverage_not_available',
  };

  bool get pickupNeedsChange =>
      reasonCode == 'PICKUP_OUTSIDE_MARKET' ||
      reasonCode == 'PICKUP_OUTSIDE_COVERAGE';

  factory CoverageDecision.fromJson(Map<String, dynamic> json) {
    return CoverageDecision(
      allowed: json['allowed'] == true,
      reasonCode: '${json['reasonCode'] ?? ''}',
      message: '${json['message'] ?? ''}',
      market: json['market']?.toString(),
      pickupArea: json['pickupArea']?.toString(),
      destinationArea: json['destinationArea']?.toString(),
    );
  }
}
