import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/data/services/recent_places_store.dart';
import 'package:ridons/domain/models/geo_place.dart';

class _MemoryRecentPlacesStorage implements RecentPlacesStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _MemoryRecentPlacesStorage storage;
  late RecentPlacesStore store;

  setUp(() {
    storage = _MemoryRecentPlacesStorage();
    store = RecentPlacesStore(storage: storage);
  });

  test('keeps destinations isolated per passenger account', () async {
    const destination = GeoPlace(
      name: 'Kigali Convention Centre',
      subtitle: 'Kimihurura',
      latitude: -1.9536,
      longitude: 30.0928,
    );

    await store.remember('passenger-a', destination);

    expect((await store.read('passenger-a')).single.name, destination.name);
    expect(await store.read('passenger-b'), isEmpty);
  });

  test('moves duplicate destination to the top and caps history', () async {
    for (var index = 0; index < 7; index++) {
      await store.remember(
        'passenger-a',
        GeoPlace(
          name: 'Place $index',
          latitude: -1.9 - index / 1000,
          longitude: 30.0 + index / 1000,
        ),
      );
    }

    const repeated = GeoPlace(
      name: 'Place 4',
      latitude: -1.904,
      longitude: 30.004,
    );
    final places = await store.remember('passenger-a', repeated);

    expect(places, hasLength(RecentPlacesStore.maxPlaces));
    expect(places.first.name, repeated.name);
    expect(places.where((place) => place.name == 'Place 4'), hasLength(1));
  });

  test('clear removes only that passenger history', () async {
    const destination = GeoPlace(
      name: 'Kigali Convention Centre',
      latitude: -1.9536,
      longitude: 30.0928,
    );
    await store.remember('passenger-a', destination);
    await store.remember('passenger-b', destination);

    await store.clear('passenger-a');

    expect(await store.read('passenger-a'), isEmpty);
    expect((await store.read('passenger-b')).single.name, destination.name);
  });
}
