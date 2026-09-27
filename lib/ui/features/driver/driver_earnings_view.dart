import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      final today = await api.earnings(period: 'today');
      final week = await api.earnings(period: 'week');
      final ratings = await api.receivedRatings();
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _ratings = ratings;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load earnings. Pull down to retry.';
        _loading = false;
      });
    }
  }

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RidonsColors.background,
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
                    const Text(
                      'Earnings',
                      style: TextStyle(
                        color: RidonsColors.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: RidonsColors.primary),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _load(),
                        child: const Text('Retry'),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _tile('Today', _today),
                      const SizedBox(height: 10),
                      _tile('This week', _week),
                      const SizedBox(height: 20),
                      const Text(
                        'Recent ratings',
                        style: TextStyle(
                          color: RidonsColors.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_ratings.isEmpty)
                        _emptyRatings()
                      else
                        ..._ratings.map(_ratingTile),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tile(String label, DriverStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RidonsColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: RidonsColors.textSecondary)),
                Text(
                  '${_money.format(stats.total)} RWF',
                  style: const TextStyle(
                    color: RidonsColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${stats.trips} trips',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _emptyRatings() {
    return const Text(
      'No ratings received yet.',
      style: TextStyle(color: RidonsColors.textSecondary),
    );
  }

  Widget _ratingTile(ReceivedRating item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RidonsColors.border),
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
                      ? 'No comment'
                      : item.comment.trim(),
                  style: const TextStyle(color: RidonsColors.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM d, yyyy').format(item.createdAt)} · ${item.rideId}',
                  style: const TextStyle(
                    color: RidonsColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
