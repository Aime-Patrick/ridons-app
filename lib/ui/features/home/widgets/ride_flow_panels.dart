import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/ridons_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../../domain/models/ride_stage.dart';
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
                            viewModel.pickupLabel,
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
                            viewModel.dropoffLabel,
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
  const RouteEtaMapBadge({
    super.key,
    required this.viewModel,
  });

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
      shape: StadiumBorder(
        side: BorderSide(color: context.ridonsLine),
      ),
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
                    'Allow location access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.ridonsInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We need your location to find nearby Moto Drivers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.ridonsMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  RidonsButton(
                    label: 'Allow location access',
                    isLoading: locating,
                    onPressed: onAllow,
                  ),
                  const SizedBox(height: 10),
                  RidonsButton(
                    label: 'Maybe later',
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
      title: 'Route',
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RideLocationField(
            value: viewModel.pickupLabel,
            hint: 'My current location',
            showMapThumb: true,
            onTap: () => viewModel.openSearch(LocationField.pickup),
            onPinTap: () => viewModel.openMapPickerFor(LocationField.pickup),
          ),
          const SizedBox(height: 8),
          RideLocationField(
            value: viewModel.dropoffLabel,
            hint: 'Choose dropoff location',
            onTap: () => viewModel.openSearch(LocationField.dropoff),
            onPinTap: () => viewModel.openMapPickerFor(LocationField.dropoff),
          ),
          if (viewModel.dropoff != null) ...[
            const SizedBox(height: 12),
            RidonsButton(
              label: 'Continue',
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
                  const Text(
                    'Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                    hint: 'My location',
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
                    hint: 'Choose dropoff location',
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
                                  ? 'Looking up places near you. You can also search or pick on the map.'
                                  : 'No places match that search. Try another name or pick on the map.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: viewModel.suggestions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
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
              const Expanded(
                child: Text(
                  'Pick from map',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
                  candidate?.name ?? 'Tap the map to drop a pin',
                  style: TextStyle(
                    color: context.ridonsMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RidonsButton(
            label: 'Use this location',
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
            title: 'Price estimation',
            trailing: viewModel.timerLabel,
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.lastOfferMissed
                ? (viewModel.lastOfferHadRiders
                    ? 'Nobody took that fare. Raise it and send again.'
                    : 'No riders within 3 km. Try again in a moment.')
                : viewModel.tripKm > 0
                    ? 'About ${viewModel.tripDistanceLabel} · ${viewModel.tripEtaLabel} by road'
                    : 'Market Fair price for this route.',
            style: TextStyle(
              color: context.ridonsMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          RidonsPriceAdjuster(
            amountRwf: viewModel.offeredPrice,
            onDecrement: () => viewModel.adjustPrice(-100),
            onIncrement: () => viewModel.adjustPrice(100),
          ),
          const SizedBox(height: 10),
          RidonsButton(
            label: 'Confirm',
            onPressed: viewModel.confirmOffer,
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
          const Text(
            'Offering your fare',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.driversViewing == 0
                      ? 'No riders within 3 km. Waiting in case one comes online…'
                      : '${viewModel.driversViewing} riders nearby · ETA ${viewModel.etaLabel}',
                  style: TextStyle(
                    color: context.ridonsMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (viewModel.driversViewing > 0) const _StackedAvatars(),
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
          const SizedBox(height: 12),
          const RidonsButton(
            label: 'Confirm',
            onPressed: null,
          ),
          const SizedBox(height: 12),
          _RouteSummary(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _MatchedSheet extends StatelessWidget {
  const _MatchedSheet({required this.viewModel, this.decorate = true});

  final HomeMapViewModel viewModel;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final driver = HomeMapViewModel.matchedDriver;
    return RidonsBottomSheet(
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Match found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                viewModel.etaLabel,
                style: const TextStyle(
                  color: RidonsColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline, size: 18, color: context.ridonsInk),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.ridonsFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: RidonsDriverCard(
              name: driver.name,
              plate: driver.plate,
              rating: driver.rating,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  label: 'Agreed fare',
                  value: '${viewModel.offeredPrice} Rwf',
                ),
              ),
              const Expanded(
                child: _Fact(
                  label: 'Payment method',
                  value: 'Cash or MoMo',
                ),
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
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share this trip'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Need help?'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RidonsButton(
            label: "I've arrived",
            onPressed: viewModel.goToPayment,
          ),
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
      title: 'Payment',
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay the driver directly. Confirm here when you’ve paid in cash or Mobile Money.',
            style: TextStyle(
              color: context.ridonsMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _PaymentOption(
            label: 'Cash',
            selected: viewModel.paymentMethod == 'Cash',
            onTap: () => viewModel.selectPayment('Cash'),
          ),
          const SizedBox(height: 8),
          _PaymentOption(
            label: 'Mobile Money',
            selected: viewModel.paymentMethod == 'Mobile Money',
            onTap: () => viewModel.selectPayment('Mobile Money'),
          ),
          const SizedBox(height: 16),
          RidonsButton(
            label: "I've paid ${viewModel.offeredPrice} RWF",
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
              const Text(
                'Trip recorded successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _TripReceiptCard(viewModel: viewModel),
              const SizedBox(height: 28),
              const Text(
                'How was the ride?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              RidonsStarRating(
                value: viewModel.rating,
                onChanged: viewModel.setRating,
                size: 34,
              ),
              const SizedBox(height: 18),
              RidonsButton(
                label: 'Send rate',
                onPressed: viewModel.resetToHome,
              ),
              const SizedBox(height: 10),
              RidonsButton(
                label: 'Report a problem',
                variant: RidonsButtonVariant.secondary,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Support is coming soon.'),
                    ),
                  );
                },
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
            label: 'Paid to the driver',
            trailing: Text(
              '${viewModel.offeredPrice} Rwf',
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
                      text: viewModel.pickupLabel,
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
                      text: viewModel.dropoffLabel,
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
            label: 'Driver',
            trailing: Text(
              viewModel.driverReceiptLabel,
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
            label: 'Record No.',
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record copied.')),
                    );
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
                  child: const Text(
                    'Share record',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF download is coming soon.'),
                      ),
                    );
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
                  child: const Text(
                    'Download PDF',
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
  const _ReceiptLine({
    this.label,
    this.labelWidget,
    required this.trailing,
  });

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
            style: TextStyle(
              color: context.ridonsMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
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
      hintText: hint,
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
              value.isEmpty ? hint : value,
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
        _SummaryLine(
          icon: Icons.location_on,
          text: viewModel.pickupLabel,
        ),
        const SizedBox(height: 8),
        _SummaryLine(
          icon: Icons.location_on_outlined,
          text: viewModel.dropoffLabel.isEmpty
              ? 'Choose dropoff location'
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
            text,
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
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
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
          label,
          style: TextStyle(
            color: context.ridonsMuted,
            fontSize: 11,
          ),
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
                label == 'Cash' ? Icons.payments_outlined : Icons.phone_iphone,
                color: RidonsColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
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

class _StackedAvatars extends StatelessWidget {
  const _StackedAvatars();

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF0F172A),
      Color(0xFFC91D22),
      Color(0xFFF59E0B),
    ];
    return SizedBox(
      width: 64,
      height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colors[i],
                child: const Icon(Icons.person, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
