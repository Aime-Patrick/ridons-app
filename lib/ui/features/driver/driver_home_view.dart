import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/location_service.dart';
import '../../../data/services/places_service.dart';
import '../../../data/services/routing_service.dart';
import '../../../domain/models/ride_offer.dart';
import '../../../domain/models/session_user.dart';
import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_notification_bell.dart';
import '../../core/widgets/ridons_price_adjuster.dart';
import '../../core/widgets/ridons_rating_prompt.dart';
import '../account/passenger_avatar.dart';
import '../notifications/notification_inbox_view.dart';
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
      return ColoredBox(
        color: context.ridonsPage,
        child: const Center(child: CircularProgressIndicator()),
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
    final notificationCenter = ref.watch(notificationCenterProvider);
    final stats = viewModel.stats;
    return ColoredBox(
      color: context.ridonsPage,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: RidonsColors.primary,
          onRefresh: viewModel.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _DriverSummaryCard(
                user: user,
                session: session,
                stats: stats,
                hidden: viewModel.hideEarnings,
                unreadCount: notificationCenter.unreadCount,
                onToggleHidden: viewModel.toggleEarningsHidden,
                onNotifications: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationInboxView(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _AvailabilityCard(
                online: viewModel.online,
                busy: viewModel.onlineBusy,
                onChanged: viewModel.toggleOnline,
              ),
              if (viewModel.pendingRatingRideId != null) ...[
                const SizedBox(height: 16),
                RidonsRatingPrompt(
                  title: viewModel.pendingRatingPassengerName.isEmpty
                      ? 'rate_passenger'.tr()
                      : 'rate_named_passenger'.tr(
                          namedArgs: {
                            'name': viewModel.pendingRatingPassengerName,
                          },
                        ),
                  value: viewModel.passengerRating,
                  onChanged: viewModel.setPassengerRating,
                  onCommentChanged: viewModel.setPassengerRatingComment,
                  onSubmit: viewModel.submitPassengerRating,
                  isLoading: viewModel.passengerRatingBusy,
                  errorMessage: viewModel.passengerRatingError,
                ),
              ],
              if (viewModel.quests.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'quests'.tr(),
                  style: TextStyle(
                    color: context.ridonsInk,
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
                  viewModel.errorMessage!.tr(
                    namedArgs: {
                      'amount': (viewModel.counteredAmount ?? '').toString(),
                    },
                  ),
                  style: TextStyle(color: RidonsColors.primary),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'available_offers'.tr(),
                style: TextStyle(
                  color: context.ridonsInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (!viewModel.online)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'go_online_offers'.tr(),
                    style: TextStyle(color: context.ridonsMuted),
                  ),
                )
              else if (viewModel.offers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'no_offers_yet'.tr(),
                        style: TextStyle(color: context.ridonsMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats.priorityDispatch
                            ? 'priority_riders_first'.tr()
                            : 'rating_priority_offers'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.ridonsMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 390,
                  child: ListView.separated(
                    primary: false,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: viewModel.offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final offer = viewModel.offers[index];
                      return _OfferCard(
                        offer: offer,
                        fare: viewModel.fareFor(offer),
                        busy: viewModel.busy,
                        onAdjust: (delta) => viewModel.adjustFare(offer, delta),
                        onSkip: () => viewModel.skip(offer),
                        onAccept: () => viewModel.accept(offer),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverSummaryCard extends StatelessWidget {
  const _DriverSummaryCard({
    required this.user,
    required this.session,
    required this.stats,
    required this.hidden,
    required this.unreadCount,
    required this.onToggleHidden,
    required this.onNotifications,
  });

  final SessionUser user;
  final AuthSession session;
  final DriverStats stats;
  final bool hidden;
  final int unreadCount;
  final VoidCallback onToggleHidden;
  final VoidCallback onNotifications;

  static final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PassengerAvatar(
                      user: user,
                      radius: 25,
                      token: session.token,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'driver_id_caption'.tr(
                              namedArgs: {'id': user.driverIdLabel},
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    stats.priorityDispatch
                                        ? 'priority_dispatch'.tr(
                                            namedArgs: {
                                              'tier': stats.tierLabel,
                                            },
                                          )
                                        : stats.tierLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: RidonsColors.accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconTheme.merge(
                      data: const IconThemeData(color: Colors.white),
                      child: RidonsNotificationBell(
                        unreadCount: unreadCount,
                        onPressed: onNotifications,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'rwf_earned'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Semantics(
                      button: true,
                      label: hidden
                          ? 'show_earnings'.tr()
                          : 'hide_earnings'.tr(),
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
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hidden ? '********' : _money.format(stats.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(
                      'rating',
                      stats.avgRating == 0
                          ? ''
                          : stats.avgRating.toStringAsFixed(1),
                      labelFontSize: 11,
                      valueFontSize: 13,
                      dividerHeight: 34,
                    ),
                    _Stat(
                      'trips',
                      stats.trips.toString(),
                      labelFontSize: 11,
                      valueFontSize: 13,
                      dividerHeight: 34,
                    ),
                    _Stat(
                      'accept',
                      '%',
                      labelFontSize: 11,
                      valueFontSize: 13,
                      dividerHeight: 34,
                    ),
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

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.online,
    required this.busy,
    required this.onChanged,
  });

  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final background = online ? RidonsColors.primary : const Color(0xFFE5E5E7);
    final foreground = online ? Colors.white : RidonsColors.navy;
    return Semantics(
      button: true,
      toggled: online,
      label: busy
          ? 'updating_online_status'.tr()
          : (online ? 'you_are_now_online'.tr() : 'click_to_go_online'.tr()),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => onChanged(!online),
          child: SizedBox(
            height: 132,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(foreground),
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: 50,
                        color: foreground,
                      ),
                const SizedBox(height: 10),
                Text(
                  busy
                      ? 'updating_online_status'.tr()
                      : (online
                            ? 'you_are_now_online'.tr()
                            : 'click_to_go_online'.tr()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
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
  const _Stat(
    this.label,
    this.value, {
    required this.labelFontSize,
    required this.valueFontSize,
    required this.dividerHeight,
  });

  final String label;
  final String value;
  final double labelFontSize;
  final double valueFontSize;
  final double dividerHeight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          if (label != 'rating') _StatDivider(height: dividerHeight),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: label == 'rating' ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: labelFontSize,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: valueFontSize,
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
  const _StatDivider({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: height,
      child: CustomPaint(painter: _DottedLinePainter()),
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
      color: context.ridonsSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.ridonsLine),
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
                    style: TextStyle(
                      color: context.ridonsInk,
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
                backgroundColor: context.ridonsFill,
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
              style: TextStyle(color: context.ridonsMuted, fontSize: 12),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final compact = width < 340;
        final horizontalPadding = (width * 0.045).clamp(12.0, 20.0).toDouble();
        final titleFontSize = (width * 0.045).clamp(14.0, 16.0).toDouble();
        final detailFontSize = (width * 0.034).clamp(11.0, 12.0).toDouble();
        final routeFontSize = (width * 0.037).clamp(12.0, 14.0).toDouble();
        final labelFontSize = (width * 0.034).clamp(11.0, 12.0).toDouble();
        final buttonFontSize = (width * 0.04).clamp(12.0, 15.0).toDouble();
        final isCounter = fare > offer.offeredPrice;
        final actionLabel = isCounter
            ? 'counter_amount'.tr(namedArgs: {'amount': _money.format(fare)})
            : 'accept_offer'.tr();

        return Material(
          color: context.ridonsSheet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: context.ridonsLine),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 12 : 14,
              horizontalPadding,
              compact ? 12 : 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: (width * 0.07).clamp(22.0, 26.0).toDouble(),
                      backgroundColor: context.ridonsFill,
                      child: Text(
                        offer.displayName.isEmpty ? 'P' : offer.displayName[0],
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.ridonsInk,
                              fontWeight: FontWeight.w800,
                              fontSize: titleFontSize,
                            ),
                          ),
                          Text(
                            '${offer.passengerIdLabel}  ${offer.passengerPhone}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.ridonsMuted,
                              fontSize: detailFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          offer.timerLabel,
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: RidonsColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: detailFontSize,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: offer.fromName.isEmpty
                            ? 'pickup'.tr()
                            : offer.fromName,
                        style: TextStyle(
                          color: RidonsColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: routeFontSize,
                        ),
                      ),
                      TextSpan(
                        text: '  →  ',
                        style: TextStyle(color: context.ridonsMuted),
                      ),
                      TextSpan(
                        text: offer.toName.isEmpty
                            ? 'dropoff'.tr()
                            : offer.toName,
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontWeight: FontWeight.w700,
                          fontSize: routeFontSize,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (offer.negotiationRound > 0) ...[
                  SizedBox(height: compact ? 6 : 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'negotiation_round'.tr(
                        namedArgs: {
                          'round': '${offer.negotiationRound}',
                          'max': '${offer.maxNegotiationRounds}',
                        },
                      ),
                      style: TextStyle(
                        color: context.ridonsMuted,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 11 : 14),
                Row(
                  children: [
                    Expanded(
                      child: _PriceCol(
                        'passenger_offer',
                        '${_money.format(offer.offeredPrice)} Rwf',
                        labelFontSize: labelFontSize,
                        valueFontSize: routeFontSize + 3,
                      ),
                    ),
                    Expanded(
                      child: _PriceCol(
                        'fair_price',
                        '${_money.format(offer.suggestedPrice == 0 ? offer.offeredPrice : offer.suggestedPrice)} Rwf',
                        alignEnd: true,
                        labelFontSize: labelFontSize,
                        valueFontSize: routeFontSize + 3,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                RidonsPriceAdjuster(
                  amountRwf: fare,
                  onDecrement: () => onAdjust(-100),
                  onIncrement: () => onAdjust(100),
                ),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onSkip,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(compact ? 44 : 48),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 12,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'skip'.tr(),
                            style: TextStyle(fontSize: buttonFontSize),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: busy ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.fromHeight(compact ? 44 : 48),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 12,
                          ),
                          backgroundColor: RidonsColors.primary,
                          shape: const StadiumBorder(),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            actionLabel,
                            maxLines: 1,
                            style: TextStyle(fontSize: buttonFontSize),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriceCol extends StatelessWidget {
  const _PriceCol(
    this.label,
    this.value, {
    this.alignEnd = false,
    this.labelFontSize = 12,
    this.valueFontSize = 18,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(),
          style: TextStyle(color: context.ridonsMuted, fontSize: labelFontSize),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: context.ridonsInk,
              fontWeight: FontWeight.w800,
              fontSize: valueFontSize,
            ),
          ),
        ),
      ],
    );
  }
}
