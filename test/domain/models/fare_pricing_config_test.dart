import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/domain/models/fare_pricing_config.dart';

void main() {
  group('FarePricingConfig offline estimate', () {
    final config = FarePricingConfig(
      version: 'test-version',
      updatedAt: DateTime.utc(2026, 11, 24),
      lastSyncedAt: DateTime.utc(2026, 11, 24, 9),
      baseFareRwf: 500,
      perKmRwf: 350,
      minFareRwf: 800,
      maxMultiplier: 1.45,
      bodaSpeedKmh: 22,
      vehicleType: 'boda',
      fareMultiplier: 1.35,
    );

    test('uses road distance, selected vehicle multiplier and route ETA', () {
      final result = config.estimate(roadDistanceKm: 5, routeDurationMin: 12);

      expect(result.suggestedPrice, 3100);
      expect(result.minPrice, 2300);
      expect(result.maxPrice, 4500);
      expect(result.distanceKm, 5);
      expect(result.durationMin, 12);
      expect(result.isProvisional, isTrue);
    });

    test('round-trips cached pricing config JSON', () {
      final restored = FarePricingConfig.fromJson(config.toJson());

      expect(restored.version, config.version);
      expect(restored.updatedAt, config.updatedAt);
      expect(restored.lastSyncedAt, config.lastSyncedAt);
      expect(restored.fareMultiplier, config.fareMultiplier);
    });
  });
}
