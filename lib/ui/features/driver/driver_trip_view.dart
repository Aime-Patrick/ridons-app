import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/ride_offer.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_button.dart';
import '../../core/widgets/ridons_bottom_sheet.dart';
import '../../core/widgets/ridons_map_view.dart';
import '../../core/widgets/map_marker_info_sheet.dart';
import 'view_models/driver_home_view_model.dart';

class DriverTripView extends StatelessWidget {
  const DriverTripView({super.key, required this.viewModel});

  final DriverHomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ride = viewModel.ride;
    if (ride == null) return const SizedBox.shrink();
    return Stack(
      children: [
        _TripMap(viewModel: viewModel, ride: ride),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    viewModel.etaChip,
                    style: const TextStyle(
                      color: RidonsColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _TripSheet(viewModel: viewModel, ride: ride),
        ),
      ],
    );
  }
}

class _TripMap extends StatefulWidget {
  const _TripMap({required this.viewModel, required this.ride});

  final DriverHomeViewModel viewModel;
  final ActiveRide ride;

  @override
  State<_TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<_TripMap> {
  final MapController _controller = MapController();
  LatLng? _lastFollowPoint;

  @override
  void didUpdateWidget(covariant _TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followDriverIfNeeded();
  }

  void _followDriverIfNeeded() {
    if (!widget.viewModel.inAppNavigation) return;
    final point = widget.viewModel.driverPoint;
    if (point == null ||
        (_lastFollowPoint != null &&
            _lastFollowPoint!.latitude == point.latitude &&
            _lastFollowPoint!.longitude == point.longitude)) {
      return;
    }
    _lastFollowPoint = point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.viewModel.inAppNavigation) {
        _controller.move(point, 16.2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final ride = widget.ride;
    _followDriverIfNeeded();
    final you = viewModel.driverPoint ?? ride.from;
    final dest = viewModel.stage == DriverStage.driving
        ? ride.to
        : (viewModel.passengerPoint ?? ride.from);
    final points = viewModel.routePoints.length >= 2
        ? viewModel.routePoints
        : [you, dest];
    return RidonsMapView(
      controller: _controller,
      center: you,
      initialZoom: 15.4,
      layers: [
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF7A1014),
              strokeWidth: 6,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: you,
              width: 44,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMapMarkerInfoDialog(
                  context,
                  title: 'Driver',
                  subtitle: viewModel.user.displayName,
                  details: {
                    'Status': 'Active',
                    'Location':
                        '${you.latitude.toStringAsFixed(5)}, ${you.longitude.toStringAsFixed(5)}',
                    'Ride': ride.rideId,
                  },
                ),
                child: const CircleAvatar(
                  backgroundColor: RidonsColors.navy,
                  child: Icon(Icons.two_wheeler, color: Colors.white),
                ),
              ),
            ),
            Marker(
              point: dest,
              width: 44,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMapMarkerInfoDialog(
                  context,
                  title: 'Passenger',
                  subtitle: ride.passengerName,
                  details: {
                    if (ride.passengerPhone.isNotEmpty)
                      'Phone': ride.passengerPhone,
                    'Location': viewModel.passengerPoint == null
                        ? (ride.fromName.isNotEmpty
                              ? ride.fromName
                              : '${ride.from.latitude.toStringAsFixed(5)}, ${ride.from.longitude.toStringAsFixed(5)}')
                        : '${viewModel.passengerPoint!.latitude.toStringAsFixed(5)}, ${viewModel.passengerPoint!.longitude.toStringAsFixed(5)}',
                    'Ride': ride.rideId,
                  },
                ),
                child: CircleAvatar(
                  backgroundColor: RidonsColors.primaryLight,
                  foregroundColor: RidonsColors.primaryDark,
                  child: Text(
                    ride.passengerName.isEmpty
                        ? 'P'
                        : ride.passengerName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripSheet extends StatelessWidget {
  const _TripSheet({required this.viewModel, required this.ride});

  final DriverHomeViewModel viewModel;
  final ActiveRide ride;

  @override
  Widget build(BuildContext context) {
    final driving = viewModel.stage == DriverStage.driving;
    final arrived = viewModel.stage == DriverStage.arrived;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: RidonsBottomSheet(
        showHandle: false,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.52,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        driving
                            ? 'Drive to destination'
                            : arrived
                            ? 'Passenger reached'
                            : 'Heading to passenger',
                        style: TextStyle(
                          color: context.ridonsInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      driving || arrived
                          ? Icons.navigation_rounded
                          : Icons.lock_rounded,
                      size: 18,
                      color: RidonsColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PassengerCard(ride: ride),
                if (driving) ...[
                  const SizedBox(height: 12),
                  RidonsButton(
                    label: 'Complete trip',
                    isLoading: viewModel.busy,
                    onPressed: viewModel.startTrip,
                  ),
                  const SizedBox(height: 10),
                  RidonsButton(
                    label: 'Trip was canceled',
                    variant: RidonsButtonVariant.secondary,
                    onPressed: viewModel.cancelTrip,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetaCol(
                          label: 'Agreed fare',
                          value: '${ride.fare} Rwf',
                        ),
                      ),
                      Expanded(
                        child: _MetaCol(
                          label: 'Payment method',
                          value: _payLabel(ride.paymentMethod),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RidonsButton(
                    label: arrived
                        ? 'Start ride'
                        : viewModel.inAppNavigation
                        ? 'Following route to passenger'
                        : 'Navigate to passenger',
                    isLoading: viewModel.busy,
                    onPressed: arrived
                        ? viewModel.startTrip
                        : viewModel.navigateToPickup,
                  ),
                  const SizedBox(height: 10),
                  RidonsButton(
                    label: 'Trip was canceled',
                    variant: RidonsButtonVariant.secondary,
                    onPressed: viewModel.cancelTrip,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _payLabel(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('momo') || value.contains('cash')) return 'Cash or MoMo';
    return 'Cash or MoMo';
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.ridonsMuted, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: context.ridonsInk,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.ride});

  final ActiveRide ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.ridonsFill,
                child: Text(
                  ride.passengerName.isEmpty ? 'P' : ride.passengerName[0],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.passengerName.isEmpty
                          ? 'Passenger'
                          : ride.passengerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.ridonsInk,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_pax(ride.passengerId)}  ${ride.passengerPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.ridonsMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: ride.fromName.isEmpty ? 'Pickup' : ride.fromName,
                    style: const TextStyle(
                      color: RidonsColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '  →  ',
                    style: TextStyle(color: context.ridonsMuted),
                  ),
                  TextSpan(
                    text: ride.toName.isEmpty ? 'Dropoff' : ride.toName,
                    style: TextStyle(
                      color: context.ridonsInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ride.passengerPhone.isEmpty
                      ? null
                      : () => launchUrl(
                          Uri(scheme: 'tel', path: ride.passengerPhone),
                        ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ride.passengerPhone.isEmpty
                      ? null
                      : () => launchUrl(
                          Uri(scheme: 'sms', path: ride.passengerPhone),
                        ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _pax(String id) {
    final tail = id.contains('_') ? id.split('_').last : id;
    final cleaned = tail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return '—';
    final few = cleaned.length <= 6
        ? cleaned
        : cleaned.substring(cleaned.length - 6);
    return 'PAX-${few.toUpperCase()}';
  }
}
