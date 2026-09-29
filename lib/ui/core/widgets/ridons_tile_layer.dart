import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Basemap tiles that follow the phone light/dark setting.
///
/// Light: OpenStreetMap streets with an Esri street-map fallback.
/// Dark: Esri's dark-gray map with an OpenStreetMap fallback.
///
/// On high-DPI phones, retina mode requests extra zoom so streets stay sharp
/// instead of stretching 256px tiles.
abstract final class RidonsMapTiles {
  static const _userAgent = 'app.ridons.mobile';

  // These providers do not require a Google, Mapbox, or Carto API key.
  static const _light =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _lightFallback =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const _dark =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray/MapServer/tile/{z}/{y}/{x}';
  static const _darkFallback =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static TileLayer _layer({
    required BuildContext context,
    required String url,
    String? fallbackUrl,
    required int maxNativeZoom,
  }) {
    return TileLayer(
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
    );
  }

  static List<Widget> layers(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return [
        _layer(
          context: context,
          url: _dark,
          fallbackUrl: _darkFallback,
          maxNativeZoom: 16,
        ),
      ];
    }
    return [
      _layer(
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
