import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/session_user.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/providers/session_providers.dart';
import '../../core/providers/theme_mode_provider.dart';
import 'account_settings_views.dart';
import 'driver_documents_view.dart';
import 'passenger_avatar.dart';

/// Passenger account hub and working settings.
class AccountView extends ConsumerWidget {
  const AccountView({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).asData?.value;
    final user = session?.user;
    final name =
        user?.displayName ??
        (user?.role.isDriver == true ? 'driver'.tr() : 'passenger'.tr());
    final idLabel = user == null ? '—' : user.roleIdCaption;

    return ColoredBox(
      color: context.ridonsPage,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: RidonsColors.primary,
          onRefresh: () async {
            await ref.read(authSessionProvider.notifier).refreshProfile();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'account'.tr(),
                style: TextStyle(
                  color: context.ridonsInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.ridonsInk,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          idLabel,
                          style: TextStyle(
                            color: context.ridonsMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PassengerAvatar(
                    user: user,
                    radius: 32,
                    token: session?.token,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OutlineTile(
                icon: Icons.person_outline_rounded,
                label: 'profile',
                onTap: () => _open(context, const ProfileSettingsView()),
              ),
              if (user?.role.isDriver == true) ...[
                const SizedBox(height: 10),
                _OutlineTile(
                  icon: Icons.verified_user_outlined,
                  label: 'driver_documents',
                  subtitle: switch (user!.verificationStatus) {
                    VerificationStatus.approved => 'approved',
                    VerificationStatus.rejected => 'documents_need_changes',
                    VerificationStatus.pending => 'documents_need_approval',
                    VerificationStatus.suspended => 'verification_not_approved',
                  },
                  onTap: () => _open(context, const DriverDocumentsView()),
                ),
              ],
              if (user?.canSwitchModes == true) ...[
                const SizedBox(height: 10),
                _OutlineTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'account_mode',
                  subtitle: user!.role.isDriver
                      ? 'driver_mode_active'
                      : 'passenger_mode_active',
                  onTap: () => _open(context, const AccountModeSettingsView()),
                ),
              ],
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.notifications_none_rounded,
                label: 'notification_settings',
                showChevron: false,
                onTap: () => _open(context, const NotificationsSettingsView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.language_rounded,
                label: 'language',
                onTap: () => _open(context, const LanguageSettingsView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.dark_mode_outlined,
                label: 'appearance',
                subtitle: switch (ref.watch(themeModeProvider).asData?.value ??
                    ThemeMode.system) {
                  ThemeMode.light => 'light',
                  ThemeMode.dark => 'dark',
                  ThemeMode.system => 'system',
                },
                onTap: () => _open(context, const AppearanceSettingsView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.lock_outline_rounded,
                label: 'privacy_security',
                onTap: () => _open(context, const PrivacySettingsView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.info_outline_rounded,
                label: 'about_ridons',
                onTap: () => _open(context, const AboutRidonsView()),
              ),
              const SizedBox(height: 18),
              _OutlineTile(
                icon: Icons.health_and_safety_outlined,
                label: 'safety_toolkit',
                subtitle: 'safety_toolkit_summary',
                onTap: () => _open(context, const SafetyToolkitView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.help_outline_rounded,
                label: 'help_center',
                onTap: () => _open(context, const HelpCenterView()),
              ),
              const SizedBox(height: 10),
              _OutlineTile(
                icon: Icons.headset_mic_outlined,
                label: 'contact_support',
                onTap: () => _open(context, const ContactSupportView()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(authSessionProvider.notifier).clear();
                    if (!context.mounted) return;
                    context.go(AppRoutes.onboarding);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RidonsColors.primary,
                    foregroundColor: Colors.white,
                    alignment: Alignment.center,
                  ),
                  child: Text('sign_out'.tr(), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineTile extends StatelessWidget {
  const _OutlineTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.showDot = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final int? badge;
  final bool showDot;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.ridonsLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: context.ridonsInk, size: 24),
                  if (showDot)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: RidonsColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.tr(),
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!.tr(),
                        style: TextStyle(
                          color: context.ridonsMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: RidonsColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (showChevron)
                Icon(Icons.chevron_right_rounded, color: context.ridonsInk),
            ],
          ),
        ),
      ),
    );
  }
}
