import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/config/api_config.dart';
import '../../../core/theme/ridons_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../../domain/models/ride_stage.dart';
import '../../../../domain/models/ride_bid.dart';
import '../view_models/home_map_view_model.dart';

class RideFlowPanel extends StatelessWidget {
  const RideFlowPanel({
    super.key,
    required this.viewModel,
    this.decorate = true,
  });

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return switch (viewModel.stage) {
      RideStage.route || RideStage.preview => _RouteSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.search => _SearchSheet(viewModel: viewModel),
      RideStage.pickOnMap => _MapPickSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.estimate => _EstimateSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.offering => _OfferingSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.matched => _MatchedSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.payment => _PaymentSheet(
        viewModel: viewModel,
        decorate: decorate,
      ),
      RideStage.success => _SuccessSheet(viewModel: viewModel),
    };
  }
}

/// Pickup → dropoff chip on a full-screen destination map.
class RouteHeaderChip extends StatelessWidget {
  const RouteHeaderChip({
    super.key,
    required this.viewModel,
    this.visible = false,
  });

  final HomeMapViewModel viewModel;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || viewModel.dropoffLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: context.ridonsSheet,
          elevation: 6,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  onPressed: viewModel.cancelRide,
                  icon: Icon(Icons.close, size: 20, color: context.ridonsInk),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            viewModel.pickupLabel.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RidonsColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: context.ridonsInk,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            viewModel.dropoffLabel.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.ridonsInk,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Google-style ETA chip for the route polyline midpoint.
class RouteEtaMapBadge extends StatelessWidget {
  const RouteEtaMapBadge({super.key, required this.viewModel});

  final HomeMapViewModel viewModel;

