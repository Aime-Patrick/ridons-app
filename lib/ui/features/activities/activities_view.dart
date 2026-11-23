import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/services/routing_service.dart';
import '../../../domain/models/geo_place.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_tile_layer.dart';
import '../../core/widgets/ridons_route_endpoints.dart';
import '../../core/providers/session_providers.dart';
import '../../../data/services/places_service.dart';

enum _ActivityFilter { all, today, week }

class ActivityTrip {
  const ActivityTrip({
    required this.pickup,
    required this.dropoff,
    required this.when,
    required this.driverName,
    required this.fareRwf,
    required this.pickupPoint,
    required this.dropoffPoint,
  });

  final String pickup;
  final String dropoff;
  final DateTime when;
  final String driverName;
  final int fareRwf;
  final LatLng pickupPoint;
  final LatLng dropoffPoint;

  ActivityTrip copyWith({String? pickup, String? dropoff}) => ActivityTrip(
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    when: when,
    driverName: driverName,
    fareRwf: fareRwf,
    pickupPoint: pickupPoint,
    dropoffPoint: dropoffPoint,
  );
}

/// Trip history with map snapshots and a filter. Data comes from GET /me/trips.
class ActivitiesView extends ConsumerStatefulWidget {
  const ActivitiesView({
    super.key,
    this.onRebook,
    this.isDriver = false,
    this.isActive = false,
  });

  final ValueChanged<ActivityTrip>? onRebook;
  final bool isDriver;
  final bool isActive;

