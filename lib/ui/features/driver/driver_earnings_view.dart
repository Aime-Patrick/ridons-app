import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/config/api_errors.dart';
import '../../../domain/models/received_rating.dart';
import '../../../domain/models/ride_offer.dart';
import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';

class DriverEarningsView extends ConsumerStatefulWidget {
  const DriverEarningsView({super.key});

  @override
  ConsumerState<DriverEarningsView> createState() => _DriverEarningsViewState();
}

class _DriverEarningsViewState extends ConsumerState<DriverEarningsView> {
  static const _periods = ['week', 'month', 'year'];
  static final _money = NumberFormat('#,###');
  static final _compactMoney = NumberFormat.compact();

  DriverStats? _stats;
  List<ReceivedRating> _ratings = const [];
  var _period = 'week';
  var _loading = true;
  var _periodLoading = false;
  var _loadGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool pull = false}) async {
    final generation = ++_loadGeneration;
    if (!pull && _stats == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (!pull) {
      setState(() {
        _periodLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(tripApiProvider);
      final stats = await _withFreshDriverSession(
        () => api.earnings(period: _period),
      );
      final ratings = await _withFreshDriverSession(api.receivedRatings);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _stats = stats;
        _ratings = ratings;
        _error = null;
        _loading = false;
        _periodLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = _errorLabel(error);
        _loading = false;
        _periodLoading = false;
      });
    }
  }

  Future<void> _selectPeriod(String period) async {
    if (_period == period) return;
    setState(() => _period = period);
    await _load();
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
      if (status == 403) return 'verification_not_approved';
      return apiErrorMessage(error, fallback: 'could_not_load_earnings');
    }
    return 'could_not_load_earnings';
  }

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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      'earnings'.tr(),
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _periodSelector(context),
                    if (_periodLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      _errorPanel(context),
                    ] else if (_stats != null) ...[
                      const SizedBox(height: 16),
                      _totalCard(context, _stats!),
                      const SizedBox(height: 14),
                      _chartCard(context, _stats!),
                      const SizedBox(height: 14),
                      _breakdown(context, _stats!),
                      const SizedBox(height: 24),
                      Text(
                        'recent_ratings'.tr(),
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontSize: 19,
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

  Widget _periodSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Row(
        children: [
          for (final period in _periods)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _selectPeriod(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _period == period
                        ? RidonsColors.primary.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'earnings_period_$period'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _period == period
                          ? RidonsColors.primary
                          : context.ridonsMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalCard(BuildContext context, DriverStats stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: RidonsColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'total_earnings'.tr(),
                style: TextStyle(
                  color: context.ridonsMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_money.format(stats.total)} RWF',
              style: TextStyle(
                color: context.ridonsInk,
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'earnings_cash_note'.tr(),
            style: TextStyle(color: context.ridonsMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, DriverStats stats) {
    final buckets = _visibleBuckets(stats);
    final maxTotal = buckets.fold<int>(
      0,
      (maximum, item) => item.total > maximum ? item.total : maximum,
    );
    final currentKey = _currentBucketKey();
    final maxIndex = buckets.indexWhere((item) => item.total == maxTotal);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'earnings_activity'.tr(),
            style: TextStyle(
              color: context.ridonsInk,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (maxTotal == 0) ...[
            const SizedBox(height: 4),
            Text(
              'no_earnings_in_period'.tr(),
              style: TextStyle(color: context.ridonsMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 142,
            child: Column(
              children: [
                SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      for (var index = 0; index < buckets.length; index++)
                        Expanded(
                          child: Text(
                            buckets.length <= 7 || index == maxIndex
                                ? _compactMoney.format(buckets[index].total)
                                : '',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: context.ridonsMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bucket in buckets)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: maxTotal == 0
                                    ? 4
                                    : (bucket.total / maxTotal * 92).clamp(
                                        6,
                                        92,
                                      ),
                                decoration: BoxDecoration(
                                  color: bucket.date == currentKey
                                      ? RidonsColors.primary
                                      : context.ridonsFill,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final bucket in buckets)
                      Expanded(
                        child: Text(
                          bucket.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: bucket.date == currentKey
                                ? context.ridonsInk
                                : context.ridonsMuted,
                            fontSize: 10,
                            fontWeight: bucket.date == currentKey
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_ChartBucket> _visibleBuckets(DriverStats stats) {
    final today = DateTime.now();
    final values = {for (final item in stats.series) item.date: item};
    final result = <_ChartBucket>[];

    if (_period == 'week') {
      final start = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 6));
      for (var offset = 0; offset < 7; offset++) {
        final date = start.add(Duration(days: offset));
        final key = DateFormat('yyyy-MM-dd').format(date);
        result.add(
          _ChartBucket(
            date: key,
            label: DateFormat('E').format(date),
            total: values[key]?.total ?? 0,
          ),
        );
      }
    } else if (_period == 'month') {
      final days = DateTime(today.year, today.month + 1, 0).day;
      final bucketCount = (days + 6) ~/ 7;
      for (var index = 0; index < bucketCount; index++) {
        final day = index * 7 + 1;
        final date = DateTime(today.year, today.month, day);
        final key = DateFormat('yyyy-MM-dd').format(date);
        result.add(
          _ChartBucket(
            date: key,
            label: 'W${index + 1}',
            total: values[key]?.total ?? 0,
          ),
        );
      }
    } else {
      for (var month = 1; month <= 12; month++) {
        final date = DateTime(today.year, month, 1);
        final key = DateFormat('yyyy-MM-dd').format(date);
        result.add(
          _ChartBucket(
            date: key,
            label: DateFormat('MMM').format(date),
            total: values[key]?.total ?? 0,
          ),
        );
      }
    }
    return result;
  }

  String _currentBucketKey() {
    final now = DateTime.now();
    final day = switch (_period) {
      'week' => now.day,
      'month' => ((now.day - 1) ~/ 7) * 7 + 1,
      _ => 1,
    };
    return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, day));
  }

  Widget _breakdown(BuildContext context, DriverStats stats) {
    final average = stats.trips == 0 ? 0 : stats.tripEarnings ~/ stats.trips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'earnings_breakdown'.tr(),
          style: TextStyle(
            color: context.ridonsMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                icon: Icons.route_rounded,
                label: 'trip_fares'.tr(),
                value: '${_money.format(stats.tripEarnings)} RWF',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                context,
                icon: Icons.stars_rounded,
                label: 'quest_bonuses'.tr(),
                value: '${_money.format(stats.questBonus)} RWF',
                accent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                icon: Icons.check_circle_outline_rounded,
                label: 'completed_trips'.tr(),
                value: '${stats.trips}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                context,
                icon: Icons.payments_outlined,
                label: 'average_fare'.tr(),
                value: '${_money.format(average)} RWF',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool accent = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accent ? RidonsColors.primary : context.ridonsMuted,
            size: 18,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.ridonsMuted, fontSize: 11),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: context.ridonsInk,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!.tr(), style: TextStyle(color: context.ridonsInk)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _load(), child: Text('retry'.tr())),
        ],
      ),
    );
  }

  Widget _emptyRatings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'no_ratings'.tr(),
        style: TextStyle(color: context.ridonsMuted),
      ),
    );
  }

  Widget _ratingTile(BuildContext context, ReceivedRating item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
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

class _ChartBucket {
  const _ChartBucket({
    required this.date,
    required this.label,
    required this.total,
  });

  final String date;
  final String label;
  final int total;
}
