import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'ridons_tile_layer.dart';

/// Shared map surface used by passenger and driver flows.
///
/// Role-specific screens provide only their layers and actions. Keeping the
/// map lifecycle here ensures both flows use the same tile source, gestures,
/// camera configuration, and map-ready behavior.
class RidonsMapView extends StatelessWidget {
  const RidonsMapView({
    super.key,
    required this.controller,
    required this.center,
    required this.layers,
    this.initialZoom = 15,
    this.onTap,
    this.onMapReady,
  });

  final MapController controller;
  final LatLng center;
  final double initialZoom;
  final List<Widget> layers;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        onMapReady: onMapReady,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [...RidonsMapTiles.layers(context), ...layers],
    );
  }
}
