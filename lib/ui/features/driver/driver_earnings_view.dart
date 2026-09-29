import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../data/config/api_errors.dart';
import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../../domain/models/ride_offer.dart';
import '../../../domain/models/received_rating.dart';

class DriverEarningsView extends ConsumerStatefulWidget {
  const DriverEarningsView({super.key});

  @override
  ConsumerState<DriverEarningsView> createState() => _DriverEarningsViewState();
}

class _DriverEarningsViewState extends ConsumerState<DriverEarningsView> {
  DriverStats _today = const DriverStats();
  DriverStats _week = const DriverStats();
  List<ReceivedRating> _ratings = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool pull = false}) async {
    if (!pull) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = ref.read(tripApiProvider);
      final today = await _withFreshDriverSession(
        () => api.earnings(period: 'today'),
      );
      final week = await _withFreshDriverSession(
        () => api.earnings(period: 'week'),
      );
      final ratings = await _withFreshDriverSession(api.receivedRatings);
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _ratings = ratings;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorLabel(error);
        _loading = false;
      });
    }
  }

  Future<T> _withFreshDriverSession<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final responseError = error.response?.data;
      final code = responseError is Map
          ? '${responseError['error'] ?? ''}'
          : '';
      final needsFreshClaims =
          error.response?.statusCode == 403 &&
          code == 'driver_verification_required';
      if (!needsFreshClaims) rethrow;

      final session = await ref.read(authRepositoryProvider).refreshSession();
      if (session == null) rethrow;
      await ref.read(authSessionProvider.notifier).setSession(session);
      return request();
    }
  }

  String _errorLabel(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'session_expired';
      if (status == 403) {
        return 'verification_not_approved';
      }
      return apiErrorMessage(error, fallback: 'could_not_load_earnings');
    }
    return 'could_not_load_earnings';
  }

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.ridonsPage,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: RidonsColors.primary,
                onRefresh: () => _load(pull: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text(
                      'earnings'.tr(),
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!.tr(),
                        style: TextStyle(color: RidonsColors.primary),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _load(),
                        child: Text('retry'.tr()),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _tile(context, 'today', _today),
                      const SizedBox(height: 10),
                      _tile(context, 'this_week', _week),
                      const SizedBox(height: 20),
                      Text(
                        'recent_ratings'.tr(),
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_ratings.isEmpty)
                        _emptyRatings(context)
                      else
                        ..._ratings.map((item) => _ratingTile(context, item)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, DriverStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.tr(), style: TextStyle(color: context.ridonsMuted)),
                Text(
                  '${_money.format(stats.total)} RWF',
                  style: TextStyle(
                    color: context.ridonsInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'trips_count'.tr(namedArgs: {'count': '${stats.trips}'}),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _emptyRatings(BuildContext context) {
    return Text(
      'no_ratings'.tr(),
      style: TextStyle(color: context.ridonsMuted),
    );
  }

  Widget _ratingTile(BuildContext context, ReceivedRating item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.ridonsSheet,
        border: Border.all(color: context.ridonsLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.rating}/5',
            style: const TextStyle(
              color: RidonsColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.comment.trim().isEmpty
                      ? 'no_comment'.tr()
                      : item.comment.trim(),
                  style: TextStyle(color: context.ridonsInk),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM d, yyyy').format(item.createdAt)} · ${item.rideId}',
                  style: TextStyle(color: context.ridonsMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
