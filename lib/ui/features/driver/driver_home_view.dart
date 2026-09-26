import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/services/location_service.dart';
import '../../../data/services/places_service.dart';
import '../../../data/services/routing_service.dart';
import '../../../domain/models/ride_offer.dart';
import '../../../domain/models/session_user.dart';
import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_price_adjuster.dart';
import '../account/passenger_avatar.dart';
import 'driver_trip_view.dart';
import 'view_models/driver_home_view_model.dart';

class DriverHomeView extends ConsumerStatefulWidget {
  const DriverHomeView({super.key, this.onTripChanged});

  final ValueChanged<bool>? onTripChanged;

  @override
  ConsumerState<DriverHomeView> createState() => DriverHomeViewState();
}

class DriverHomeViewState extends ConsumerState<DriverHomeView> {
  DriverHomeViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    final session = ref.read(authSessionProvider).asData?.value;
    final user = session?.user;
    if (user == null) return;
    _vm = DriverHomeViewModel(
      locationService: LocationService(),
      placesService: PlacesService(apiClient: ref.read(apiClientProvider)),
      routingService: RoutingService(),
      geoApi: ref.read(geoApiProvider),
      tripApi: ref.read(tripApiProvider),
      realtime: ref.read(realtimeClientProvider),
      authRepository: ref.read(authRepositoryProvider),
      user: user,
      onSessionRefreshed: (session) {
        ref.read(authSessionProvider.notifier).setSession(session);
      },
    )..addListener(_onVm);
    _vm!.bootstrap();
  }

  void _onVm() {
    widget.onTripChanged?.call(_vm?.onTrip ?? false);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm
      ?..removeListener(_onVm)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final session = ref.watch(authSessionProvider).asData?.value;
    if (vm == null || session == null) {
      return const ColoredBox(
        color: RidonsColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vm.onTrip) {
      return DriverTripView(viewModel: vm);
    }
    return _DriverIdleHome(viewModel: vm, session: session);
  }
}

class _DriverIdleHome extends ConsumerWidget {
  const _DriverIdleHome({required this.viewModel, required this.session});

