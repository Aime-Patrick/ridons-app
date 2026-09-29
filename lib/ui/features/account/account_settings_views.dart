import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/prefs_store.dart';
import '../../core/providers/session_providers.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';
import 'passenger_avatar.dart';
import 'profile_photo_sheet.dart';

class AccountSubpage extends StatelessWidget {
  const AccountSubpage({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
  });

  final String title;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ridonsPage,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(showBack ? 8 : 20, 12, 16, 12),
              child: showBack
                  ? RidonsBackHeader(title: title)
                  : Text(
                      title.tr(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class ProfileSettingsView extends ConsumerStatefulWidget {
  const ProfileSettingsView({super.key});

  @override
  ConsumerState<ProfileSettingsView> createState() =>
      _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends ConsumerState<ProfileSettingsView> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authSessionProvider).asData?.value?.user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = ref.read(authViewModelProvider);
    final session = await vm.saveName(
      firstName: _firstName.text,
      lastName: _lastName.text,
      locale: context.locale.languageCode,
    );
    if (!mounted) return;
    if (session == null) {
      RidonsNotice.error(
        context,
        (vm.errorMessage ?? 'could_not_save_profile').tr(),
      );
      return;
    }
    await ref.read(authSessionProvider.notifier).setSession(session);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(authViewModelProvider);
    final session = ref.watch(authSessionProvider).asData?.value;
    final phone = session?.user.phone ?? '';
    return AccountSubpage(
      title: 'profile',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PassengerAvatar(
                  user: session?.user,
                  radius: 44,
                  token: session?.token,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: context.ridonsSheet,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => showProfilePhotoSheet(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 18,
                          color: context.ridonsInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showProfilePhotoSheet(context, ref),
            child: Text('upload_image_or_avatar'.tr()),
          ),
          const SizedBox(height: 16),
          RidonsTextField(
            controller: _firstName,
            label: 'first_name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          RidonsTextField(
            controller: _lastName,
            label: 'last_name',
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          RidonsTextField(label: 'phone', hint: phone, enabled: false),
          const SizedBox(height: 12),
          _InfoCard(
            label: session?.user.role.isDriver == true
                ? 'driver_id'
                : 'passenger_id',
            value: session?.user.publicIdLabel ?? '—',
          ),
          const SizedBox(height: 24),
          RidonsButton(
            label: 'save',
            isLoading: vm.savingProfile,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class NotificationsSettingsView extends ConsumerStatefulWidget {
  const NotificationsSettingsView({super.key});

  @override
  ConsumerState<NotificationsSettingsView> createState() =>
      _NotificationsSettingsViewState();
}

class _NotificationsSettingsViewState
    extends ConsumerState<NotificationsSettingsView> {
  var _rides = true;
  var _offers = true;
  var _safety = true;
  var _ready = false;

  PrefsStore get _prefs => ref.read(prefsStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rides = await _prefs.rideNotifications();
    final offers = await _prefs.offerNotifications();
    final safety = await _prefs.safetyNotifications();
    if (!mounted) return;
    setState(() {
      _rides = rides;
      _offers = offers;
      _safety = safety;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AccountSubpage(
      title: 'notifications',
      child: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _ToggleCard(
                  title: 'ride_updates',
                  subtitle: 'ride_updates_summary',
                  value: _rides,
                  onChanged: (value) async {
                    setState(() => _rides = value);
                    await _prefs.setRideNotifications(value);
                  },
                ),
                const SizedBox(height: 10),
                _ToggleCard(
                  title: 'fare_offers',
                  subtitle: 'fare_offers_summary',
                  value: _offers,
                  onChanged: (value) async {
                    setState(() => _offers = value);
                    await _prefs.setOfferNotifications(value);
                  },
                ),
                const SizedBox(height: 10),
                _ToggleCard(
                  title: 'safety_alerts',
                  subtitle: 'safety_alerts_summary',
                  value: _safety,
                  onChanged: (value) async {
                    setState(() => _safety = value);
                    await _prefs.setSafetyNotifications(value);
                  },
                ),
              ],
            ),
    );
  }
}

class LanguageSettingsView extends ConsumerWidget {
  const LanguageSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = context.locale.languageCode;
    return AccountSubpage(
      title: 'language',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          RidonsLanguageTile(
            title: 'english'.tr(),
            flag: '🇬🇧',
            outlined: true,
            isSelected: current == 'en',
            onTap: () => _select(context, ref, const Locale('en')),
          ),
          const SizedBox(height: 10),
          RidonsLanguageTile(
            title: 'kinyarwanda'.tr(),
            flag: '🇷🇼',
            outlined: true,
            isSelected: current == 'rw',
            onTap: () => _select(context, ref, const Locale('rw')),
          ),
        ],
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) async {
    await context.setLocale(locale);
    final session = await ref
        .read(authViewModelProvider)
        .saveLocale(locale.languageCode);
    if (session != null) {
      await ref.read(authSessionProvider.notifier).setSession(session);
    }
  }
}

class AppearanceSettingsView extends ConsumerWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    const options = <(ThemeMode, IconData, String, String)>[
      (
        ThemeMode.system,
        Icons.brightness_auto_rounded,
        'system',
        'system_theme',
      ),
      (ThemeMode.light, Icons.light_mode_outlined, 'light', 'always_light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'dark', 'always_dark'),
    ];
    return AccountSubpage(
      title: 'appearance',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final option in options) ...[
            _ThemeChoiceTile(
              icon: option.$2,
              title: option.$3,
              subtitle: option.$4,
              selected: mode == option.$1,
              onTap: () =>
                  ref.read(themeModeProvider.notifier).setMode(option.$1),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? RidonsColors.primary : context.ridonsLine,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: context.ridonsInk),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.tr(),
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.tr(),
                      style: TextStyle(
                        color: context.ridonsMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? RidonsColors.primary : context.ridonsLine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacySettingsView extends ConsumerWidget {
  const PrivacySettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).asData?.value?.user;
    return AccountSubpage(
      title: 'privacy_security',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _InfoCard(label: 'phone_number', value: user?.phone ?? '—'),
          const SizedBox(height: 10),
          _InfoCard(
            label: user?.role.isDriver == true ? 'driver_id' : 'passenger_id',
            value: user?.publicIdLabel ?? '—',
          ),
          const SizedBox(height: 20),
          Text(
            'privacy_description'.tr(),
            style: TextStyle(color: context.ridonsMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class AboutRidonsView extends StatelessWidget {
  const AboutRidonsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountSubpage(
      title: 'about_ridons',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'app_name'.tr(),
            style: TextStyle(
              color: context.ridonsInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text('version'.tr()),
          const SizedBox(height: 16),
          Text(
            'about_description'.tr(),
            style: TextStyle(color: context.ridonsMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class SafetyToolkitView extends ConsumerStatefulWidget {
  const SafetyToolkitView({super.key});

  @override
  ConsumerState<SafetyToolkitView> createState() => _SafetyToolkitViewState();
}

class _SafetyToolkitViewState extends ConsumerState<SafetyToolkitView> {
  List<String> _contacts = const [];

  @override
  void initState() {
    super.initState();
    ref.read(prefsStoreProvider).emergencyContacts().then((value) {
      if (mounted) setState(() => _contacts = value);
    });
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('emergency_contact'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RidonsTextField(controller: name, label: 'name'),
              const SizedBox(height: 10),
              RidonsTextField(
                controller: phone,
                label: 'phone',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );
    if (saved != true) return;
    final label = '${name.text.trim()} · ${phone.text.trim()}'.trim();
    if (label == '·') return;
    final next = [..._contacts, label];
    await ref.read(prefsStoreProvider).setEmergencyContacts(next);
    if (mounted) setState(() => _contacts = next);
  }

  @override
  Widget build(BuildContext context) {
    return AccountSubpage(
      title: 'safety_toolkit',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          RidonsButton(
            label: 'call_sos',
            onPressed: () => _launch(Uri(scheme: 'tel', path: '112')),
          ),
          const SizedBox(height: 10),
          RidonsButton(
            label: 'share_trip',
            variant: RidonsButtonVariant.secondary,
            onPressed: () async {
              const text =
                  'I am on a Ridons trip. Track me if I do not arrive.';
              await Clipboard.setData(const ClipboardData(text: text));
              if (!context.mounted) return;
              RidonsNotice.success(context, 'trip_share_copied');
            },
          ),
          const SizedBox(height: 22),
          Text(
            'emergency_contacts'.tr(),
            style: TextStyle(
              color: context.ridonsInk,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_contacts.isEmpty)
            Text(
              'no_contacts'.tr(),
              style: TextStyle(color: context.ridonsMuted),
            ),
          for (final contact in _contacts)
            Material(
              color: context.ridonsPage,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(contact),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final next = [..._contacts]..remove(contact);
                    await ref
                        .read(prefsStoreProvider)
                        .setEmergencyContacts(next);
                    setState(() => _contacts = next);
                  },
                ),
              ),
            ),
          TextButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.add),
            label: Text('add_contact'.tr()),
          ),
        ],
      ),
    );
  }
}

class HelpCenterView extends StatelessWidget {
  const HelpCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    const faqs = [
      ('faq_set_fare_q', 'faq_set_fare_a'),
      ('faq_pay_q', 'faq_pay_a'),
      ('faq_rebook_q', 'faq_rebook_a'),
    ];
    return AccountSubpage(
      title: 'help_center',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final faq in faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: context.ridonsLine),
                ),
                child: ExpansionTile(
                  title: Text(
                    faq.$1.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      faq.$2.tr(),
                      style: TextStyle(color: context.ridonsMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ContactSupportView extends StatelessWidget {
  const ContactSupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountSubpage(
      title: 'contact_support',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Material(
            color: context.ridonsPage,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.mail_outline, color: context.ridonsInk),
              title: Text('email'.tr()),
              subtitle: const Text('support@ridons.app'),
              onTap: () => _launch(
                Uri(
                  scheme: 'mailto',
                  path: 'support@ridons.app',
                  query: 'subject=Ridons support',
                ),
              ),
            ),
          ),
          Material(
            color: context.ridonsPage,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.call_outlined, color: context.ridonsInk),
              title: Text('call'.tr()),
              subtitle: const Text('+250 788 000 000'),
              onTap: () => _launch(Uri(scheme: 'tel', path: '+250788000000')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.ridonsLine),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: RidonsColors.primary,
        title: Text(
          title.tr(),
          style: TextStyle(
            color: context.ridonsInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle.tr()),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(),
            style: TextStyle(color: context.ridonsMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.ridonsInk,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launch(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
