import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/app_role.dart';
import '../../core/providers/app_role_provider.dart';
import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';
import 'view_models/auth_view_model.dart';

/// Sign-in flow matching the phone-number and verification-code references.
class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key, this.showCode = false, this.isSignUp = false});

  final bool showCode;
  final bool isSignUp;

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    if (widget.showCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final phone = ref.read(authViewModelProvider).pendingPhone;
        if (phone.isEmpty && mounted) {
          context.go(
            widget.isSignUp ? AppRoutes.signUpPhone : AppRoutes.signInPhone,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  AppRole get _role => ref.read(appRoleProvider) ?? AppRole.passenger;

  Future<void> _continueToCode() async {
    final vm = ref.read(authViewModelProvider);
    final sent = await vm.sendCode(_phoneController.text);
    if (!mounted || !sent) return;
    context.go(
      widget.isSignUp ? AppRoutes.signUpCode : AppRoutes.signInCode,
    );
  }

  Future<void> _verify({bool? signUp}) async {
    final vm = ref.read(authViewModelProvider);
    final session = await vm.verifyCode(
      role: _role,
      signUp: signUp ?? widget.isSignUp,
    );
    if (!mounted || session == null) return;
    await ref.read(authSessionProvider.notifier).setSession(session);
    ref.read(appRoleProvider.notifier).state = session.user.role;
    if (!mounted) return;
    context.go(
      session.needsProfile ? AppRoutes.signUpAccount : AppRoutes.home,
    );
  }

  void _googleSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Google sign-in is coming soon.',
          style: TextStyle(color: context.ridonsInk),
        ),
        backgroundColor: context.ridonsFill,
      ),
    );
  }

  TextStyle _bodyStyle({
    required Color color,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: 16,
      fontWeight: weight,
      height: 1.1875,
      letterSpacing: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authViewModelProvider, (previous, next) {
      final startedLoading = (next.sending && previous?.sending != true) ||
          (next.verifying && previous?.verifying != true);
      if (startedLoading) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
    final vm = ref.watch(authViewModelProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.ridonsOverlay,
      child: Scaffold(
        backgroundColor: context.ridonsPage,
        resizeToAvoidBottomInset: false,
        appBar: widget.showCode
            ? AppBar(
                backgroundColor: context.ridonsPage,
                elevation: 0,
                automaticallyImplyLeading: false,
                systemOverlayStyle: context.ridonsOverlay,
                leading: IconButton(
                  onPressed: () => context.go(
                    widget.isSignUp
                        ? AppRoutes.signUpPhone
                        : AppRoutes.signInPhone,
                  ),
                  padding: const EdgeInsets.all(8),
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: context.ridonsLine),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 26,
                      color: context.ridonsInk,
                    ),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardIsOpen =
                    MediaQuery.viewInsetsOf(context).bottom > 0;
                final minHeight = constraints.maxHeight > 32
                    ? constraints.maxHeight - 32
                    : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: keyboardIsOpen
                          ? Alignment.topCenter
                          : Alignment.center,
                      child: SizedBox(
                        width: double.infinity,
                        child: widget.showCode
                            ? _buildCodeStep(context, vm)
                            : _buildPhoneStep(context, vm),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, AuthViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 46),
        _buildHeading('Enter your number', centered: true),
        const SizedBox(height: 8),
        Text(
          "We'll send you a verification code on your phone number",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: context.ridonsMuted,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 18 / 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        RidonsPhoneField(
          controller: _phoneController,
          autofocus: true,
          enabled: !vm.sending,
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            vm.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RidonsColors.primary,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
        RidonsButton(
          label: 'Continue',
          isLoading: vm.sending,
          onPressed: _continueToCode,
        ),
        const SizedBox(height: 46),
        Center(
          child: GestureDetector(
            onTap: () => context.go(
              widget.isSignUp ? AppRoutes.signInPhone : AppRoutes.signUp,
            ),
            child: Text.rich(
              widget.isSignUp
                  ? TextSpan(
                      text: 'Already have an account? ',
                      style: _bodyStyle(color: context.ridonsInk),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: _bodyStyle(
                            color: RidonsColors.primary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : TextSpan(
                      text: 'Don\u2019t have an account? ',
                      style: _bodyStyle(color: context.ridonsInk),
                      children: [
                        TextSpan(
                          text: 'Create One',
                          style: _bodyStyle(
                            color: RidonsColors.primary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Or',
            style: TextStyle(
              color: context.ridonsMuted,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 10),
        RidonsButton(
          label: 'Continue with Google',
          variant: RidonsButtonVariant.outline,
          leading: SvgPicture.asset(
            'assets/brand/google_g.svg',
            width: 20,
            height: 20,
          ),
          onPressed: _googleSoon,
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context, AuthViewModel vm) {
    final resendIn = vm.resendInSec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeading('Enter the code'),
        const SizedBox(height: 24),
        Text(
          'A code was sent to your number\n${vm.displayPhone}',
          style: GoogleFonts.inter(
            color: context.ridonsInk,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 19 / 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        RidonsOtpField(
          enabled: !vm.verifying && !vm.sending,
          hasError: vm.errorMessage != null,
          onChanged: vm.updateOtp,
          onCompleted: (_) => _verify(),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            vm.errorMessage!,
            style: const TextStyle(
              color: RidonsColors.primary,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
        RidonsButton(
          label: vm.phoneTaken
              ? 'Sign In instead'
              : (widget.isSignUp ? 'Continue' : 'Sign In'),
          isLoading: vm.verifying,
          onPressed: () => _verify(signUp: vm.phoneTaken ? false : null),
        ),
        const SizedBox(height: 14),
        if (resendIn > 0)
          Text.rich(
            TextSpan(
              text: 'Resend in ',
              style: _bodyStyle(color: context.ridonsInk),
              children: [
                TextSpan(
                  text: '$resendIn',
                  style: _bodyStyle(
                    color: context.ridonsInk,
                    weight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: 's',
                  style: _bodyStyle(color: context.ridonsInk),
                ),
              ],
            ),
          )
        else
          TextButton(
            onPressed: vm.resend,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
              'Resend code',
              style: _bodyStyle(
                color: RidonsColors.primary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        TextButton(
          onPressed: () => context.go(
            widget.isSignUp ? AppRoutes.signUpPhone : AppRoutes.signInPhone,
          ),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 40),
          ),
          child: Text(
            'Try a different method',
            style: _bodyStyle(color: RidonsColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildHeading(String text, {bool centered = false}) {
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      style: GoogleFonts.inter(
        color: context.ridonsInk,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
  }
}
