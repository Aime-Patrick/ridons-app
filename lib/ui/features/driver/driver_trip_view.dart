import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/ride_offer.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_button.dart';
import '../../core/widgets/ridons_tile_layer.dart';
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

class _TripMap extends StatelessWidget {
  const _TripMap({required this.viewModel, required this.ride});

  final DriverHomeViewModel viewModel;
  final ActiveRide ride;

  @override
  Widget build(BuildContext context) {
    final you = viewModel.driverPoint ?? ride.from;
    final dest = viewModel.stage == DriverStage.driving ? ride.to : ride.from;
    final points = viewModel.routePoints.length >= 2
        ? viewModel.routePoints
        : [you, dest];
    return FlutterMap(
      options: MapOptions(
        initialCenter: you,
        initialZoom: 14.5,
      ),
      children: [
        ...RidonsMapTiles.layers(context),
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
                child: CircleAvatar(
                  backgroundColor: RidonsColors.navy,
                  child: Text(
                    ride.passengerName.isEmpty ? '?' : ride.passengerName[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Marker(
              point: dest,
              width: 22,
              height: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMapMarkerInfoSheet(
                  context,
                  title: 'Passenger',
                  subtitle: ride.passengerName,
                  details: {
                    if (ride.passengerPhone.isNotEmpty)
                      'Phone': ride.passengerPhone,
                    'Pickup': ride.fromName.isNotEmpty
                        ? ride.fromName
                        : '${ride.from.latitude.toStringAsFixed(5)}, ${ride.from.longitude.toStringAsFixed(5)}',
                    'Ride': ride.rideId,
                  },
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: RidonsColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
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
    return Material(
      color: context.ridonsSheet,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    driving ? 'Drive to destination' : 'Trip locked',
                    style: TextStyle(
                      color: context.ridonsInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.lock_rounded, color: RidonsColors.primary),
              ],
            ),
            const SizedBox(height: 14),
            _PassengerCard(ride: ride),
            if (!driving) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: _MetaCol(label: 'Agreed fare', value: null, ride: null),
                  ),
                  Expanded(
                    child: _MetaCol(
                      label: 'Payment method',
                      value: _payLabel(ride.paymentMethod),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ride.fare} Rwf',
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              RidonsButton(
                label: 'Start a trip',
                isLoading: viewModel.busy,
                onPressed: viewModel.startTrip,
              ),
              const SizedBox(height: 10),
              RidonsButton(
                label: 'Trip were canceled',
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
  const _MetaCol({required this.label, this.value, this.ride});

  final String label;
  final String? value;
  final ActiveRide? ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.ridonsMuted, fontSize: 12)),
        if (value != null)
          Text(
            value!,
            style: TextStyle(
              color: context.ridonsInk,
              fontWeight: FontWeight.w800,
              fontSize: 18,
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
        borderRadius: BorderRadius.circular(18),
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
                      ride.passengerName.isEmpty ? 'Passenger' : ride.passengerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.ridonsInk,
                        fontSize: 16,
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
                      : () => launchUrl(Uri(scheme: 'tel', path: ride.passengerPhone)),
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
                      : () => launchUrl(Uri(
                            scheme: 'sms',
                            path: ride.passengerPhone,
                          )),
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
    if (cleaned.isEmpty) return 'PAX-0000';
    final few = cleaned.length <= 6 ? cleaned : cleaned.substring(cleaned.length - 6);
    return 'PAX-${few.toUpperCase()}';
  }
}
