import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Basemap tiles that follow the phone light/dark setting.
///
/// Both themes use the same detailed OpenStreetMap street tiles. Dark mode
/// applies a restrained slate color treatment to the tiles only, keeping map
/// content consistent while leaving route and location overlays untouched.
///
/// On high-DPI phones, retina mode requests extra zoom so streets stay sharp
/// instead of stretching 256px tiles.
///
/// Tile caching is enabled automatically by flutter_map on Android/iOS.
/// Tiles loaded once are stored on disk and reused on the next app open,
/// so the map appears instantly without a network round-trip.
abstract final class RidonsMapTiles {
  static const _userAgent = 'app.ridons.mobile';

  // Cache provider shared across all tile layers — 500 MB limit,
  // tiles kept for 30 days regardless of server Cache-Control headers.
  static final _cacheProvider = BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 500 * 1024 * 1024, // 500 MB
    overrideFreshAge: const Duration(days: 30),
  );

  // These providers do not require a Google, Mapbox, or Carto API key.
  static const _light = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _lightFallback =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const _darkMapFilter = ColorFilter.matrix([
    -0.144568,
    -0.486336,
    -0.049096,
    0,
    189.4,
    -0.140316,
    -0.472032,
    -0.047652,
    0,
    188.3,
    -0.133938,
    -0.450576,
    -0.045486,
    0,
    187.65,
    0,
    0,
    0,
    1,
    0,
  ]);

  static TileLayer _layer({
    required Key key,
    required BuildContext context,
    required String url,
    String? fallbackUrl,
    required int maxNativeZoom,
  }) {
    return TileLayer(
      key: key,
      urlTemplate: url,
      fallbackUrl: fallbackUrl,
      userAgentPackageName: _userAgent,
      maxNativeZoom: maxNativeZoom,
      keepBuffer: 2,
      panBuffer: 1,
      retinaMode: RetinaMode.isHighDensity(context),
      tileDisplay: const TileDisplay.fadeIn(
        duration: Duration(milliseconds: 120),
      ),
      tileProvider: NetworkTileProvider(cachingProvider: _cacheProvider),
    );
  }

  static List<Widget> layers(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return [
        ColorFiltered(
          key: const ValueKey('ridons-map-dark-osm'),
          colorFilter: _darkMapFilter,
          child: _layer(
            key: const ValueKey('ridons-map-dark-osm-tiles'),
            context: context,
            url: _light,
            fallbackUrl: _lightFallback,
            maxNativeZoom: 19,
          ),
        ),
      ];
    }
    return [
      _layer(
        key: const ValueKey('ridons-map-light'),
        context: context,
        url: _light,
        fallbackUrl: _lightFallback,
        maxNativeZoom: 19,
      ),
    ];
  }
}

/// Drop-in single child for maps that only need the base (mini maps).
class RidonsTileLayer extends StatelessWidget {
  const RidonsTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return RidonsMapTiles.layers(context).first;
  }
}
