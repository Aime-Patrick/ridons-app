import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/app_role.dart';
import '../../../domain/models/session_user.dart';
import '../../core/providers/session_providers.dart';
import '../../core/widgets/widgets.dart';
import 'passenger_avatar.dart';

Future<void> showProfilePhotoSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'profile_photo'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'profile_photo_description'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _upload(context, ref);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('upload_image'.tr()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  if (!context.mounted) return;
                  await _pickAvatar(context, ref);
                },
                icon: const Icon(Icons.face_retouching_natural_outlined),
                label: Text('use_avatar'.tr()),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _upload(BuildContext context, WidgetRef ref) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 720,
    imageQuality: 82,
  );
  if (picked == null || !context.mounted) return;
  final session = await ref
      .read(authViewModelProvider)
      .uploadPhoto(picked.path);
  if (!context.mounted) return;
  if (session == null) {
    final message =
        (ref.read(authViewModelProvider).errorMessage ?? 'could_not_upload')
            .tr();
    RidonsNotice.error(context, message);
    return;
  }
  await ref.read(authSessionProvider.notifier).setSession(session);
}

Future<void> _pickAvatar(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'choose_avatar'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final preset in AvatarPreset.all)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final session = await ref
                            .read(authViewModelProvider)
                            .setAvatarKey(preset.key);
                        if (!context.mounted) return;
                        if (session == null) {
                          final message =
                              ref.read(authViewModelProvider).errorMessage ??
                              'could_not_save_avatar';
                          RidonsNotice.error(context, message);
                          return;
                        }
                        await ref
                            .read(authSessionProvider.notifier)
                            .setSession(session);
                      },
                      child: PassengerAvatar(
                        radius: 28,
                        user: SessionUser(
                          id: 'preview',
                          phone: '',
                          role: AppRole.passenger,
                          avatarKey: preset.key,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
