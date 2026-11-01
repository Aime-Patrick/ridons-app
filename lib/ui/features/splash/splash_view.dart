import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_role_provider.dart';
import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/widgets.dart';

/// The only animated brand sequence shown when the app opens.
///
/// The native launch screen shows the static Ridons R while Flutter loads.
/// Once Flutter is ready, this view runs the camera pull-back wordmark and
/// then routes to the correct first screen.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  Timer? _leaveTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _leaveTimer = Timer(const Duration(milliseconds: 1550), _leave);
  }

  Future<void> _leave() async {
    if (!mounted || _leaving) return;
    _leaving = true;

    final session = await ref.read(authSessionProvider.future);
    if (!mounted) return;
    if (session != null) {
      ref.read(appRoleProvider.notifier).state = session.user.role;
      context.go(
        session.needsProfile ? AppRoutes.signUpAccount : AppRoutes.home,
      );
      return;
    }

    final prefs = ref.read(prefsStoreProvider);
    final onboarded = await prefs.isOnboarded();
    final role = await prefs.readRole();
    if (role != null) {
      ref.read(appRoleProvider.notifier).state = role;
    }
    if (!mounted) return;
    context.go(onboarded ? AppRoutes.signInPhone : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RidonsSplashBackground(
        child: Center(
          child: const CameraWordmark(
            width: 220,
            initialZoom: 3.2,
            duration: Duration(milliseconds: 1100),
          ),
        ),
      ),
    );
  }
}
