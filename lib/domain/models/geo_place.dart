/// A named point on the map (pickup, dropoff, or search result).
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.subtitle = '',
  });

  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
}
