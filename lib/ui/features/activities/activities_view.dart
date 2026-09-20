import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_tile_layer.dart';
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
}

/// Trip history with map snapshots and a filter. Data comes from GET /me/trips.
class ActivitiesView extends ConsumerStatefulWidget {
  const ActivitiesView({super.key, this.onRebook, this.isDriver = false});

  final ValueChanged<ActivityTrip>? onRebook;
  final bool isDriver;

  @override
  ConsumerState<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends ConsumerState<ActivitiesView> {
  _ActivityFilter _filter = _ActivityFilter.all;
  List<ActivityTrip> _trips = const [];
  var _loading = true;
  var _refreshing = false;
  String? _error;
  final _places = PlacesService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool pull = false}) async {
    if (pull) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final period = switch (_filter) {
        _ActivityFilter.all => 'all',
        _ActivityFilter.today => 'today',
        _ActivityFilter.week => 'week',
      };
      final items = await ref.read(tripApiProvider).myTrips(period: period);
      final trips = <ActivityTrip>[];
      for (final item in items) {
        var pickup = 'Pickup';
        var dropoff = 'Dropoff';
        try {
          pickup =
              (await _places.reverse(item.from.latitude, item.from.longitude))
                  .name;
          dropoff =
              (await _places.reverse(item.to.latitude, item.to.longitude)).name;
        } catch (_) {}
        trips.add(
          ActivityTrip(
            pickup: pickup,
            dropoff: dropoff,
            when: item.when,
            driverName: widget.isDriver ? 'Passenger' : 'Driver',
            fareRwf: item.fare,
            pickupPoint: item.from,
            dropoffPoint: item.to,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load trips. Pull down to retry.';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  List<ActivityTrip> get _visible => _trips;

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
                  'Filter trips',
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
                      title: Text(_filterLabel(option)),
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
        _loading = true;
      });
      await _load();
    }
  }

  static String _filterLabel(_ActivityFilter filter) {
    return switch (filter) {
      _ActivityFilter.all => 'All trips',
      _ActivityFilter.today => 'Today',
      _ActivityFilter.week => 'This week',
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
                      'Activities',
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
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: RidonsColors.primary,
                      onRefresh: () => _load(pull: true),
                      child: _error != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.ridonsMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: OutlinedButton(
                                    onPressed: () => _load(),
                                    child: const Text('Retry'),
                                  ),
                                ),
                              ],
                            )
                          : trips.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    48,
                                    24,
                                    24,
                                  ),
                                  children: [
                                    Text(
                                      'No trips in this filter.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.ridonsMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Pull down to refresh.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.ridonsMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  itemCount: trips.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    return _ActivityTripCard(
                                      trip: trips[index],
                                      onRebook: widget.onRebook == null
                                          ? null
                                          : () =>
                                              widget.onRebook!(trips[index]),
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

class _ActivityTripCard extends StatelessWidget {
  const _ActivityTripCard({required this.trip, this.onRebook});

  final ActivityTrip trip;
  final VoidCallback? onRebook;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = trip.when.year == now.year &&
        trip.when.month == now.month &&
        trip.when.day == now.day;
    final dayLabel = isToday ? 'Today' : DateFormat('d MMM').format(trip.when);
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
                Text.rich(
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
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: context.ridonsMuted,
                      fontSize: 13,
                    ),
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
                      TextSpan(text: trip.driverName),
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
                        child: const Text(
                          'Rebook',
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

class _TripMapSnapshot extends StatelessWidget {
  const _TripMapSnapshot({
    required this.pickup,
    required this.dropoff,
  });

  final LatLng pickup;
  final LatLng dropoff;

  @override
  Widget build(BuildContext context) {
    final mid = LatLng(
      (pickup.latitude + dropoff.latitude) / 2 + 0.003,
      (pickup.longitude + dropoff.longitude) / 2,
    );
    final route = [pickup, mid, dropoff];
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: mid,
          initialZoom: 12.4,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          const RidonsTileLayer(),
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
                point: pickup,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : RidonsColors.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              Marker(
                point: dropoff,
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
  }
}
