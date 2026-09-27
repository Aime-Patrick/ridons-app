import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/places_service.dart';
import '../../../data/services/routing_service.dart';
import '../../../domain/models/geo_place.dart';
import '../../../domain/models/ride_stage.dart';
import '../../../domain/models/session_user.dart';
import '../account/passenger_avatar.dart';
import '../notifications/notification_inbox_view.dart';
import '../../core/widgets/map_marker_info_sheet.dart';
import '../../core/widgets/ridons_notification_bell.dart';
import '../../core/widgets/ridons_map_view.dart';
import 'view_models/home_map_view_model.dart';
import 'widgets/ride_flow_panels.dart';

/// Passenger home: OpenStreetMap, route request, offer, match, manual payment.
class HomeMapView extends ConsumerStatefulWidget {
  const HomeMapView({super.key});

  @override
  ConsumerState<HomeMapView> createState() => HomeMapViewState();
}

class HomeMapViewState extends ConsumerState<HomeMapView> {
  late final HomeMapViewModel _viewModel;
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  List<LatLng> _fittedRoute = const [];
  var _didCenterOnGps = false;
  var _mapReady = false;
  RideStage? _sheetStage;
  var _sheetHasDropoff = false;
  var _sheetCollapsed = false;
  var _sheetFraction = 0.34;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeMapViewModel(
      locationService: LocationService(),
      placesService: PlacesService(apiClient: ref.read(apiClientProvider)),
      routingService: RoutingService(),
      geoApi: ref.read(geoApiProvider),
      realtime: ref.read(realtimeClientProvider),
      tripApi: ref.read(tripApiProvider),
      pricingApi: ref.read(pricingApiProvider),
      supportApi: ref.read(supportApiProvider),
      passengerName:
          ref.read(authSessionProvider).asData?.value?.user.displayName ?? '',
    )..addListener(_onViewModel);
    _sheetController.addListener(_onSheetMoved);
    _viewModel.bootstrap();
  }

  Future<void> rebookReverse({
    required GeoPlace pickup,
    required GeoPlace dropoff,
  }) {
    return _viewModel.rebook(pickup: pickup, dropoff: dropoff);
  }

  void _onViewModel() {
    _maybeResizeSheet();
    _centerOnGpsIfNeeded();

    final route = _viewModel.routePoints;
    if (route.length >= 2 && !_sameRoute(route, _fittedRoute)) {
      _fittedRoute = List<LatLng>.from(route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _viewModel.routePoints.length < 2) return;
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_viewModel.routePoints),
              padding: const EdgeInsets.fromLTRB(48, 120, 48, 280),
            ),
          );
        } catch (_) {}
      });
    }
  }

  void _centerOnGpsIfNeeded() {
    if (!_mapReady || _didCenterOnGps) return;
    if (_viewModel.routePoints.length >= 2) return;
    if (!_viewModel.hasGpsFix) return;
    final you = _viewModel.userPoint;
    if (you == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didCenterOnGps) return;
      _moveTo(you);
      _didCenterOnGps = true;
    });
  }

  void _recenterOnYou() {
    final you = _viewModel.userPoint;
    if (you == null) {
      _viewModel.allowLocation();
      return;
    }
    _moveTo(you);
    _didCenterOnGps = true;
  }

  void _moveTo(LatLng point) {
    try {
      _mapController.move(point, 16);
    } catch (_) {}
  }

  bool _sameRoute(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length || a.length < 2) return false;
    return a.first == b.first && a.last == b.last;
  }

  @override
  void dispose() {
    _sheetController
      ..removeListener(_onSheetMoved)
      ..dispose();
    _viewModel
      ..removeListener(_onViewModel)
      ..dispose();
    super.dispose();
  }

  double get _sheetMinSize => 0.1;

  double get _sheetMaxSize => 0.82;

  double get _sheetInitialSize {
    return switch (_viewModel.stage) {
      RideStage.pickOnMap => 0.28,
      RideStage.route ||
      RideStage.preview => _viewModel.dropoff == null ? 0.24 : 0.34,
      RideStage.estimate => 0.40,
      RideStage.offering => 0.38,
      RideStage.matched => 0.52,
      RideStage.payment => 0.44,
      RideStage.success => 0.52,
      _ => 0.34,
    };
  }

  List<double> get _sheetSnapSizes {
    // Keep a stable snap list so DraggableScrollableSheet does not
    // rewrite extent during build when the stage changes.
    return const [0.1, 0.24, 0.28, 0.34, 0.38, 0.40, 0.44, 0.52, 0.82];
  }

  void _maybeResizeSheet() {
    final stage = _viewModel.stage;
    final hasDropoff = _viewModel.dropoff != null;
    if (stage == RideStage.search ||
        _viewModel.locationPromptNeeded ||
        !_viewModel.bootstrapped) {
      return;
    }
    final target = _sheetInitialSize.clamp(_sheetMinSize, _sheetMaxSize);
    final tooFar =
        _sheetController.isAttached &&
        (_sheetController.size - target).abs() > 0.03;
    if (_sheetStage == stage && _sheetHasDropoff == hasDropoff && !tooFar) {
      return;
    }
    _sheetStage = stage;
    _sheetHasDropoff = hasDropoff;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _sheetFraction = target;
      _sheetController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size <= _sheetMinSize + 0.02) return;
    _sheetController.animateTo(
      _sheetMinSize,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSheetMoved() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    final collapsed = size <= _sheetMinSize + 0.06;
    if (collapsed == _sheetCollapsed && (size - _sheetFraction).abs() < 0.005) {
      return;
    }
    // Defer — controller can notify while DraggableScrollableSheet updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      final next = _sheetController.size;
      final nextCollapsed = next <= _sheetMinSize + 0.06;
      if (nextCollapsed == _sheetCollapsed &&
          (next - _sheetFraction).abs() < 0.005) {
        return;
      }
      setState(() {
        _sheetCollapsed = nextCollapsed;
        _sheetFraction = next;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final searching = _viewModel.stage == RideStage.search;
        final success = _viewModel.stage == RideStage.success;
        final askingLocation = _viewModel.locationPromptNeeded;
        final showRideSheet =
            _viewModel.bootstrapped &&
            !askingLocation &&
            !searching &&
            !success;
        final showDestinationChip =
            _sheetCollapsed &&
            showRideSheet &&
            _viewModel.dropoffLabel.isNotEmpty;
        final sheetFraction = showRideSheet ? _sheetFraction : 0.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _PassengerMap(
                controller: _mapController,
                viewModel: _viewModel,
                user: ref.watch(authSessionProvider).asData?.value?.user,
                token: ref.watch(authSessionProvider).asData?.value?.token,
                onMapTap: askingLocation ? null : _collapseSheet,
                onMapReady: () {
                  _mapReady = true;
                  _centerOnGpsIfNeeded();
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RouteHeaderChip(
                viewModel: _viewModel,
                visible: showDestinationChip,
              ),
            ),
            Positioned(
              top:
                  MediaQuery.paddingOf(context).top +
                  (showDestinationChip ? 64 : 8),
              right: 12,
              child: Material(
                color: context.ridonsSheet,
                elevation: 4,
                shape: const CircleBorder(),
                child: RidonsNotificationBell(
                  unreadCount: ref
                      .watch(notificationCenterProvider)
                      .unreadCount,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationInboxView(),
                    ),
                  ),
                ),
              ),
            ),
            if (showRideSheet)
              Positioned.fill(
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  // Keep initial size stable so didUpdateWidget does not
                  // replace extent (and notify listeners) mid-build.
                  initialChildSize: 0.34,
                  minChildSize: _sheetMinSize,
                  maxChildSize: _sheetMaxSize,
                  snap: true,
                  snapSizes: _sheetSnapSizes,
                  builder: (context, scrollController) {
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    return Material(
                      color: context.ridonsSheet,
                      elevation: 12,
                      shadowColor: const Color(0x33000000),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(0, 4, 0, 4 + bottomInset),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: context.ridonsLine,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            RideFlowPanel(
                              viewModel: _viewModel,
                              decorate: false,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!askingLocation && !searching)
              _MyLocationButton(
                sheetFraction: sheetFraction,
                onPressed: _recenterOnYou,
              ),
            if (searching || success)
              Positioned.fill(child: RideFlowPanel(viewModel: _viewModel)),
            _AnimatedLocationSheet(
              visible: askingLocation,
              locating: _viewModel.locating,
              onAllow: _viewModel.allowLocation,
              onSkip: _viewModel.skipPermissions,
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedLocationSheet extends StatefulWidget {
  const _AnimatedLocationSheet({
    required this.visible,
    required this.locating,
    required this.onAllow,
    required this.onSkip,
  });

  final bool visible;
  final bool locating;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  State<_AnimatedLocationSheet> createState() => _AnimatedLocationSheetState();
}

class _AnimatedLocationSheetState extends State<_AnimatedLocationSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedLocationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed && !widget.visible) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _offset,
            child: LocationAccessSheet(
              locating: widget.locating,
              onAllow: widget.onAllow,
              onSkip: widget.onSkip,
            ),
          ),
        );
      },
    );
  }
}

