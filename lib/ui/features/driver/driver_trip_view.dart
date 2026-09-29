import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/ride_offer.dart';
import '../../../data/services/compass_service.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_button.dart';
import '../../core/widgets/ridons_map_view.dart';
import '../../core/widgets/map_marker_info_sheet.dart';
import '../../core/widgets/ridons_route_endpoints.dart';
import '../../core/widgets/ridons_trip_sheet.dart';
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
        Positioned.fill(
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
  final MapController controller = MapController();
  final CompassService compassService = CompassService();

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final ride = widget.ride;
    final you = viewModel.driverPoint ?? ride.from;
    final dest = viewModel.stage == DriverStage.driving
        ? ride.to
        : (viewModel.passengerPoint ?? ride.from);
    final points = viewModel.routePoints.length >= 2
        ? viewModel.routePoints
        : [you, dest];
    return RidonsMapView(
      controller: controller,
      center: you,
      initialZoom: 15.4,
      deviceHeadingStream: compassService.headingStream,
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
                onTap: () => showMapMarkerInfoSheet(
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
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircleAvatar(
                      backgroundColor: RidonsColors.navy,
                      child: Icon(
                        Icons.two_wheeler,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Marker(
              point: dest,
              width: 44,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMapMarkerInfoSheet(
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
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircleAvatar(
                      backgroundColor: RidonsColors.primaryLight,
                      foregroundColor: RidonsColors.primaryDark,
                      child: Text(
                        ride.passengerName.isEmpty
                            ? 'P'
                            : ride.passengerName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
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
    return RidonsTripSheetHost(
      initialChildSize: 0.44,
      minChildSize: 0.1,
      maxChildSize: 0.82,
      snapSizes: RidonsTripSheetHost.defaultSnapSizes,
      child: RidonsTripSheet(
        title: driving
            ? 'Drive to destination'
            : arrived
          ? 'Passenger reached'
          : 'Heading to passenger',
        trailing: Icon(
          driving || arrived
              ? Icons.route_rounded
              : Icons.lock_rounded,
          size: 18,
          color: RidonsColors.primary,
        ),
        decorate: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (arrived)
                RidonsButton(
                  label: 'Start ride',
                  isLoading: viewModel.busy,
                  onPressed: viewModel.startTrip,
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
    );
  }

  static String _payLabel(String raw) {
    final value = raw.trim().toLowerCase().replaceAll('_', ' ');
    if (value.isEmpty) return 'Not specified';
    if (value.contains('momo') || value.contains('mobile money')) {
      if (value.contains('cash')) return 'Cash or MoMo';
      return 'Mobile Money';
    }
    if (value.contains('cash')) return 'Cash';
    return raw.trim();
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(color: context.ridonsMuted, fontSize: 12),
        ),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
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
          Offstage(
            offstage: true,
            child: Align(
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
          ),
          RidonsRouteEndpoints(
            pickup: ride.fromName.isEmpty ? 'Pickup' : ride.fromName,
            destination: ride.toName.isEmpty ? 'Dropoff' : ride.toName,
            pickupColor: RidonsColors.primary,
            destinationColor: context.ridonsInk,
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