  @override
  ConsumerState<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends ConsumerState<ActivitiesView> {
  static const _cacheDuration = Duration(minutes: 2);

  _ActivityFilter _filter = _ActivityFilter.all;
  List<ActivityTrip> _trips = const [];
  var _loading = true;
  var _refreshing = false;
  var _hasLoaded = false;
  var _requestInFlight = false;
  DateTime? _lastFetchedAt;
  String? _error;
  final _places = PlacesService();
  final Map<String, String> _placeLabels = {};
  final Map<String, Future<String?>> _placeLabelRequests = {};

  @override
  void initState() {
    super.initState();
    // IndexedStack creates this screen before it is first opened. Wait until
    // the Activities tab is selected so we don't fetch it in the background.
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant ActivitiesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load({bool pull = false, bool force = false}) async {
    if (_requestInFlight) return;
    final lastFetchedAt = _lastFetchedAt;
    if (!force &&
        lastFetchedAt != null &&
        DateTime.now().difference(lastFetchedAt) < _cacheDuration) {
      return;
    }

    _requestInFlight = true;
    // Preserve the current list when revalidating stale cached data; only the
    // first load uses the skeleton state.
    if (mounted) {
      setState(() {
        _refreshing = pull;
        if (!_hasLoaded) {
          _loading = true;
          _error = null;
        }
      });
    }
    try {
      // Fetch the server's latest 50 once; the filter tabs are applied locally
      // so switching filters doesn't generate another history request.
      final items = await ref.read(tripApiProvider).myTrips(period: 'all');
      final trips = items
          .map(
            (item) => ActivityTrip(
              pickup:
                  _placeLabels[_locationKey(item.from)] ??
                  _coordinateLabel(item.from),
              dropoff:
                  _placeLabels[_locationKey(item.to)] ??
                  _coordinateLabel(item.to),
              when: item.when,
              driverName: widget.isDriver ? 'passenger' : 'driver',
              fareRwf: item.fare,
              pickupPoint: item.from,
              dropoffPoint: item.to,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
        _hasLoaded = true;
        _lastFetchedAt = DateTime.now();
        _loading = false;
        _refreshing = false;
      });
      // Render trips as soon as the API responds. Place-name lookups are
      // enrichment only; show coordinate fallbacks until each one completes.
      unawaited(_resolvePlaceLabels(trips));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Keep the cached history visible if a background refresh fails.
        if (!_hasLoaded) _error = 'could_not_load_trips';
        // Back off automatic re-attempts; the retry button and pull-to-refresh
        // still bypass the cache window.
        _lastFetchedAt = DateTime.now();
        _loading = false;
        _refreshing = false;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  List<ActivityTrip> get _visible {
    final now = DateTime.now();
    return switch (_filter) {
      _ActivityFilter.all => _trips,
      _ActivityFilter.today => _trips
          .where(
            (trip) =>
                trip.when.year == now.year &&
                trip.when.month == now.month &&
                trip.when.day == now.day,
          )
          .toList(growable: false),
      _ActivityFilter.week => _trips
          .where(
            (trip) =>
                !trip.when.isBefore(now.subtract(const Duration(days: 7))),
          )
          .toList(growable: false),
    };
  }

  Future<String?> _placeLabel(LatLng point) {
    final key = _locationKey(point);
    final cached = _placeLabels[key];
    if (cached != null) return Future.value(cached);
    return _placeLabelRequests.putIfAbsent(key, () async {
      final place = await _places.reverseFast(point.latitude, point.longitude);
      final name = place?.name.trim();
      if (name == null || name.isEmpty) return null;
      _placeLabels[key] = name;
      return name;
    });
  }

  Future<void> _resolvePlaceLabels(List<ActivityTrip> trips) async {
    for (final trip in trips) {
      final labels = await Future.wait([
        _placeLabel(trip.pickupPoint),
        _placeLabel(trip.dropoffPoint),
      ]);
      if (!mounted || (labels[0] == null && labels[1] == null)) continue;
      setState(() {
        _trips = [
          for (final current in _trips)
            current.copyWith(
              pickup: _placeLabels[_locationKey(current.pickupPoint)],
              dropoff: _placeLabels[_locationKey(current.dropoffPoint)],
            ),
        ];
      });
    }
  }

  static String _locationKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';

  static String _coordinateLabel(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _openFilter() async {
    final selected = await showModalBottomSheet<_ActivityFilter>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'filter_trips'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final option in _ActivityFilter.values)
                  Material(
                    color: context.ridonsSheet,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_filterLabel(option).tr()),
                      trailing: _filter == option
                          ? const Icon(Icons.check, color: RidonsColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _filter = selected;
      });
    }
  }

  static String _filterLabel(_ActivityFilter filter) {
    return switch (filter) {
      _ActivityFilter.all => 'all_trips',
      _ActivityFilter.today => 'today',
      _ActivityFilter.week => 'this_week',
    };
  }

  @override
  Widget build(BuildContext context) {
    final trips = _visible;
    return ColoredBox(
      color: context.ridonsPage,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'activities'.tr(),
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openFilter,
                    style: IconButton.styleFrom(
                      side: BorderSide(color: context.ridonsLine),
                      backgroundColor: context.ridonsSheet,
                    ),
                    icon: Icon(Icons.tune, color: context.ridonsInk),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && !_refreshing
                  ? _ActivitySkeletonList(showRebook: !widget.isDriver)
                  : RefreshIndicator(
                      color: RidonsColors.primary,
                      onRefresh: () => _load(pull: true, force: true),
                      child: _error != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                48,
                                24,
                                24,
                              ),
                              children: [
                                Text(
                                  _error!.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.ridonsMuted),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: OutlinedButton(
                                    onPressed: () => _load(force: true),
                                    child: Text('retry'.tr()),
                                  ),
                                ),
                              ],
                            )
                          : trips.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                48,
                                24,
                                24,
                              ),
                              children: [
                                Text(
                                  'no_trips_filter'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.ridonsMuted),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'pull_to_refresh'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.ridonsMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: trips.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _ActivityTripCard(
                                  trip: trips[index],
                                  onRebook: widget.onRebook == null
                                      ? null
                                      : () => widget.onRebook!(trips[index]),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeletonList extends StatefulWidget {
  const _ActivitySkeletonList({required this.showRebook});

  final bool showRebook;

  @override
  State<_ActivitySkeletonList> createState() => _ActivitySkeletonListState();
}

class _ActivitySkeletonListState extends State<_ActivitySkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shimmer.stop();
      _shimmer.value = 0.5;
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final color = Color.lerp(
          context.ridonsPage,
          context.ridonsLine,
          0.48 + (_shimmer.value * 0.3),
        )!;
        return Semantics(
          label: 'loading_activities'.tr(),
          liveRegion: true,
          child: ExcludeSemantics(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, _) => _ActivityTripCardSkeleton(
                color: color,
                showRebook: widget.showRebook,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityTripCardSkeleton extends StatelessWidget {
  const _ActivityTripCardSkeleton({
    required this.color,
    required this.showRebook,
  });

  final Color color;
  final bool showRebook;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ridonsSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.ridonsLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 128,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: color)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ActivityMapSkeletonPainter(
                      color: context.ridonsMuted.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  left: 28,
                  top: 55,
                  child: _SkeletonDot(color: color, size: 12),
                ),
                Positioned(
                  right: 34,
                  bottom: 28,
                  child: _SkeletonDot(color: color, size: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SkeletonDot(color: color, size: 9),
                    const SizedBox(width: 10),
                    _SkeletonBar(color: color, width: 142, height: 12),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SkeletonDot(color: color, size: 9),
                    const SizedBox(width: 10),
                    _SkeletonBar(color: color, width: 196, height: 12),
                  ],
                ),
                const SizedBox(height: 12),
                _SkeletonBar(color: color, width: 174, height: 9),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _SkeletonBar(color: color, width: 104, height: 21),
                    const Spacer(),
                    if (showRebook)
                      _SkeletonBar(
                        color: color,
                        width: 92,
                        height: 40,
                        radius: 100,
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
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.color,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final Color color;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _SkeletonDot extends StatelessWidget {
  const _SkeletonDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ActivityMapSkeletonPainter extends CustomPainter {
  const _ActivityMapSkeletonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = ui.Path()
      ..moveTo(size.width * 0.12, size.height * 0.58)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.45, size.height * 0.34)
      ..lineTo(size.width * 0.61, size.height * 0.48)
      ..lineTo(size.width * 0.72, size.height * 0.33)
      ..lineTo(size.width * 0.88, size.height * 0.42);
    canvas.drawPath(route, paint);
  }

  @override
  bool shouldRepaint(covariant _ActivityMapSkeletonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ActivityTripCard extends StatelessWidget {
  const _ActivityTripCard({required this.trip, this.onRebook});

  final ActivityTrip trip;
  final VoidCallback? onRebook;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        trip.when.year == now.year &&
        trip.when.month == now.month &&
        trip.when.day == now.day;
    final dayLabel = isToday
        ? 'today'.tr()
        : DateFormat('d MMM').format(trip.when);
    final timeLabel = DateFormat('hh:mma').format(trip.when);

    return Material(
      color: context.ridonsSheet,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.ridonsLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 128,
            child: _TripMapSnapshot(
              pickup: trip.pickupPoint,
              dropoff: trip.dropoffPoint,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Offstage(
                  offstage: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: trip.pickup,
                          style: TextStyle(
                            color: context.ridonsInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: '  →  ',
                          style: TextStyle(
                            color: context.ridonsMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: trip.dropoff,
                          style: TextStyle(
                            color: context.ridonsInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                RidonsRouteEndpoints(
                  pickup: trip.pickup,
                  destination: trip.dropoff,
                  pickupColor: context.ridonsInk,
                  destinationColor: context.ridonsInk,
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: context.ridonsMuted, fontSize: 13),
                    children: [
                      TextSpan(text: dayLabel),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: timeLabel,
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(text: trip.driverName.tr()),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${NumberFormat('#,###').format(trip.fareRwf)} Rwf',
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onRebook != null)
                      OutlinedButton(
                        onPressed: onRebook,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(96, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          foregroundColor: context.ridonsInk,
                          side: BorderSide(color: context.ridonsLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          'rebook'.tr(),
                          style: TextStyle(fontWeight: FontWeight.w700),
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
}

class _TripMapSnapshot extends StatefulWidget {
  const _TripMapSnapshot({required this.pickup, required this.dropoff});

  final LatLng pickup;
  final LatLng dropoff;

  @override
  State<_TripMapSnapshot> createState() => _TripMapSnapshotState();
}

class _TripMapSnapshotState extends State<_TripMapSnapshot> {
  final MapController _controller = MapController();
  late final Future<List<LatLng>> _routeFuture;
  var _didFitRoute = false;

  @override
  void initState() {
    super.initState();
    _routeFuture = _loadRoute();
  }

  Future<List<LatLng>> _loadRoute() async {
    final result = await RoutingService().route(
      GeoPlace(
        name: 'Pickup',
        latitude: widget.pickup.latitude,
        longitude: widget.pickup.longitude,
      ),
      GeoPlace(
        name: 'Dropoff',
        latitude: widget.dropoff.latitude,
        longitude: widget.dropoff.longitude,
      ),
      alternatives: false,
    );
    // Do not draw a fake straight line when the road router is unavailable.
    if (!result.method.startsWith('osrm_') || result.points.length < 2) {
      return const [];
    }
    return result.points;
  }

  LatLng _fallbackCenter() {
    return LatLng(
      (widget.pickup.latitude + widget.dropoff.latitude) / 2,
      (widget.pickup.longitude + widget.dropoff.longitude) / 2,
    );
  }

  void _fitRoute(List<LatLng> route) {
    if (_didFitRoute || route.length < 2) return;
    _didFitRoute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(route),
            padding: const EdgeInsets.all(24),
          ),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LatLng>>(
      future: _routeFuture,
      builder: (context, snapshot) {
        final route = snapshot.data ?? const <LatLng>[];
        _fitRoute(route);
        final center = route.length >= 2
            ? (RoutingService.midpointAlong(route) ?? _fallbackCenter())
            : _fallbackCenter();
        return IgnorePointer(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.2,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              ...RidonsMapTiles.layers(context),
              if (route.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFBBF24)
                          : RidonsColors.primaryDark,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.pickup,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : RidonsColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  Marker(
                    point: widget.dropoff,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: RidonsColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
