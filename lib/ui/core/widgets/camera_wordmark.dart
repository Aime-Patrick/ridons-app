import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reveals the existing RIDONS wordmark as if a camera is pulling back from
/// the first letter. The SVG is rendered as one wordmark throughout; only the
/// viewport changes during the animation.
class CameraWordmark extends StatefulWidget {
  const CameraWordmark({
    super.key,
    this.width = 150,
    this.initialZoom = 3.2,
    this.duration = const Duration(milliseconds: 900),
  });

  /// Final width of the complete wordmark.
  final double width;

  /// How close the initial camera is to the first letter.
  final double initialZoom;

  final Duration duration;

  @override
  State<CameraWordmark> createState() => _CameraWordmarkState();
}

class _CameraWordmarkState extends State<CameraWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalHeight = widget.width * (36.0 / 148.0);
    final viewportHeight = finalHeight * widget.initialZoom;

    return Semantics(
      label: 'Ridons',
      image: true,
      child: SizedBox(
        width: widget.width,
        height: viewportHeight,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return _CameraWordmarkFrame(
              progress: _controller.value,
              width: widget.width,
              height: finalHeight,
              viewportHeight: viewportHeight,
              initialZoom: widget.initialZoom,
            );
          },
        ),
      ),
    );
  }
}

class _CameraWordmarkFrame extends StatelessWidget {
  const _CameraWordmarkFrame({
    required this.progress,
    required this.width,
    required this.height,
    required this.viewportHeight,
    required this.initialZoom,
  });

  final double progress;
  final double width;
  final double height;
  final double viewportHeight;
  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    final cameraProgress = Curves.easeInOutCubic.transform(progress);
    final zoom = lerpDouble(initialZoom, 1.0, cameraProgress)!;
    final initialRCenter = width * (13.0 / 148.0);
    final initialLeft = width / 2 - initialRCenter * initialZoom;
    final left = lerpDouble(initialLeft, 0, cameraProgress)!;
    final imageWidth = width * zoom;
    final imageHeight = height * zoom;
    final top = (viewportHeight - imageHeight) / 2;
    final rWidth = width * (27.0 / 148.0) * zoom;
    final initialViewportWidth = rWidth * 1.1;
    final viewportWidth = lerpDouble(
      initialViewportWidth,
      width,
      cameraProgress,
    )!;
    final viewportLeft = (width - viewportWidth) / 2;

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: viewportLeft,
            top: 0,
            width: viewportWidth,
            height: viewportHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: left - viewportLeft,
                    top: top,
                    width: imageWidth,
                    height: imageHeight,
                    child: SvgPicture.asset(
                      'assets/brand/logo_full.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
