import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/domain/models/ride_offer.dart';

void main() {
  test('DriverStats reads tier and priority dispatch', () {
    final stats = DriverStats.fromJson({
      'total': 128500,
      'trips': 67,
      'avgRating': 4.9,
      'acceptanceRate': 92,
      'todayEarnings': 18500,
      'goalDaily': 25000,
      'tier': 'gold',
      'commissionPct': 8,
      'priorityDispatch': true,
    });
    expect(stats.tierLabel, 'Gold tier');
    expect(stats.hasTierBadge, isTrue);
    expect(stats.priorityDispatch, isTrue);
    expect(stats.goalFraction, closeTo(18500 / 25000, 0.001));
  });

  test('DriverQuest parses progress', () {
    final quest = DriverQuest.fromJson({
      'id': 'q1',
      'title': 'Complete 5 trips today',
      'current': 3,
      'total': 5,
      'reward': 2000,
      'expires': '2026-09-17T23:59:59Z',
      'completed': false,
    });
    expect(quest.fraction, closeTo(0.6, 0.001));
    expect(quest.completed, isFalse);
  });
}
