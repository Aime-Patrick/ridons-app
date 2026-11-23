import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

ThemeMode resolveThemeMode(ThemeMode preference, Brightness systemBrightness) {
  if (preference != ThemeMode.system) return preference;
  return systemBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() {
    return ref.read(prefsStoreProvider).readThemeMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(prefsStoreProvider).setThemeMode(mode);
  }
}
