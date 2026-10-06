import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/ride_offer.dart';
import '../../../data/services/compass_service.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_button.dart';
import '../../core/widgets/ridons_animated_marker.dart';
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        viewModel.etaChip.tr(
                          namedArgs: {
                            'minutes': '${viewModel.etaMinutes ?? ''}',
                          },
                        ),
                        style: const TextStyle(
                          color: RidonsColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (viewModel.routeDistanceKm != null)
                        Text(
                          '${viewModel.routeDistanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: RidonsColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
  var _followLocation = true;

  void _pauseLocationFollow() {
    if (_followLocation) setState(() => _followLocation = false);
  }

  void _recenterOnDriver() {
    final point = widget.viewModel.driverPoint;
    if (point == null) return;
    setState(() => _followLocation = true);
    try {
      controller.move(point, controller.camera.zoom);
    } catch (_) {}
  }

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
    final showActualTrack = viewModel.actualTrackPoints.length >= 2;
    return RidonsMapView(
      controller: controller,
      center: you,
      initialZoom: 15.4,
      followLocation: _followLocation,
      followPoint: you,
      onRecenter: _recenterOnDriver,
      onMapInteraction: _pauseLocationFollow,
      deviceHeadingStream: compassService.headingStream,
      layers: [
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: showActualTrack
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0x88FFFFFF)
                        : const Color(0x66515A6B))
                  : Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF7A1014),
              strokeWidth: 6,
            ),
            if (showActualTrack)
              Polyline(
                points: viewModel.actualTrackPoints,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFBBF24)
                    : RidonsColors.primary,
                strokeWidth: 5,
              ),
          ],
        ),
        RidonsAnimatedMarker(
          point: you,
          child: _driverMarkerChild(
            viewModel: viewModel,
            ride: ride,
            point: you,
          ),
        ),
        RidonsAnimatedMarker(
          point: dest,
          child: _passengerMarkerChild(viewModel: viewModel, ride: ride),
        ),
      ],
    );
  }

  Widget _driverMarkerChild({
    required DriverHomeViewModel viewModel,
    required ActiveRide ride,
    required LatLng point,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showMapMarkerInfoSheet(
        context,
        title: 'driver',
        subtitle: viewModel.user.displayName,
        details: {
          'status': 'active'.tr(),
          'location':
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          'ride': ride.rideId,
        },
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircleAvatar(
            backgroundColor: RidonsColors.navy,
            child: Icon(Icons.two_wheeler, color: Colors.white, size: 12),
          ),
        ),
      ),
    );
  }

  Widget _passengerMarkerChild({
    required DriverHomeViewModel viewModel,
    required ActiveRide ride,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showMapMarkerInfoSheet(
        context,
        title: 'passenger',
        subtitle: ride.passengerName,
        details: {
          if (ride.passengerPhone.isNotEmpty) 'phone': ride.passengerPhone,
          'location': viewModel.passengerPoint == null
              ? (ride.fromName.isNotEmpty
                    ? ride.fromName
                    : '${ride.from.latitude.toStringAsFixed(5)}, ${ride.from.longitude.toStringAsFixed(5)}')
              : '${viewModel.passengerPoint!.latitude.toStringAsFixed(5)}, ${viewModel.passengerPoint!.longitude.toStringAsFixed(5)}',
          'ride': ride.rideId,
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
            ),
          ),
        ),
      ),
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
            ? 'drive_to_destination'
            : arrived
            ? 'passenger_reached'
            : 'heading_to_passenger',
        trailing: Icon(
          driving || arrived ? Icons.route_rounded : Icons.lock_rounded,
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
                label: 'complete_trip',
                isLoading: viewModel.busy,
                onPressed: viewModel.startTrip,
              ),
              const SizedBox(height: 10),
              RidonsButton(
                label: 'trip_was_canceled',
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
                      label: 'agreed_fare',
                      value: '${ride.fare} Rwf',
                    ),
                  ),
                  Expanded(
                    child: _MetaCol(
                      label: 'payment_method',
                      value: _payLabel(ride.paymentMethod),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (arrived)
                RidonsButton(
                  label: 'start_ride',
                  isLoading: viewModel.busy,
                  onPressed: viewModel.startTrip,
                ),
              const SizedBox(height: 10),
              RidonsButton(
                label: 'trip_was_canceled',
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
    if (value.isEmpty) return 'not_specified'.tr();
    if (value.contains('momo') || value.contains('mobile money')) {
      if (value.contains('cash')) return 'cash_or_momo'.tr();
      return 'mobile_money'.tr();
    }
    if (value.contains('cash')) return 'cash'.tr();
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
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(),
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
                          ? 'passenger'.tr()
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
                      text: ride.fromName.isEmpty
                          ? 'pickup'.tr()
                          : ride.fromName,
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
                      text: ride.toName.isEmpty ? 'dropoff'.tr() : ride.toName,
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
            pickup: ride.fromName.isEmpty ? 'pickup'.tr() : ride.fromName,
            destination: ride.toName.isEmpty ? 'dropoff'.tr() : ride.toName,
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
                  label: Text('call'.tr()),
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
                  label: Text('message'.tr()),
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
