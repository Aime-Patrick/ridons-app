import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

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
