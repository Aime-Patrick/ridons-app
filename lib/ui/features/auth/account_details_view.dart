import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';

/// Final phone-only sign-up step: collect the user's name.
class AccountDetailsView extends ConsumerStatefulWidget {
  const AccountDetailsView({super.key});

  @override
  ConsumerState<AccountDetailsView> createState() => _AccountDetailsViewState();
}

class _AccountDetailsViewState extends ConsumerState<AccountDetailsView> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final vm = ref.read(authViewModelProvider);
    final session = await vm.saveName(
      firstName: _firstName.text,
      lastName: _lastName.text,
      locale: context.locale.languageCode,
    );
    if (!mounted || session == null) return;
    await ref.read(authSessionProvider.notifier).setSession(session);
    if (!mounted) return;
    context.go(
      session.user.role.isDriver && !session.user.isVerified
          ? AppRoutes.driverVerification
          : AppRoutes.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authViewModelProvider, (previous, next) {
      if (next.savingProfile && previous?.savingProfile != true) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
    final vm = ref.watch(authViewModelProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.ridonsOverlay,
      child: Scaffold(
        backgroundColor: context.ridonsPage,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 56, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.ridonsInk,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Let's get to know you",
                  style: TextStyle(
                    color: context.ridonsInk,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                RidonsTextField(
                  controller: _firstName,
                  label: 'First name',
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  enabled: !vm.savingProfile,
                ),
                const SizedBox(height: 12),
                RidonsTextField(
                  controller: _lastName,
                  label: 'Last name',
                  textInputAction: TextInputAction.done,
                  enabled: !vm.savingProfile,
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
                const SizedBox(height: 22),
                RidonsButton(
                  label: 'Finish',
                  isLoading: vm.savingProfile,
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
