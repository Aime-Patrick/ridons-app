import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
    this.bottomControlsOffset = 0,
    this.onRecenter,
    this.onTap,
    this.onMapReady,
    this.deviceHeadingStream,
  });

  final MapController controller;
  final LatLng center;
  final double initialZoom;
  final double bottomControlsOffset;
  final VoidCallback? onRecenter;
  final List<Widget> layers;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onMapReady;
  final Stream<double>? deviceHeadingStream;

  @override
  Widget build(BuildContext context) {
    final hasLocationControl = onRecenter != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            // Start north-up. The compass tracks manual map rotation and can
            // reset the map without entering a navigation/follow mode.
            initialCenter: center,
            initialZoom: initialZoom,
            onMapReady: onMapReady,
            onTap: onTap == null ? null : (_, point) => onTap!(point),
          ),
          children: [...RidonsMapTiles.layers(context), ...layers],
        ),
        if (hasLocationControl)
          Positioned(
            bottom: bottomControlsOffset,
            right: 12,
            child: _MapControlButton(
              tooltip: 'My location',
              onPressed: onRecenter!,
              icon: Icon(
                Icons.my_location_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        Positioned(
          top: hasLocationControl
              ? null
              : MediaQuery.paddingOf(context).top + 12,
          bottom: hasLocationControl
              ? bottomControlsOffset + 64
              : null,
          right: 12,
          child: _MapControlButton(
            tooltip: 'Reset map to north',
            onPressed: () {
              try {
                controller.rotate(0);
              } catch (_) {}
            },
            icon: _NorthCompass(
              controller: controller,
              deviceHeadingStream: deviceHeadingStream,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}

class _NorthCompass extends StatefulWidget {
  const _NorthCompass({
    required this.controller,
    this.deviceHeadingStream,
  });

  final MapController controller;
  final Stream<double>? deviceHeadingStream;

  @override
  State<_NorthCompass> createState() => _NorthCompassState();
}

class _NorthCompassState extends State<_NorthCompass> {
  StreamSubscription<MapEvent>? _mapEvents;
  StreamSubscription<double>? _headingEvents;
  double _mapRotation = 0;
  double? _deviceHeading;

  @override
  void initState() {
    super.initState();
    _mapEvents = widget.controller.mapEventStream.listen((event) {
      if (!mounted) return;
      final rotation = event.camera.rotation;
      if ((rotation - _mapRotation).abs() < 0.1) return;
      setState(() => _mapRotation = rotation);
    });
    _listenToDeviceHeading(widget.deviceHeadingStream);
  }

  void _listenToDeviceHeading(Stream<double>? stream) {
    _headingEvents?.cancel();
    _headingEvents = stream?.listen(
      (heading) {
        if (!mounted) return;
        if (_deviceHeading != null &&
            _headingDelta(_deviceHeading!, heading).abs() < 0.5) {
          return;
        }
        setState(() => _deviceHeading = heading);
      },
      onError: (_) {
        if (mounted) setState(() => _deviceHeading = null);
      },
    );
  }

  double _headingDelta(double from, double to) {
    var delta = to - from;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  @override
  void didUpdateWidget(covariant _NorthCompass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceHeadingStream != widget.deviceHeadingStream) {
      _listenToDeviceHeading(widget.deviceHeadingStream);
    }
  }

  @override
  void dispose() {
    _mapEvents?.cancel();
    _headingEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rotation = _deviceHeading ?? _mapRotation;
    return Transform.rotate(
      // When available, the phone heading shows where geographic north is
      // relative to the physical phone. Fall back to map rotation if the
      // device has no compass sensor.
      angle: -rotation * math.pi / 180,
      child: CustomPaint(
        size: const Size.square(24),
        painter: _CompassPainter(
          northColor: colors.primary,
          southColor: colors.onSurfaceVariant,
          ringColor: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({
    required this.northColor,
    required this.southColor,
    required this.ringColor,
  });

  final Color northColor;
  final Color southColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.38;
    final ring = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius, ring);

    final north = ui.Path()
      ..moveTo(center.dx, center.dy - radius - 1)
      ..lineTo(center.dx - 3.2, center.dy + 1)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + 3.2, center.dy + 1)
      ..close();
    final south = ui.Path()
      ..moveTo(center.dx, center.dy + radius + 1)
      ..lineTo(center.dx - 3.2, center.dy - 1)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + 3.2, center.dy - 1)
      ..close();

    canvas
      ..drawPath(north, Paint()..color = northColor)
      ..drawPath(south, Paint()..color = southColor)
      ..drawCircle(center, 1.5, Paint()..color = ringColor);
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) {
    return northColor != oldDelegate.northColor ||
        southColor != oldDelegate.southColor ||
        ringColor != oldDelegate.ringColor;
  }
}
