import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/models/app_role.dart';
import 'ui/core/providers/app_role_provider.dart';
import 'ui/core/providers/theme_mode_provider.dart';
import 'ui/core/routing/app_router.dart';
import 'ui/core/theme/ridons_colors.dart';
import 'ui/core/theme/ridons_theme.dart';

class RidonsApp extends ConsumerStatefulWidget {
  const RidonsApp({super.key});

  @override
  ConsumerState<RidonsApp> createState() => _RidonsAppState();
}

class _RidonsAppState extends ConsumerState<RidonsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  Brightness _resolve(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(appRoleProvider) ?? AppRole.passenger;
    final savedMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final brightness = _resolve(savedMode);

    return MaterialApp.router(
      title: 'Ridons',
      debugShowCheckedModeBanner: false,
      theme: RidonsTheme.forRole(role),
      darkTheme: RidonsTheme.forRole(role, brightness: Brightness.dark),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        return AnnotatedRegion(
          value: context.ridonsOverlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
