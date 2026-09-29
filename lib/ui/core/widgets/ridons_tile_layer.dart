import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Basemap tiles that follow the phone light/dark setting.
///
/// Light: OpenStreetMap streets with an Esri street-map fallback.
/// Dark: Esri's dark-gray base with its dark-gray reference overlay.
///
/// On high-DPI phones, retina mode requests extra zoom so streets stay sharp
/// instead of stretching 256px tiles.
abstract final class RidonsMapTiles {
  static const _userAgent = 'app.ridons.mobile';

  // These providers do not require a Google, Mapbox, or Carto API key.
  static const _light = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _lightFallback =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const _darkBase =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const _darkBaseFallback =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const _darkReference =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';
  static const _darkReferenceFallback =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

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
    );
  }

  static List<Widget> layers(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return [
        _layer(
          key: const ValueKey('ridons-map-dark-base'),
          context: context,
          url: _darkBase,
          fallbackUrl: _darkBaseFallback,
          maxNativeZoom: 16,
        ),
        _layer(
          key: const ValueKey('ridons-map-dark-reference'),
          context: context,
          url: _darkReference,
          fallbackUrl: _darkReferenceFallback,
          maxNativeZoom: 16,
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