  final DriverHomeViewModel viewModel;
  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = session.user;
    final badge = ref.watch(notificationBadgeProvider).asData?.value ?? 0;
    final stats = viewModel.stats;
    return ColoredBox(
      color: RidonsColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: RidonsColors.primary,
          onRefresh: viewModel.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  PassengerAvatar(user: user, radius: 28, token: session.token),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: RidonsColors.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Driver ID · ${user.driverIdLabel}',
                          style: const TextStyle(
                            color: RidonsColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (stats.hasTierBadge)
                          Row(
                            children: [
                              Icon(
                                stats.tier == 'platinum'
                                    ? Icons.workspace_premium_rounded
                                    : Icons.star_rounded,
                                color: RidonsColors.accent,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stats.priorityDispatch
                                    ? '${stats.tierLabel} · Priority dispatch'
                                    : stats.tierLabel,
                                style: const TextStyle(
                                  color: RidonsColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (badge > 0)
                        const Positioned(
                          right: 10,
                          top: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: RidonsColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 8, height: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _EarningsCard(
                stats: stats,
                hidden: viewModel.hideEarnings,
                online: viewModel.online,
                onlineBusy: viewModel.onlineBusy,
                onToggleHidden: viewModel.toggleEarningsHidden,
                onToggleOnline: viewModel.toggleOnline,
              ),
              if (viewModel.quests.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Quests',
                  style: TextStyle(
                    color: RidonsColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final quest in viewModel.quests) ...[
                  _QuestCard(quest: quest),
                  const SizedBox(height: 10),
                ],
              ],
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: RidonsColors.primary),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'Available offers',
                style: TextStyle(
                  color: RidonsColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (!viewModel.online)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Go online to receive passenger offers.',
                    style: TextStyle(color: RidonsColors.textSecondary),
                  ),
                )
              else if (viewModel.offers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Text(
                        'No offers nearby yet.',
                        style: TextStyle(color: RidonsColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats.priorityDispatch
                            ? 'Gold and Platinum riders see new offers first.'
                            : 'Keep rating high to see offers before nearby riders.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: RidonsColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final offer in viewModel.offers) ...[
                  _OfferCard(
                    offer: offer,
                    fare: viewModel.fareFor(offer),
                    busy: viewModel.busy,
                    onAdjust: (delta) => viewModel.adjustFare(offer, delta),
                    onSkip: () => viewModel.skip(offer),
                    onAccept: () => viewModel.accept(offer),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.stats,
    required this.hidden,
    required this.online,
    required this.onlineBusy,
    required this.onToggleHidden,
    required this.onToggleOnline,
  });

  final DriverStats stats;
  final bool hidden;
  final bool online;
  final bool onlineBusy;
  final VoidCallback onToggleHidden;
  final ValueChanged<bool> onToggleOnline;

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8D1D2D), Color(0xFF5D1C2A), Color(0xFF241A2B)],
          ),
        ),
        child: CustomPaint(
          foregroundPainter: const _EarningsPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'RWF Earned',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Semantics(
                                button: true,
                                label: hidden
                                    ? 'Show earnings'
                                    : 'Hide earnings',
                                child: GestureDetector(
                                  onTap: onToggleHidden,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      hidden
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hidden ? '********' : _money.format(stats.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _OnlineToggle(
                          value: online,
                          busy: onlineBusy,
                          onChanged: onToggleOnline,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                Container(height: 2, color: Colors.white24),
                const SizedBox(height: 23),
                Row(
                  children: [
                    _Stat(
                      'Rating',
                      stats.avgRating == 0
                          ? '—'
                          : stats.avgRating.toStringAsFixed(1),
                    ),
                    _Stat('Trips', '${stats.trips}'),
                    _Stat('Accept', '${stats.acceptanceRate}%'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          if (label != 'Rating') const _StatDivider(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: label == 'Rating' ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 53,
      child: CustomPaint(painter: _DottedLinePainter()),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: busy ? 'Updating online status' : (value ? 'Online' : 'Offline'),
      child: GestureDetector(
        onTap: busy ? null : () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 66,
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? RidonsColors.primary : Colors.white24,
            borderRadius: BorderRadius.circular(99),
          ),
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Align(
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EarningsPatternPainter extends CustomPainter {
  const _EarningsPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var x = -size.height; x < size.width + size.height; x += 92) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x + 46, 0),
        Offset(x - size.height + 46, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EarningsPatternPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 2.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) => false;
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final DriverQuest quest;

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RidonsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: RidonsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quest.completed
                      ? Icons.check_circle_rounded
                      : Icons.flag_rounded,
                  color: quest.completed
                      ? RidonsColors.success
                      : RidonsColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      color: RidonsColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '+${_money.format(quest.reward)} RWF',
                  style: TextStyle(
                    color: quest.completed
                        ? RidonsColors.success
                        : RidonsColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: quest.fraction,
                minHeight: 6,
                backgroundColor: RidonsColors.inputFill,
                color: quest.completed
                    ? RidonsColors.success
                    : RidonsColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              quest.completed
                  ? '${quest.current} / ${quest.total} · Completed'
                  : '${quest.current} / ${quest.total}',
              style: const TextStyle(
                color: RidonsColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.fare,
    required this.busy,
    required this.onAdjust,
    required this.onSkip,
    required this.onAccept,
  });

  final RideOffer offer;
  final int fare;
  final bool busy;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;
  final VoidCallback onAccept;

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RidonsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: RidonsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: RidonsColors.inputFill,
                  child: Text(
                    offer.displayName.isEmpty ? 'P' : offer.displayName[0],
                    style: const TextStyle(
                      color: RidonsColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RidonsColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${offer.passengerIdLabel}  ${offer.passengerPhone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RidonsColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    offer.timerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: RidonsColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: offer.fromName.isEmpty ? 'Pickup' : offer.fromName,
                    style: const TextStyle(
                      color: RidonsColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text: '  →  ',
                    style: TextStyle(color: RidonsColors.textSecondary),
                  ),
                  TextSpan(
                    text: offer.toName.isEmpty ? 'Dropoff' : offer.toName,
                    style: const TextStyle(
                      color: RidonsColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PriceCol(
                    'Passenger offer',
                    '${_money.format(offer.offeredPrice)} Rwf',
                  ),
                ),
                Expanded(
                  child: _PriceCol(
                    'Fair Price',
                    '${_money.format(offer.suggestedPrice == 0 ? offer.offeredPrice : offer.suggestedPrice)} Rwf',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RidonsPriceAdjuster(
              amountRwf: fare,
              onDecrement: () => onAdjust(-100),
              onIncrement: () => onAdjust(100),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onSkip,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: busy ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: RidonsColors.primary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Accept offer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCol extends StatelessWidget {
  const _PriceCol(this.label, this.value, {this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: RidonsColors.textSecondary,
            fontSize: 12,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: RidonsColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}
