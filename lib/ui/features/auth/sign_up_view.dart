import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';

/// Entry screen for phone-only account creation.
class SignUpView extends StatelessWidget {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.ridonsOverlay,
      child: Scaffold(
        backgroundColor: context.ridonsPage,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                AspectRatio(
                  aspectRatio: 368 / 268,
                  child: SvgPicture.asset(
                    'assets/brand/Sign-up.svg',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    colorMapper: dark ? const _SignupArtColorMapper() : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'fair_deals_tagline'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.ridonsInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'choose_ride_tagline'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: context.ridonsMuted,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 19 / 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 18),
                RidonsButton(
                  label: 'continue_with_phone',
                  onPressed: () => context.go(AppRoutes.signUpPhone),
                ),
                const SizedBox(height: 8),
                RidonsButton(
                  label: 'continue_with_google',
                  variant: RidonsButtonVariant.outline,
                  leading: SvgPicture.asset(
                    'assets/brand/google_g.svg',
                    width: 20,
                    height: 20,
                  ),
                  onPressed: () {
                    RidonsNotice.info(context, 'google_coming_soon'.tr());
                  },
                ),
                const SizedBox(height: 22),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.signInPhone),
                    child: Text.rich(
                      TextSpan(
                        text: 'already_have_account'.tr(),
                        style: GoogleFonts.inter(
                          color: context.ridonsInk,
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          height: 19 / 16,
                          letterSpacing: 16 * 0.005,
                        ),
                        children: [
                          TextSpan(
                            text: 'sign_in'.tr(),
                            style: GoogleFonts.inter(
                              color: RidonsColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 19 / 16,
                              letterSpacing: 16 * 0.005,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(
                    text: 'by_continuing'.tr(),
                    style: GoogleFonts.inter(
                      color: context.ridonsMuted,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 18 / 14,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'terms_conditions'.tr(),
                        style: GoogleFonts.inter(
                          color: RidonsColors.primary,
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 18 / 14,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.solid,
                          decorationColor: RidonsColors.primary,
                        ),
                      ),
                      TextSpan(text: 'acknowledge_our'.tr()),
                      TextSpan(
                        text: 'privacy_policy'.tr(),
                        style: GoogleFonts.inter(
                          color: RidonsColors.primary,
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 18 / 14,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.solid,
                          decorationColor: RidonsColors.primary,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Remaps the light-grey Sign-up art onto dark surfaces without washing out
/// brand red or navy ink.
class _SignupArtColorMapper extends ColorMapper {
  const _SignupArtColorMapper();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.r > 0.63 && color.g < 0.35 && color.b < 0.35) {
      return color;
    }
    final luminance = color.computeLuminance();
    if (luminance < 0.12) {
      return color;
    }
    if (luminance > 0.72) {
      return const Color(0xFF1E293B);
    }
    if (luminance > 0.45) {
      return const Color(0xFF334155);
    }
    return Color.lerp(color, const Color(0xFF0B1220), 0.55)!;
  }
}
