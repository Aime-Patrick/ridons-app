# Ridons (Flutter)

Single app for **passenger** and **driver** (role chosen at onboarding).

## Run

```bash
cd ridons-app/ridons
flutter pub get
flutter run
```

Flow for now: **Splash → Shared widgets lab → Shell** (bottom nav).

## Layout

```
lib/
  app.dart / main.dart
  data/services/          # API + Socket.IO stubs
  domain/models/          # AppRole
  ui/
    core/theme/           # Ridons colors + dual themes
    core/widgets/         # Reusable PDF-matched widgets
    core/routing/
    features/splash|shell|widgets_lab/
assets/brand/             # logo SVGs
assets/translations/      # en + rw
```

## Stack

Riverpod · go_router · dio · socket_io_client · google_maps_flutter · geolocator · flutter_svg · easy_localization
