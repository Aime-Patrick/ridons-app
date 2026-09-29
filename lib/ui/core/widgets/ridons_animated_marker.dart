import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Animates a moving map marker between real location fixes.
///
/// The animation is visual only: the target remains the exact GPS coordinate
/// received from the device, while the transition prevents visible jumps.
class RidonsAnimatedMarker extends StatefulWidget {
  const RidonsAnimatedMarker({
    super.key,
    required this.point,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.alignment = Alignment.center,
    this.duration = const Duration(milliseconds: 700),
  });

  final LatLng point;
  final Widget child;
  final double width;
  final double height;
  final Alignment alignment;
  final Duration duration;

  @override
  State<RidonsAnimatedMarker> createState() => _RidonsAnimatedMarkerState();
}

class _RidonsAnimatedMarkerState extends State<RidonsAnimatedMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  LatLng? _displayPoint;
  LatLng? _from;
  LatLng? _to;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _displayPoint = widget.point;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = _animationDuration;
  }

  @override
  void didUpdateWidget(covariant RidonsAnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _animationDuration;
    if (_samePoint(oldWidget.point, widget.point)) return;
    _animateTo(widget.point);
  }

  Duration get _animationDuration {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduced ? Duration.zero : widget.duration;
  }

  void _animateTo(LatLng point) {
    final current = _animatedPoint();
    _from = current;
    _to = point;
    _controller.forward(from: 0);
  }

  LatLng _animatedPoint() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return _displayPoint ?? widget.point;
    final t = Curves.easeOutCubic.transform(_controller.value);
    final point = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    if (_controller.isCompleted) _displayPoint = to;
    return point;
  }

  bool _samePoint(LatLng a, LatLng b) {
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MarkerLayer(
          markers: [
            Marker(
              point: _animatedPoint(),
              width: widget.width,
              height: widget.height,
              alignment: widget.alignment,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
