import 'package:flutter_compass/flutter_compass.dart';

/// Provides the device's magnetic heading without coupling map widgets to a
/// platform sensor plugin.
class CompassService {
  late final Stream<double> headingStream = _createHeadingStream();

  /// Emits a smoothed heading in degrees: 0/360 north, 90 east, 180 south,
  /// and 270 west. An empty stream is returned when the device has no sensor.
  Stream<double> _createHeadingStream() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream<double>.empty();

    double? previous;
    return events
        .where((event) {
          final heading = event.heading;
          return heading != null && heading.isFinite;
        })
        .map((event) {
          final current = _normalize(event.heading!);
          if (previous == null) {
            previous = current;
            return current;
          }

          // Smooth across 0/360 so the needle does not jump when crossing
          // north, while still responding quickly when the phone turns.
          var delta = current - previous!;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          previous = _normalize(previous! + delta * 0.25);
          return previous!;
        });
  }

  double _normalize(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}
