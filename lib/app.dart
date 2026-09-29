import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/models/app_role.dart';
import 'ui/core/providers/app_role_provider.dart';
import 'ui/core/providers/session_providers.dart';
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
  String? _lastSyncedLocale;

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
    ref.listen(authSessionProvider, (previous, next) {
      final savedLocale = next.asData?.value?.user.locale;
      if (savedLocale == null ||
          savedLocale == _lastSyncedLocale ||
          !{'en', 'rw'}.contains(savedLocale)) {
        return;
      }
      _lastSyncedLocale = savedLocale;
      if (context.locale.languageCode == savedLocale) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.setLocale(Locale(savedLocale));
      });
    });

    final role = ref.watch(appRoleProvider) ?? AppRole.passenger;
    final savedMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final brightness = _resolve(savedMode);
    final easyLocalizationDelegate = context.localizationDelegates.first;

    return MaterialApp.router(
      onGenerateTitle: (_) => 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      theme: RidonsTheme.forRole(role),
      darkTheme: RidonsTheme.forRole(role, brightness: Brightness.dark),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
      // Flutter does not ship Material/Widgets/Cupertino strings for rw.
      // Keep Ridons translations in Kinyarwanda while using English for
      // framework-provided labels such as " back" and "cancel".
      localizationsDelegates: [
        easyLocalizationDelegate,
        const _RidonsMaterialLocalizationsDelegate(),
        const _RidonsWidgetsLocalizationsDelegate(),
        const _RidonsCupertinoLocalizationsDelegate(),
      ],
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

Locale _frameworkLocale(Locale locale) =>
    locale.languageCode == 'rw' ? const Locale('en') : locale;

class _RidonsMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _RidonsMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_frameworkLocale(locale));

  @override
  bool shouldReload(_RidonsMaterialLocalizationsDelegate old) => false;
}

class _RidonsWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RidonsWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      GlobalWidgetsLocalizations.delegate.isSupported(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(_frameworkLocale(locale));

  @override
  bool shouldReload(_RidonsWidgetsLocalizationsDelegate old) => false;
}

class _RidonsCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _RidonsCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      GlobalCupertinoLocalizations.delegate.isSupported(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_frameworkLocale(locale));

  @override
  bool shouldReload(_RidonsCupertinoLocalizationsDelegate old) => false;
}