class _PassengerMap extends StatelessWidget {
  const _PassengerMap({
    required this.controller,
    required this.viewModel,
    this.user,
    this.token,
    this.onMapTap,
    this.onMapReady,
  });

  final MapController controller;
  final HomeMapViewModel viewModel;
  final SessionUser? user;
  final String? token;
  final VoidCallback? onMapTap;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    final pickup = viewModel.pickup;
    final dropoff = viewModel.dropoff;
    final candidate = viewModel.pickCandidate;
    final you = viewModel.userPoint;
    final showPickupPin =
        pickup != null &&
        !viewModel.pickupIsUser &&
        (you == null ||
            pickup.latitude != you.latitude ||
            pickup.longitude != you.longitude);
    final showDrivers = viewModel.nearbyDrivers.isNotEmpty;
    final etaMid = RoutingService.midpointAlong(viewModel.routePoints);

    return RidonsMapView(
      controller: controller,
      center: viewModel.mapCenter,
      initialZoom: 15.4,
      onMapReady: onMapReady,
      onTap: (point) {
        if (viewModel.stage == RideStage.pickOnMap) {
          viewModel.pickOnMap(point);
          return;
        }
        onMapTap?.call();
      },
      layers: [
        if (you != null && viewModel.hasGpsFix)
          CircleLayer(
            circles: [
              CircleMarker(
                point: you,
                radius: viewModel.gpsAccuracyMeters,
                useRadiusInMeter: true,
                color: const Color(0x184285F4),
                borderColor: const Color(0x554285F4),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        if (viewModel.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              for (final alt in viewModel.routeAlternatives)
                if (alt.length >= 2)
                  Polyline(
                    points: alt,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0x66FBBF24)
                        : RidonsColors.primary.withValues(alpha: 0.28),
                    strokeWidth: 4,
                  ),
              Polyline(
                points: viewModel.routePoints,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFBBF24)
                    : RidonsColors.primaryDark,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (showDrivers)
              for (final driver in viewModel.nearbyDrivers)
                Marker(
                  point: driver.point,
                  width: driver.id == viewModel.focusedDriverId ? 44 : 32,
                  height: driver.id == viewModel.focusedDriverId ? 44 : 32,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showMapMarkerInfoDialog(
                      context,
                      title: 'Driver',
                      subtitle: driver.id,
                      details: {
                        'Status': 'Online',
                        'Speed': '${driver.speedKmh.toStringAsFixed(1)} km/h',
                        'Heading': '${driver.headingDeg.toStringAsFixed(0)}°',
                      },
                    ),
                    child: _DriverMapMarker(
                      assigned: driver.id == viewModel.focusedDriverId,
                    ),
                  ),
                ),
            if (you != null)
              _youMarker(
                you,
                user: user,
                token: token,
                onTap: () => showMapMarkerInfoDialog(
                  context,
                  title: 'Your location',
                  details: {
                    'Status': 'Active',
                    'Coordinates':
                        '${you.latitude.toStringAsFixed(5)}, ${you.longitude.toStringAsFixed(5)}',
                  },
                ),
              ),
            if (showPickupPin)
              _pinMarker(
                pickup,
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : RidonsColors.navy,
              ),
            if (dropoff != null) _pinMarker(dropoff, RidonsColors.primary),
            if (candidate != null) _pinMarker(candidate, RidonsColors.primary),
            if (etaMid != null)
              Marker(
                point: etaMid,
                width: 156,
                height: 40,
                alignment: Alignment.center,
                child: IgnorePointer(
                  child: RouteEtaMapBadge(viewModel: viewModel),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Marker _youMarker(
    LatLng point, {
    SessionUser? user,
    String? token,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: user != null && user.hasChosenAvatar
                  ? PassengerAvatar(user: user, radius: 19, token: token)
                  : const ColoredBox(
                      color: Color(0xFF4285F4),
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _pinMarker(GeoPlace place, Color color) {
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: Icon(Icons.location_on, color: color, size: 40),
    );
  }
}

class _DriverMapMarker extends StatelessWidget {
  const _DriverMapMarker({required this.assigned});

  final bool assigned;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: assigned ? RidonsColors.primary : RidonsColors.navy,
        shape: BoxShape.circle,
        border: Border.all(
          color: assigned ? RidonsColors.accent : Colors.white,
          width: assigned ? 3 : 2,
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Icon(
        Icons.two_wheeler,
        color: Colors.white,
        size: assigned ? 23 : 16,
      ),
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({
    required this.sheetFraction,
    required this.onPressed,
  });

  final double sheetFraction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final topSafe = media.padding.top + 80;
    final raw = height * sheetFraction + 12;
    final bottom = raw.clamp(16.0, (height - topSafe - 56).clamp(16.0, height));
    return Positioned(
      right: 16,
      bottom: bottom,
      child: Material(
        elevation: 4,
        color: scheme.surface,
        shadowColor: const Color(0x33000000),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'My location',
          onPressed: onPressed,
          icon: Icon(Icons.my_location_rounded, color: scheme.primary),
        ),
      ),
    );
  }
}
