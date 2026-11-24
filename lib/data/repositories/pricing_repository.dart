import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/fare_estimate.dart';
import '../services/pricing_api.dart';
import '../services/prefs_store.dart';

class PricingRepository {
  PricingRepository({required this.api, required this.prefs});

  final PricingApi api;
  final PrefsStore prefs;

  Future<FareEstimate> estimate({
    required LatLng from,
    required LatLng to,
    required double roadDistanceKm,
    required int routeDurationMin,
    String vehicleType = 'boda',
  }) async {
    try {
      final estimate = await api.estimate(
        from: from,
        to: to,
        roadDistanceKm: roadDistanceKm > 0 ? roadDistanceKm : null,
        routeDurationMin: routeDurationMin > 0 ? routeDurationMin : null,
        vehicleType: vehicleType,
      );
      final pricingConfig = estimate.pricingConfig;
      if (pricingConfig != null) {
        try {
          await prefs.saveOfflineFarePricing(
            pricingConfig.copyWith(lastSyncedAt: DateTime.now().toUtc()),
          );
        } catch (_) {
          // A local cache failure must not discard a valid server quote.
        }
      }
      return estimate;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final isUnavailable =
          error.response == null || (status != null && status >= 500);
      if (!isUnavailable) rethrow;

      final cachedConfig = await prefs.readOfflineFarePricing();
      if (cachedConfig == null || cachedConfig.vehicleType != vehicleType) {
        rethrow;
      }
      final syncedAt = cachedConfig.lastSyncedAt ?? cachedConfig.updatedAt;
      final configAge = DateTime.now().toUtc().difference(syncedAt.toUtc());
      if (syncedAt.year < 2000 || configAge > const Duration(days: 7)) {
        rethrow;
      }
      return cachedConfig.estimate(
        roadDistanceKm: roadDistanceKm,
        routeDurationMin: routeDurationMin,
      );
    }
  }

  Future<FareEstimate> estimateOffline({
    required double roadDistanceKm,
    required int routeDurationMin,
    String vehicleType = 'boda',
  }) async {
    final config = await prefs.readOfflineFarePricing();
    if (config == null || config.vehicleType != vehicleType) {
      throw StateError('offline_pricing_unavailable');
    }
    final syncedAt = config.lastSyncedAt ?? config.updatedAt;
    final age = DateTime.now().toUtc().difference(syncedAt.toUtc());
    if (syncedAt.year < 2000 || age > const Duration(days: 7)) {
      throw StateError('offline_pricing_expired');
    }
    return config.estimate(
      roadDistanceKm: roadDistanceKm,
      routeDurationMin: routeDurationMin,
    );
  }
}
