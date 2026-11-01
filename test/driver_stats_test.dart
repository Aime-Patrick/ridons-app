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

  test('DriverStats reads earnings breakdown and chart buckets', () {
    final stats = DriverStats.fromJson({
      'period': 'week',
      'total': 14500,
      'tripEarnings': 12000,
      'questBonus': 2500,
      'trips': 3,
      'series': [
        {
          'date': '2026-10-30',
          'tripEarnings': 4000,
          'questBonus': 500,
          'total': 4500,
          'trips': 1,
        },
      ],
    });

    expect(stats.total, 14500);
    expect(stats.tripEarnings, 12000);
    expect(stats.questBonus, 2500);
    expect(stats.series.single.total, 4500);
    expect(stats.series.single.date, '2026-10-30');
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