  bool get _visible {
    if (viewModel.dropoff == null) return false;
    return viewModel.stage == RideStage.preview ||
        viewModel.stage == RideStage.estimate ||
        viewModel.stage == RideStage.offering ||
        viewModel.stage == RideStage.matched ||
        viewModel.loadingRoute;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final loading = viewModel.loadingRoute && viewModel.tripDurationMin < 1;
    final eta = viewModel.tripEtaLabel;
    final km = viewModel.tripDistanceLabel;
    final ink = context.ridonsInk;
    final muted = context.ridonsMuted;

    return Material(
      color: context.ridonsSheet,
      elevation: 6,
      shadowColor: const Color(0x33000000),
      shape: StadiumBorder(side: BorderSide(color: context.ridonsLine)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RidonsColors.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eta,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1,
                    ),
                  ),
                  if (viewModel.tripKm > 0) ...[
                    Container(
                      width: 1,
                      height: 13,
                      margin: const EdgeInsets.symmetric(horizontal: 9),
                      color: context.ridonsLine,
                    ),
                    Text(
                      km,
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Map overlay matching the Allow location access sheet.
class LocationAccessSheet extends StatelessWidget {
  const LocationAccessSheet({
    super.key,
    required this.onAllow,
    required this.onSkip,
    this.locating = false,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ridonsSheet,
      elevation: 16,
      shadowColor: const Color(0x33000000),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/brand/Addrees.svg',
                    height: 148,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'allow_location_access'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.ridonsInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'location_permission_description'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.ridonsMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  RidonsButton(
                    label: 'allow_location_access',
                    isLoading: locating,
                    onPressed: onAllow,
                  ),
                  const SizedBox(height: 10),
                  RidonsButton(
                    label: 'maybe_later',
                    variant: RidonsButtonVariant.secondary,
                    onPressed: locating ? null : onSkip,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: locating ? null : onSkip,
                icon: Icon(Icons.close, size: 20, color: context.ridonsInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSheet extends StatelessWidget {
  const _RouteSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return RidonsBottomSheet(
      title: 'route',
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RideLocationField(
            value: viewModel.pickupLabel,
            hint: 'my_current_location',
            showMapThumb: true,
            onTap: () => viewModel.openSearch(LocationField.pickup),
            onPinTap: () => viewModel.openMapPickerFor(LocationField.pickup),
          ),
          const SizedBox(height: 8),
          RideLocationField(
            value: viewModel.dropoffLabel,
            hint: 'choose_dropoff_location',
            onTap: () => viewModel.openSearch(LocationField.dropoff),
            onPinTap: () => viewModel.openMapPickerFor(LocationField.dropoff),
          ),
          if (viewModel.dropoff != null) ...[
            const SizedBox(height: 12),
            RidonsButton(
              label: 'continue',
              onPressed: viewModel.continueFromRoute,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.viewModel});

  final HomeMapViewModel viewModel;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final pickupActive = viewModel.activeField == LocationField.pickup;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: viewModel.closeSearch,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                  Text(
                    'route'.tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  RideLocationField(
                    value: viewModel.pickupLabel,
                    hint: 'my_location',
                    highlighted: pickupActive,
                    controller: pickupActive ? _searchController : null,
                    onTap: () {
                      _searchController.clear();
                      viewModel.openSearch(LocationField.pickup);
                    },
                    onChanged: pickupActive ? viewModel.updateSearch : null,
                    onPinTap: () =>
                        viewModel.openMapPickerFor(LocationField.pickup),
                  ),
                  const SizedBox(height: 8),
                  RideLocationField(
                    value: viewModel.dropoffLabel,
                    hint: 'choose_dropoff_location',
                    highlighted: !pickupActive,
                    autofocus: !pickupActive,
                    controller: pickupActive ? null : _searchController,
                    onChanged: pickupActive ? null : viewModel.updateSearch,
                    onTap: () {
                      _searchController.clear();
                      viewModel.openSearch(LocationField.dropoff);
                    },
                    onPinTap: () =>
                        viewModel.openMapPickerFor(LocationField.dropoff),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: viewModel.searchingPlaces && viewModel.suggestions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.suggestions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          viewModel.searchQuery.trim().isEmpty
                              ? 'looking_up_places'.tr()
                              : 'no_places_match'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: viewModel.suggestions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        color: context.ridonsLine,
                      ),
                      itemBuilder: (context, index) {
                        final place = viewModel.suggestions[index];
                        return RidonsLocationTile(
                          title: place.name,
                          subtitle: place.subtitle.isEmpty
                              ? null
                              : place.subtitle,
                          onTap: () => viewModel.choosePlace(place),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPickSheet extends StatelessWidget {
  const _MapPickSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final candidate = viewModel.pickCandidate;
    return RidonsBottomSheet(
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: viewModel.closeMapPicker,
                icon: const Icon(Icons.close, size: 20),
              ),
              Expanded(
                child: Text(
                  'pick_from_map'.tr(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (viewModel.resolvingPin) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  (candidate?.name ?? 'tap_map_drop_pin').tr(),
                  style: TextStyle(color: context.ridonsMuted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RidonsButton(
            label: 'use_this_location',
            onPressed: candidate == null ? null : viewModel.confirmMapPick,
          ),
        ],
      ),
    );
  }
}

class _EstimateSheet extends StatelessWidget {
  const _EstimateSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return RidonsBottomSheet(
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitleRow(
            title: 'price_estimation',
            trailing: viewModel.timerLabel,
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.lastOfferMissed
                ? (viewModel.lastOfferHadRiders
                      ? 'nobody_took_fare'.tr()
                      : 'no_nearby_riders'.tr())
                : viewModel.tripKm > 0
                ? 'about_route_by_road'.tr(
                    namedArgs: {
                      'distance': viewModel.tripDistanceLabel,
                      'eta': viewModel.tripEtaLabel,
                    },
                  )
                : 'market_fair_price'.tr(),
            style: TextStyle(color: context.ridonsMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          RidonsPriceAdjuster(
            amountRwf: viewModel.offeredPrice,
            enabled:
                !viewModel.loadingFareEstimate && viewModel.offeredPrice > 0,
            onDecrement: () => viewModel.adjustPrice(-100),
            onIncrement: () => viewModel.adjustPrice(100),
          ),
          if (viewModel.loadingFareEstimate) ...[
            const SizedBox(height: 8),
            Text('loading_current_fare'.tr(), textAlign: TextAlign.center),
          ],
          if (viewModel.fareEstimateError != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.fareEstimateError!.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.ridonsMuted, fontSize: 12),
            ),
            TextButton(
              onPressed: viewModel.retryFareEstimate,
              child: Text('retry'.tr()),
            ),
          ],
          const SizedBox(height: 10),
          RidonsButton(
            label: 'confirm',
            onPressed:
                viewModel.loadingFareEstimate || viewModel.offeredPrice <= 0
                ? null
                : viewModel.confirmOffer,
          ),
          const SizedBox(height: 8),
          _RouteSummary(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _OfferingSheet extends StatelessWidget {
  const _OfferingSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return RidonsBottomSheet(
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'offering_your_fare'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.driversNotified == 0
                      ? 'no_drivers_received_offer'.tr()
                      : 'drivers_notified'.tr(
                          namedArgs: {
                            'count': '${viewModel.driversNotified}',
                            'driverWord': viewModel.driversNotified == 1
                                ? 'driver'.tr()
                                : 'drivers'.tr(),
                            'eta': viewModel.etaLabel,
                          },
                        ),
                  style: TextStyle(color: context.ridonsMuted, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                viewModel.timerLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RidonsPriceAdjuster(
            amountRwf: viewModel.offeredPrice,
            enabled: false,
            onDecrement: () {},
            onIncrement: () {},
          ),
          if (viewModel.counterOffers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CounterOffersPanel(viewModel: viewModel),
          ],
          if (viewModel.bidError != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.bidError!.tr(),
              style: TextStyle(color: context.ridonsMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          RidonsButton(label: 'confirm', onPressed: null),
          const SizedBox(height: 12),
          _RouteSummary(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _CounterOffersPanel extends StatelessWidget {
  const _CounterOffersPanel({required this.viewModel});

  final HomeMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final offers = viewModel.counterOffers;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RidonsColors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: RidonsColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.two_wheeler,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offers.length == 1
                            ? 'driver_sent_counter_offer'.tr()
                            : 'drivers_sent_counter_offers'.tr(
                                namedArgs: {'count': '${offers.length}'},
                              ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'choose_before_expiry'.tr(),
                        style: TextStyle(
                          color: context.ridonsMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.forum_outlined, color: RidonsColors.primary),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < offers.length; index++) ...[
              if (index > 0) Divider(color: context.ridonsLine, height: 20),
              _CounterOfferTile(
                bid: offers[index],
                originalPrice: viewModel.offeredPrice,
                busy: viewModel.bidBusy,
                onAccept: () => viewModel.acceptCounterOffer(offers[index]),
                onDecline: () => viewModel.rejectCounterOffer(offers[index]),
                onCounter: (price) =>
                    viewModel.counterBack(offers[index], price),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CounterOfferTile extends StatefulWidget {
  const _CounterOfferTile({
    required this.bid,
    required this.originalPrice,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  final RideBid bid;
  final int originalPrice;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final ValueChanged<int> onCounter;

  @override
  State<_CounterOfferTile> createState() => _CounterOfferTileState();
}

class _CounterOfferTileState extends State<_CounterOfferTile> {
  late int _counterPrice;

  @override
  void initState() {
    super.initState();
    _counterPrice = widget.originalPrice;
  }

  @override
  void didUpdateWidget(covariant _CounterOfferTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bid.bidId != widget.bid.bidId) {
      _counterPrice = widget.originalPrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;
    final avatarUrl = bid.driverAvatarUrl;
    final resolvedAvatarUrl = avatarUrl == null
        ? null
        : avatarUrl.startsWith('http')
        ? avatarUrl
        : '${defaultGatewayUrl()}$avatarUrl';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: RidonsColors.primaryLight,
              backgroundImage: resolvedAvatarUrl == null
                  ? null
                  : CachedNetworkImageProvider(resolvedAvatarUrl),
              child: resolvedAvatarUrl == null
                  ? Text(
                      (bid.driverName.isNotEmpty
                              ? bid.driverName
                              : bid.driverLabel)[0]
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bid.driverName.isNotEmpty
                        ? bid.driverName
                        : bid.driverLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (bid.driverRating > 0)
                    Text(
                      '★ ${bid.driverRating.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: context.ridonsMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              bid.proximityLabel,
              style: TextStyle(color: context.ridonsMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'round_of'.tr(
            namedArgs: {
              'round': '${bid.negotiationRound}',
              'total': '${bid.maxNegotiationRounds}',
            },
          ),
          style: TextStyle(color: context.ridonsMuted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CounterPrice(
                label: 'your_offer',
                value: '${widget.originalPrice} Rwf',
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            Expanded(
              child: _CounterPrice(
                label: 'driver_asks',
                value: '${bid.price} Rwf',
                emphasized: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RidonsPriceAdjuster(
          amountRwf: _counterPrice,
          enabled: !widget.busy,
          onDecrement: () => setState(() {
            _counterPrice = (_counterPrice - 100).clamp(500, 1000000).toInt();
          }),
          onIncrement: () => setState(() {
            _counterPrice += 100;
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.busy
                    ? null
                    : () => widget.onCounter(_counterPrice),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(color: context.ridonsLine),
                ),
                child: Text('counter_offer'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.busy ? null : widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RidonsColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
                child: Text('accept'.tr()),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: widget.busy ? null : widget.onDecline,
          child: Text('leave_it'.tr()),
        ),
      ],
    );
  }
}

class _CounterPrice extends StatelessWidget {
  const _CounterPrice({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: emphasized
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(),
          style: TextStyle(color: context.ridonsMuted, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value.tr(),
          style: TextStyle(
            color: emphasized ? RidonsColors.primary : context.ridonsInk,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _MatchedSheet extends StatelessWidget {
  const _MatchedSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final driver = viewModel.matchedDriver;
    return RidonsTripSheet(
      title: viewModel.rideStatusLabel,
      decorate: decorate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            viewModel.etaLabel,
            style: const TextStyle(
              color: RidonsColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            viewModel.liveRideStatus == 'matched'
                ? Icons.lock_outline
                : Icons.route_rounded,
            size: 18,
            color: context.ridonsInk,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.ridonsFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: RidonsDriverCard(
              name: driver?.name.isNotEmpty == true
                  ? driver!.name
                  : 'driver_details_pending',
              plate: driver?.plate ?? '',
              rating: driver?.rating ?? 0,
              avatarUrl: driver?.avatarUrl,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  label: 'agreed_fare',
                  value: '${viewModel.payableFare} Rwf',
                ),
              ),
              const Expanded(
                child: _Fact(label: 'payment_method', value: 'cash_or_momo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteSummary(viewModel: viewModel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: viewModel.driverPhone.trim().isEmpty
                      ? null
                      : () => _callDriver(context, viewModel.driverPhone),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: Text('call_driver'.tr()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: viewModel.sharingTrip
                      ? null
                      : () => _shareTrip(context, viewModel),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text(
                    viewModel.sharingTrip
                        ? 'creating_link'.tr()
                        : 'share_trip'.tr(),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openNeedHelpDialog(context, viewModel),
              icon: const Icon(Icons.help_outline, size: 16),
              label: Text('need_help'.tr()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          if (viewModel.liveRideStatus == 'completed') ...[
            const SizedBox(height: 10),
            RidonsButton(
              label: 'continue_to_payment',
              onPressed: viewModel.goToPayment,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return RidonsBottomSheet(
      title: 'payment',
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'payment_confirmation_description'.tr(),
            style: TextStyle(
              color: context.ridonsMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _PaymentOption(
            label: 'cash',
            selected: viewModel.paymentMethod == 'Cash',
            onTap: () => viewModel.selectPayment('Cash'),
          ),
          const SizedBox(height: 8),
          _PaymentOption(
            label: 'mobile_money',
            selected: viewModel.paymentMethod == 'Mobile Money',
            onTap: () => viewModel.selectPayment('Mobile Money'),
          ),
          const SizedBox(height: 16),
          RidonsButton(
            label: 'ive_paid_amount'.tr(
              namedArgs: {'amount': '${viewModel.payableFare}'},
            ),
            onPressed: viewModel.confirmPayment,
          ),
        ],
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.viewModel});

  final HomeMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.ridonsSheet,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: RidonsColors.primary,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 18),
              Text(
                'trip_recorded_successfully'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              _TripReceiptCard(viewModel: viewModel),
              const SizedBox(height: 28),
              RidonsRatingPrompt(
                title: 'how_was_ride',
                value: viewModel.rating,
                onChanged: viewModel.setRating,
                onCommentChanged: viewModel.setRatingComment,
                onSubmit: viewModel.submitRating,
                submitLabel: 'send_rating',
                isLoading: viewModel.ratingBusy,
                errorMessage: viewModel.ratingError,
              ),
              const SizedBox(height: 10),
              RidonsButton(
                label: 'report_a_problem',
                variant: RidonsButtonVariant.secondary,
                onPressed: () => _openNeedHelpDialog(
                  context,
                  viewModel,
                  defaultSubject: 'problem_completed_trip',
                  category: 'ride',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripReceiptCard extends StatelessWidget {
  const _TripReceiptCard({required this.viewModel});

  final HomeMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ink = context.ridonsInk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        children: [
          _ReceiptLine(
            label: 'paid_to_driver',
            trailing: Text(
              '${viewModel.payableFare} Rwf',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReceiptLine(
            labelWidget: Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: viewModel.pickupLabel.tr(),
                      style: const TextStyle(
                        color: RidonsColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: '  →  ',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: viewModel.dropoffLabel.tr(),
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Text(
              viewModel.tripDistanceLabel,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReceiptLine(
            label: 'driver',
            trailing: Text(
              viewModel.driverReceiptLabel.tr(),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReceiptLine(
            label: 'record_number',
            trailing: Text(
              viewModel.recordNumber,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: viewModel.receiptSummary),
                    );
                    if (!context.mounted) return;
                    RidonsNotice.success(context, 'record_copied');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    backgroundColor: context.ridonsSheet,
                    side: BorderSide(color: context.ridonsLine),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'share_record'.tr(),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    RidonsNotice.info(context, 'pdf_coming_soon');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    backgroundColor: context.ridonsSheet,
                    side: BorderSide(color: context.ridonsLine),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'download_pdf'.tr(),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({this.label, this.labelWidget, required this.trailing});

  final String? label;
  final Widget? labelWidget;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (labelWidget != null) ...[
          labelWidget!,
          const SizedBox(width: 8),
          trailing,
        ] else ...[
          Text(
            label ?? '',
            style: TextStyle(color: context.ridonsMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ],
    );
  }
}

class RideLocationField extends StatelessWidget {
  const RideLocationField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
    this.onPinTap,
    this.onChanged,
    this.controller,
    this.highlighted = false,
    this.showMapThumb = false,
    this.autofocus = false,
  });

  final String value;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onPinTap;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool highlighted;
  final bool showMapThumb;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      hintText: hint.tr(),
      prefixIcon: const Icon(Icons.search, size: 18),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMapThumb)
            Container(
              width: 28,
              height: 22,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: context.ridonsFill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          IconButton(
            onPressed: onPinTap,
            icon: Icon(
              Icons.location_on,
              color: highlighted || onPinTap != null
                  ? RidonsColors.primary
                  : context.ridonsMuted,
              size: 22,
            ),
          ),
        ],
      ),
      filled: true,
      fillColor: context.ridonsSheet,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: highlighted ? RidonsColors.primary : context.ridonsLine,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RidonsColors.primary, width: 1.4),
      ),
    );

    if (controller != null) {
      return SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          onTap: onTap,
          onChanged: onChanged,
          style: TextStyle(
            color: context.ridonsInk,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: decoration,
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: GestureDetector(
        onTap: onTap,
        child: InputDecorator(
          decoration: decoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value.isEmpty ? hint.tr() : value.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: value.isEmpty ? context.ridonsMuted : context.ridonsInk,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.viewModel});

  final HomeMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryLine(icon: Icons.location_on, text: viewModel.pickupLabel),
        const SizedBox(height: 8),
        _SummaryLine(
          icon: Icons.location_on_outlined,
          text: viewModel.dropoffLabel.isEmpty
              ? 'choose_dropoff_location'
              : viewModel.dropoffLabel,
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.ridonsInk),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.tr(),
            style: TextStyle(
              color: context.ridonsInk,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetTitleRow extends StatelessWidget {
  const _SheetTitleRow({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(),
          style: TextStyle(color: context.ridonsMuted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.ridonsInk,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.ridonsSoft : context.ridonsFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RidonsColors.primary : context.ridonsLine,
            ),
          ),
          child: Row(
            children: [
              Icon(
                label == 'cash' ? Icons.payments_outlined : Icons.phone_iphone,
                color: RidonsColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.tr(),
                  style: TextStyle(
                    color: context.ridonsInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? RidonsColors.primary : context.ridonsLine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openNeedHelpDialog(
  BuildContext context,
  HomeMapViewModel viewModel, {
  String defaultSubject = 'need_help_with_ride',
  String category = 'ride',
}) async {
  final subject = TextEditingController(text: defaultSubject.tr());
  final body = TextEditingController();
  var submitting = false;

  final sent = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('need_help'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RidonsTextField(
                  controller: subject,
                  label: 'subject',
                  hint: 'what_do_you_need_help_with',
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'details'.tr(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.ridonsInk,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: body,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'describe_happened_optional'.tr(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final subj = subject.text.trim();
                        if (subj.length < 3) {
                          RidonsNotice.show(
                            context,
                            'short_subject_required',
                            tone: RidonsNoticeTone.warning,
                          );
                          return;
                        }
                        setState(() => submitting = true);
                        final id = await viewModel.requestHelp(
                          subject: subj,
                          body: body.text.trim().isEmpty
                              ? null
                              : body.text.trim(),
                          category: category,
                        );
                        if (!dialogContext.mounted) return;
                        if (id == null) {
                          setState(() => submitting = false);
                          RidonsNotice.error(context, 'support_unavailable');
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('send'.tr()),
              ),
            ],
          );
        },
      );
    },
  );

  subject.dispose();
  body.dispose();

  if (sent == true && context.mounted) {
    RidonsNotice.success(context, 'support_ticket_sent');
  }
}

Future<void> _callDriver(BuildContext context, String phone) async {
  final normalized = phone.trim();
  if (normalized.isEmpty) return;
  final launched = await launchUrl(
    Uri(scheme: 'tel', path: normalized),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    RidonsNotice.error(context, 'calling_unavailable');
  }
}

Future<void> _shareTrip(
  BuildContext context,
  HomeMapViewModel viewModel,
) async {
  final link = await viewModel.createTripShareLink();
  if (!context.mounted) return;
  if (link == null || link.isEmpty) {
    RidonsNotice.error(
      context,
      (viewModel.shareError ?? 'could_not_share_trip').tr(),
    );
    return;
  }

  final text = Uri.encodeComponent(
    'track_trip_message'.tr(namedArgs: {'link': link}),
  );
  final whatsapp = Uri.parse('whatsapp://send?text=$text');
  final openedWhatsApp = await launchUrl(
    whatsapp,
    mode: LaunchMode.externalApplication,
  );
  if (openedWhatsApp || !context.mounted) return;

  final browserFallback = Uri.parse('https://api.whatsapp.com/send?text=$text');
  final openedFallback = await launchUrl(
    browserFallback,
    mode: LaunchMode.externalApplication,
  );
  if (!openedFallback && context.mounted) {
    RidonsNotice.error(context, 'whatsapp_unavailable');
  }
}
