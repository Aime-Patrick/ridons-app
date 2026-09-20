import 'package:latlong2/latlong.dart';

/// A driver (or sim boda) currently in Redis GEO, drawn on the passenger map.
class LiveMapMarker {
  const LiveMapMarker({
    required this.id,
    required this.point,
    this.headingDeg = 0,
    this.speedKmh = 0,
  });

  final String id;
  final LatLng point;
  final double headingDeg;
  final double speedKmh;
}

class EtaQuote {
  const EtaQuote({
    required this.minutes,
    required this.distanceKm,
    this.method = 'haversine_v1',
  });

  final int minutes;
  final double distanceKm;
  final String method;
}
