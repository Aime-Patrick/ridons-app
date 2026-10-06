import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:ridons/data/services/routing_service.dart';
import 'package:ridons/data/services/location_service.dart';
import 'package:ridons/domain/models/geo_place.dart';

void main() {
  test('suggests fare from road km in 50 RWF steps', () {
    final fare = RoutingService().suggestFareFromKm(3.2);
    expect(fare, inInclusiveRange(1500, 2500));
    expect(fare % 50, 0);
  });

  test('haversine suggest still works as sync fallback', () {
    const pickup = GeoPlace(
      name: 'Nyarutarama',
      latitude: -1.9330,
      longitude: 30.0980,
    );
    const dropoff = GeoPlace(
      name: 'Remera Bus Park',
      latitude: -1.9577,
      longitude: 30.1144,
    );

    final fare = RoutingService().suggestFare(pickup, dropoff);

    expect(fare, inInclusiveRange(1500, 2500));
    expect(fare % 50, 0);
  });

  test('RouteResult suggestedFare matches road formula', () {
    const result = RouteResult(
      points: [LatLng(0, 0), LatLng(1, 1)],
      distanceKm: 4.0,
      durationMin: 12,
      method: 'osrm_driving',
    );
    expect(result.suggestedFare, 2000);
  });

  test('decodePolyline reads OSRM google-encoded geometry', () {
    // Canonical sample: (38.5, -120.2)
    final points = RoutingService.decodePolyline('_p~iF~ps|U');
    expect(points, hasLength(1));
    expect(points.first.latitude, closeTo(38.5, 0.0001));
    expect(points.first.longitude, closeTo(-120.2, 0.0001));
  });

  test('midpointAlong is halfway by path length', () {
    final mid = RoutingService.midpointAlong(const [
      LatLng(0, 0),
      LatLng(0, 1),
      LatLng(0, 2),
    ]);
    expect(mid, isNotNull);
    expect(mid!.latitude, closeTo(0, 0.0001));
    expect(mid.longitude, closeTo(1, 0.0001));
  });

  test('distanceToPolylineMeters measures the nearest route segment', () {
    final distance = RoutingService.distanceToPolylineMeters(
      const LatLng(0.001, 0.5),
      const [LatLng(0, 0), LatLng(0, 1)],
    );
    expect(distance, closeTo(111, 3));
  });

  test('speedKmh derives movement when GPS speed is unavailable', () {
    final previous = _position(
      latitude: 0,
      timestamp: DateTime.utc(2026, 1, 1, 12),
    );
    final current = _position(
      latitude: 0.0001,
      timestamp: DateTime.utc(2026, 1, 1, 12, 0, 10),
    );

    expect(LocationService.speedKmh(current, previous), closeTo(4.0, 0.5));
  });
}

Position _position({
  required double latitude,
  required DateTime timestamp,
  double longitude = 0,
  double speed = 0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}
