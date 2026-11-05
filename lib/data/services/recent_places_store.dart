import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/geo_place.dart';

abstract interface class RecentPlacesStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureRecentPlacesStorage implements RecentPlacesStorage {
  SecureRecentPlacesStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores a small, account-scoped list of destinations encrypted on-device.
class RecentPlacesStore {
  RecentPlacesStore({RecentPlacesStorage? storage})
    : _storage = storage ?? SecureRecentPlacesStorage();

  static const maxPlaces = 6;
  final RecentPlacesStorage _storage;

  String _key(String passengerId) => 'ridons.recentDestinations.$passengerId';

  Future<List<GeoPlace>> read(String passengerId) async {
    if (passengerId.isEmpty) return const [];
    final raw = await _storage.read(_key(passengerId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final places = <GeoPlace>[];
      for (final value in decoded) {
        if (value is! Map<String, dynamic> ||
            value['name'] is! String ||
            (value['subtitle'] != null && value['subtitle'] is! String) ||
            value['latitude'] is! num ||
            value['longitude'] is! num) {
          continue;
        }
        places.add(
          GeoPlace(
            name: value['name'] as String,
            subtitle: value['subtitle'] as String? ?? '',
            latitude: (value['latitude'] as num).toDouble(),
            longitude: (value['longitude'] as num).toDouble(),
          ),
        );
      }
      return places.take(maxPlaces).toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<List<GeoPlace>> remember(String passengerId, GeoPlace place) async {
    if (passengerId.isEmpty) return const [];
    final existing = await read(passengerId);
    final normalizedName = place.name.trim().toLowerCase();
    final normalizedSubtitle = place.subtitle.trim().toLowerCase();
    final next = [
      place,
      ...existing.where((item) {
        final sameCoordinates =
            (item.latitude - place.latitude).abs() < 0.0001 &&
            (item.longitude - place.longitude).abs() < 0.0001;
        final sameLabel =
            item.name.trim().toLowerCase() == normalizedName &&
            item.subtitle.trim().toLowerCase() == normalizedSubtitle;
        return !sameCoordinates && !sameLabel;
      }),
    ].take(maxPlaces).toList(growable: false);

    await _storage.write(
      _key(passengerId),
      jsonEncode(next.map(_toJson).toList(growable: false)),
    );
    return next;
  }

  Future<void> clear(String passengerId) async {
    if (passengerId.isEmpty) return;
    await _storage.delete(_key(passengerId));
  }

  Map<String, Object> _toJson(GeoPlace place) => {
    'name': place.name,
    'subtitle': place.subtitle,
    'latitude': place.latitude,
    'longitude': place.longitude,
  };
}
