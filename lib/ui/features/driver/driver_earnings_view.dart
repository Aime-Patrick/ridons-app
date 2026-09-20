import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../../domain/models/ride_offer.dart';

class DriverEarningsView extends ConsumerStatefulWidget {
  const DriverEarningsView({super.key});

  @override
  ConsumerState<DriverEarningsView> createState() => _DriverEarningsViewState();
}

class _DriverEarningsViewState extends ConsumerState<DriverEarningsView> {
  DriverStats _today = const DriverStats();
  DriverStats _week = const DriverStats();
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
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
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
}
