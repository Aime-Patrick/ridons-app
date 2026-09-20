import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/account_details_view.dart';
import '../../features/auth/sign_in_view.dart';
import '../../features/auth/sign_up_view.dart';
import '../../features/onboarding/onboarding_view.dart';
import '../../features/shell/main_shell_view.dart';
import '../../features/splash/splash_view.dart';
import '../../features/widgets_lab/widgets_lab_view.dart';
import '../providers/session_providers.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signInPhone = '/sign-in/phone';
  static const signInCode = '/sign-in/code';
  static const signUp = '/sign-up';
  static const signUpPhone = '/sign-up/phone';
  static const signUpCode = '/sign-up/code';
  static const signUpAccount = '/sign-up/account';
  static const widgetsLab = '/widgets';
  static const home = '/home';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authSessionProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == AppRoutes.splash || loc == AppRoutes.widgetsLab) {
        return null;
      }

      final session = ref.read(authSessionProvider);
      if (session.isLoading) {
        return AppRoutes.splash;
      }

      final loggedIn = session.asData?.value != null;
      final needsProfile = session.asData?.value?.needsProfile ?? false;
      final onAccount = loc == AppRoutes.signUpAccount;
      final onAuth = loc.startsWith('/sign-in') ||
          loc.startsWith('/sign-up') ||
          loc == AppRoutes.onboarding;

      if (loggedIn && needsProfile && !onAccount) {
        return AppRoutes.signUpAccount;
      }
      if (loggedIn && !needsProfile && onAuth) {
        return AppRoutes.home;
      }
      if (!loggedIn && loc == AppRoutes.home) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const OnboardingView(),
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.widgetsLab,
        builder: (context, state) => const WidgetsLabView(),
      ),
      GoRoute(
        path: AppRoutes.signInPhone,
        builder: (context, state) => const SignInView(),
      ),
      GoRoute(
        path: AppRoutes.signInCode,
        builder: (context, state) => const SignInView(showCode: true),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpView(),
      ),
      GoRoute(
        path: AppRoutes.signUpPhone,
        builder: (context, state) => const SignInView(isSignUp: true),
      ),
      GoRoute(
        path: AppRoutes.signUpCode,
        builder: (context, state) =>
            const SignInView(showCode: true, isSignUp: true),
      ),
      GoRoute(
        path: AppRoutes.signUpAccount,
        builder: (context, state) => const AccountDetailsView(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainShellView(),
      ),
    ],
  );
});
