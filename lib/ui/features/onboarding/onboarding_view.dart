import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/app_role.dart';
import '../../core/providers/app_role_provider.dart';
import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';

const _brandTopFactor = 0.51;

/// Two-phase Onboarding flow:
/// 1. Language Selection (Kinyarwanda / English).
/// 2. Role Selection (Passenger "Get a ride" vs Driver "Drive & Earn").
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  int _currentStep = 0; // 0: Language, 1: Role
  Locale _selectedLocale = const Locale('en');
  AppRole? _selectedRole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  void _onLanguageContinue() {
    context.setLocale(_selectedLocale);
    setState(() => _currentStep = 1);
  }

  Future<void> _persist(AppRole role) async {
    ref.read(appRoleProvider.notifier).state = role;
    try {
      final prefs = ref.read(prefsStoreProvider);
      await prefs.setRole(role);
      await prefs.setOnboarded();
    } catch (_) {}
  }

  void _onRoleSelected(AppRole role) {
    setState(() => _selectedRole = role);
    unawaited(_persist(role));
    context.go(AppRoutes.signUp);
  }

  void _onSkip() {
    unawaited(_persist(AppRole.passenger));
    context.go(AppRoutes.signUp);
  }

  void _onSignIn() {
    unawaited(_persist(_selectedRole ?? AppRole.passenger));
    context.go(AppRoutes.signInPhone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 3,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Transform.scale(
                scale: 1.45,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/image/landing_image.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: RidonsColors.primaryDarker,
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.70),
                  Colors.black.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.025),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _currentStep == 0
                  ? _buildLanguageLayout(context)
                  : _buildRoleLayout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageLayout(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('language_layout'),
      builder: (context, constraints) {
        const maxContentWidth = 404.0;
        final contentWidth = constraints.maxWidth > maxContentWidth
            ? maxContentWidth
            : constraints.maxWidth;
        final contentLeft = (constraints.maxWidth - contentWidth) / 2;

        return Stack(
          children: [
            // Keep the language and role brand lockup on the same baseline.
            Positioned(
              left: contentLeft,
              width: contentWidth,
              top: constraints.maxHeight * _brandTopFactor,
              child: _buildBrandHeader(context),
            ),
            Positioned(
              left: contentLeft,
              width: contentWidth,
              bottom: 0,
              child: _buildSheet(
                child: _buildLanguageStep(context),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleLayout(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('role_layout'),
      builder: (context, constraints) {
        // The design frame is 404px wide with a 380px role row inside it.
        const maxContentWidth = 404.0;
        final contentWidth = constraints.maxWidth > maxContentWidth
            ? maxContentWidth
            : constraints.maxWidth;
        final contentLeft = (constraints.maxWidth - contentWidth) / 2;
        final roleRowWidth = contentWidth - 24;
        final roleScale = roleRowWidth / 380;
        final roleHeight = 197 * roleScale;

        return Stack(
          children: [
            Positioned(
              left: contentLeft,
              width: contentWidth,
              top: constraints.maxHeight * _brandTopFactor,
              child: _buildBrandHeader(context),
            ),
            Positioned(
              left: contentLeft,
              width: contentWidth,
              top: constraints.maxHeight * 0.70,
              bottom: 0,
              child: _buildSheet(
                child: _buildRoleActions(context),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              ),
            ),
            Positioned(
              left: contentLeft + 12,
              width: roleRowWidth,
              top: constraints.maxHeight * 0.61,
              child: _buildRoleCards(
                scale: roleScale,
                height: roleHeight,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RidonsLogo(
          kind: RidonsLogoKind.wordmark,
          height: 32,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            tr('tagline'),
            textAlign: TextAlign.center,
            softWrap: false,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 27 / 20,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSheet({
    required Widget child,
    required EdgeInsetsGeometry padding,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildRoleCards({
    required double scale,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RidonsRoleCard(
            title: 'Get a ride',
            description: 'Offer your price, pick from the drivers',
            imageAsset: 'assets/image/passenger_avatar.png',
            isSelected: _selectedRole == AppRole.passenger,
            onTap: () => _onRoleSelected(AppRole.passenger),
            scale: scale,
          ),
          SizedBox(width: 16 * scale),
          RidonsRoleCard(
            title: 'Drive & Earn',
            description: 'Get offers, pick from the passengers',
            imageAsset: 'assets/image/driver_avatar.png',
            isSelected: _selectedRole == AppRole.driver,
            onTap: () => _onRoleSelected(AppRole.driver),
            scale: scale,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleActions(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _onSkip,
              style: _linkButtonStyle(),
            child: _buildActionText(context, 'Skip'),
            ),
            TextButton(
              onPressed: _onSignIn,
              style: _linkButtonStyle(),
              child: _buildActionText(
                context,
                tr('sign_in'),
                color: RidonsColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _linkButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: context.ridonsInk,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  Widget _buildActionText(
    BuildContext context,
    String text, {
    Color? color,
  }) {
    final resolved = color ?? context.ridonsInk;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: resolved,
            decoration: TextDecoration.underline,
            decorationColor: resolved,
          ),
    );
  }

  Widget _buildLanguageStep(BuildContext context) {
    return Column(
      key: const ValueKey('language_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a language/Hitamo ururimi',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.ridonsInk,
              ),
        ),
        const SizedBox(height: 18),
        RidonsLanguageTile(
          title: 'Kinyarwanda',
          flag: '🇷🇼',
          isSelected: _selectedLocale.languageCode == 'rw',
          onTap: () => setState(() => _selectedLocale = const Locale('rw')),
        ),
        const SizedBox(height: 12),
        RidonsLanguageTile(
          title: 'English',
          flag: '🇬🇧',
          isSelected: _selectedLocale.languageCode == 'en',
          onTap: () => setState(() => _selectedLocale = const Locale('en')),
        ),
        const SizedBox(height: 22),
        RidonsButton(
          label: tr('continue'),
          onPressed: _onLanguageContinue,
        ),
      ],
    );
  }

}
