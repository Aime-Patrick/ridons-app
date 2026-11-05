import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/domain/models/coverage_decision.dart';

void main() {
  test('pickup coverage denials offer a pickup change', () {
    final decision = CoverageDecision.fromJson({
      'allowed': false,
      'reasonCode': 'PICKUP_OUTSIDE_COVERAGE',
      'message': 'unsupported pickup',
    });

    expect(decision.allowed, isFalse);
    expect(decision.pickupNeedsChange, isTrue);
    expect(decision.messageKey, 'coverage_pickup_outside_coverage');
  });

  test('destination coverage denials offer a destination change', () {
    final decision = CoverageDecision.fromJson({
      'allowed': false,
      'reasonCode': 'DESTINATION_OUTSIDE_MARKET',
      'message': 'unsupported destination',
    });

    expect(decision.allowed, isFalse);
    expect(decision.pickupNeedsChange, isFalse);
    expect(decision.messageKey, 'coverage_destination_outside_market');
  });

  test('supported route is parsed from the coverage response', () {
    final decision = CoverageDecision.fromJson({
      'allowed': true,
      'reasonCode': 'SUPPORTED_ROUTE',
      'market': 'RW',
      'pickupArea': 'City of Kigali',
      'destinationArea': 'City of Kigali',
      'message': 'supported',
    });

    expect(decision.allowed, isTrue);
    expect(decision.market, 'RW');
    expect(decision.messageKey, 'coverage_route_supported');
  });
}
