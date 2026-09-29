import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_role_provider.dart';
import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/widgets.dart';


/// Animated Brand Splash Screen.
/// 1. Scales the single "R" into the center and holds it briefly.
/// 2. Moves that same "R" to the left.
/// 3. Staggers reveal of the remaining letters "i", "d", "o", "n", "s".
/// 3. Transitions smoothly to the Onboarding flow.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin {
  bool _leaving = false;
  late final AnimationController _controller;

  // One R instance: scale in, hold in the center, then move left.
  late final Animation<double> _rScale;
  late final Animation<double> _rSlide;

  // Staggered animations for letters: i, d, o, n, s
  late final Animation<double> _letterIOpacity;
  late final Animation<Offset> _letterISlide;

  late final Animation<double> _letterDOpacity;
  late final Animation<Offset> _letterDSlide;

  late final Animation<double> _letterOOpacity;
  late final Animation<Offset> _letterOSlide;

  late final Animation<double> _letterNOpacity;
  late final Animation<Offset> _letterNSlide;

  late final Animation<double> _letterSOpacity;
  late final Animation<Offset> _letterSSlide;

  // Final glow / subtle breathing
  late final Animation<double> _finalPulse;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      // Keep the reveal relaxed enough to read while preserving a quick start.
      duration: const Duration(milliseconds: 4200),
    );

    // 0.0 - 0.18 (~0 to 0.75s): the R scales into the center.
    _rScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutCubic),
      ),
    );

    // 0.32 - 0.50 (~1.35 to 2.1s): the same R moves from center to left.
    _rSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.50, curve: Curves.easeInOutCubic),
      ),
    );

    // Staggered letters
    // The R has finished moving before the first remaining letter appears.
    // Each letter overlaps the previous one slightly so the wordmark flows
    // together instead of feeling like five separate steps.
    // 'i' (0.52 - 0.62)
    _letterIOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _letterISlide = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    // 'd' (0.60 - 0.70)
    _letterDOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.70, curve: Curves.easeOutCubic),
      ),
    );
    _letterDSlide = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // 'o' (0.68 - 0.78)
    _letterOOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _letterOSlide = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    // 'n' (0.76 - 0.86)
    _letterNOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.76, 0.86, curve: Curves.easeOutCubic),
      ),
    );
    _letterNSlide = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.76, 0.86, curve: Curves.easeOutCubic),
      ),
    );

    // 's' (0.84 - 0.94)
    _letterSOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.84, 0.94, curve: Curves.easeOutCubic),
      ),
    );
    _letterSSlide = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.84, 0.94, curve: Curves.easeOutCubic),
      ),
    );

    // Final breathing hold (0.94 - 1.0), kept intentionally very subtle.
    _finalPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.015),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.015, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.94, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 450), _leave);
    });
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
    _controller.dispose();
    super.dispose();
  }

  // Individual letter SVGs with exact path coordinates from assets/brand/logo_full.svg.
  // The R is cropped to its own viewBox so the same widget can move from the
  // center into the final wordmark position without being recreated.
  static const _letterR = '''
<svg width="28" height="36" viewBox="0 0 28 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M25.8319 13.4146C25.8319 18.95 22.4408 22.9894 16.9553 24.3358C18.4015 27.2282 21.4435 28.9237 25.5825 28.9237H26.8293V35.4066H25.3332C16.0078 35.4066 9.47501 28.9736 9.47501 19.8477V18.3516H12.7165C16.4566 18.3516 18.8503 16.4566 18.8503 13.4146C18.8503 10.3228 16.5563 8.47765 12.7165 8.47765H6.98159V35.4066H0V1.99474H12.7165C20.5957 1.99474 25.8319 6.58264 25.8319 13.4146Z" fill="#FBFBFB"/>
</svg>''';

  static const _letterI = '''
<svg width="148" height="36" viewBox="0 0 148 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M34.0567 0C36.3506 0 38.0462 1.69553 38.0462 3.98948C38.0462 6.28343 36.3506 7.97896 34.0567 7.97896C31.7627 7.97896 30.0672 6.28343 30.0672 3.98948C30.0672 1.69553 31.7627 0 34.0567 0ZM30.8152 35.4066V11.4698H37.2981V35.4066H30.8152Z" fill="#FBFBFB"/>
</svg>''';

  static const _letterD = '''
<svg width="148" height="36" viewBox="0 0 148 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M59.2636 12.7165V1.99474H65.7466V25.9316H59.2636V23.1889C59.2636 19.8975 56.7702 17.454 53.5288 17.454C50.2374 17.454 47.7939 19.8975 47.7939 23.1889C47.7939 26.4303 50.2374 28.9237 53.5288 28.9237H65.7466V35.4066H53.5288C46.6469 35.4066 41.311 30.0208 41.311 23.1889C41.311 16.3569 46.4973 10.9711 53.1298 10.9711C55.3739 10.9711 57.4684 11.6194 59.2636 12.7165Z" fill="#FBFBFB"/>
</svg>''';

  static const _letterO = '''
<svg width="148" height="36" viewBox="0 0 148 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M69.7516 23.4382C69.7516 16.4067 75.2371 10.9711 82.2187 10.9711C89.2502 10.9711 94.6859 16.4067 94.6859 23.4382C94.6859 30.4198 89.2502 35.9053 82.2187 35.9053C75.2371 35.9053 69.7516 30.4198 69.7516 23.4382ZM76.2345 23.4382C76.2345 26.8293 78.8277 29.4224 82.2187 29.4224C85.6597 29.4224 88.203 26.8293 88.203 23.4382C88.203 19.9973 85.6597 17.454 82.2187 17.454C78.8277 17.454 76.2345 19.9973 76.2345 23.4382Z" fill="#FBFBFB"/>
</svg>''';

  static const _letterN = '''
<svg width="148" height="36" viewBox="0 0 148 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M109.874 17.454C107.032 17.454 105.137 19.2991 105.137 22.0917V35.4066H98.6539V22.0419C98.6539 15.6088 103.391 10.9711 109.874 10.9711C116.357 10.9711 121.045 15.6088 121.045 22.0419V35.4066H114.562V22.0917C114.562 19.2991 112.717 17.454 109.874 17.454Z" fill="#FBFBFB"/>
</svg>''';

  static const _letterS = '''
<svg width="148" height="36" viewBox="0 0 148 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M146.02 20.1967H139.538C139.538 18.2519 137.842 16.9553 135.249 16.9553C133.204 16.9553 131.758 17.8529 131.758 19.0996C131.758 23.0393 147.566 24.0366 147.566 35.4066H141.083C141.083 28.2754 125.275 28.7243 125.275 19.0996C125.275 14.412 129.614 10.9711 135.548 10.9711C141.732 10.9711 146.02 14.7611 146.02 20.1967ZM128.965 28.425C131.11 28.425 132.755 30.0707 132.755 32.2151C132.755 34.3095 131.11 35.9053 128.965 35.9053C126.871 35.9053 125.275 34.3095 125.275 32.2151C125.275 30.0707 126.871 28.425 128.965 28.425Z" fill="#FBFBFB"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    const wordmarkWidth = 220.0;
    const wordmarkHeight = wordmarkWidth * (36.0 / 148.0); // ~53.5
    const wordmarkTop = (90.0 - wordmarkHeight) / 2;

    return Scaffold(
      body: RidonsSplashBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              const rWidth = wordmarkWidth * (28.0 / 148.0);
              const centerRLeft = (wordmarkWidth - rWidth) / 2;
              final rLeft = centerRLeft * (1.0 - _rSlide.value);

              return ScaleTransition(
                scale: _finalPulse,
                child: SizedBox(
                  width: wordmarkWidth,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The only R in the animation. It scales in, holds in
                      // the center, then moves to the final left position.
                      Positioned(
                        left: rLeft,
                        top: wordmarkTop,
                        width: rWidth,
                        height: wordmarkHeight,
                        child: Transform.scale(
                          scale: _rScale.value,
                          child: SvgPicture.string(
                            _letterR,
                            width: rWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // The remaining letters reveal beside the R.
                      FadeTransition(
                        opacity: _letterIOpacity,
                        child: SlideTransition(
                          position: _letterISlide,
                          child: SvgPicture.string(
                            _letterI,
                            width: wordmarkWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _letterDOpacity,
                        child: SlideTransition(
                          position: _letterDSlide,
                          child: SvgPicture.string(
                            _letterD,
                            width: wordmarkWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _letterOOpacity,
                        child: SlideTransition(
                          position: _letterOSlide,
                          child: SvgPicture.string(
                            _letterO,
                            width: wordmarkWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _letterNOpacity,
                        child: SlideTransition(
                          position: _letterNSlide,
                          child: SvgPicture.string(
                            _letterN,
                            width: wordmarkWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _letterSOpacity,
                        child: SlideTransition(
                          position: _letterSSlide,
                          child: SvgPicture.string(
                            _letterS,
                            width: wordmarkWidth,
                            height: wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
