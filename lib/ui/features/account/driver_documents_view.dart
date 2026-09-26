import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/driver_document.dart';
import '../../../domain/models/session_user.dart';
import '../../core/providers/session_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import 'account_settings_views.dart';
import 'view_models/driver_documents_view_model.dart';

class DriverDocumentsView extends ConsumerStatefulWidget {
  const DriverDocumentsView({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<DriverDocumentsView> createState() =>
      _DriverDocumentsViewState();
}

class _DriverDocumentsViewState extends ConsumerState<DriverDocumentsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(driverDocumentsViewModelProvider).load();
    });
  }

  Future<void> _pick(DriverDocumentType type) async {
    final choice = await showModalBottomSheet<_DocumentPickChoice>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                type.label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload a clear photo or PDF. Make sure all text is visible.',
                style: TextStyle(color: context.ridonsMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  _DocumentPickChoice.camera,
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take a photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  _DocumentPickChoice.gallery,
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  _DocumentPickChoice.pdf,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Choose a PDF'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == _DocumentPickChoice.pdf) {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (picked == null || !mounted) return;
      final path = picked.path;
      if (path == null || path.isEmpty) {
        _showUploadMessage('Could not access the selected PDF.');
        return;
      }
      await _upload(
        type: type,
        filePath: path,
        fileName: picked.name,
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: choice == _DocumentPickChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;

    await _upload(
      type: type,
      filePath: picked.path,
      fileName: picked.name,
    );
  }

  Future<void> _upload({
    required DriverDocumentType type,
    required String filePath,
    required String fileName,
  }) async {
    if (!mounted) return;

    final viewModel = ref.read(driverDocumentsViewModelProvider);
    final success = await viewModel.upload(
      type: type,
      filePath: filePath,
      fileName: fileName,
    );
    if (!mounted) return;
    _showUploadMessage(
      success
          ? '${type.label} uploaded for review.'
          : viewModel.errorMessage ?? 'Could not upload this document.',
    );
  }

  void _showUploadMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(driverDocumentsViewModelProvider);
    final session = ref.watch(authSessionProvider).asData?.value;
    final verificationStatus = session?.user.verificationStatus;
    return AccountSubpage(
      title: widget.onboarding && verificationStatus == VerificationStatus.rejected
          ? 'Update your documents'
          : widget.onboarding
              ? 'Verify your driver account'
              : 'Driver documents',
      showBack: !widget.onboarding,
      child: RefreshIndicator(
        color: RidonsColors.primary,
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Upload the documents required to start accepting rides.',
              style: TextStyle(color: context.ridonsMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            _VerificationBanner(
              viewModel: viewModel,
              status: verificationStatus,
              reason: session?.user.rejectReason,
            ),
            const SizedBox(height: 16),
            if (viewModel.loading && viewModel.documents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final type in DriverDocumentType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentTile(
                  type: type,
                  document: viewModel.documentFor(type),
                  uploading: viewModel.uploading == type,
                  onUpload: () => _pick(type),
                ),
              ),
            if (viewModel.errorMessage != null && !viewModel.loading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: RidonsColors.primary),
                ),
              ),
            if (widget.onboarding) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: viewModel.loading
                    ? null
                    : () async {
                        await ref
                            .read(authSessionProvider.notifier)
                            .refreshProfile();
                        await viewModel.load();
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check verification status'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref.read(authSessionProvider.notifier).clear();
                  if (context.mounted) context.go(AppRoutes.onboarding);
                },
                child: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DocumentPickChoice { camera, gallery, pdf }

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.viewModel,
    required this.status,
    this.reason,
  });

  final DriverDocumentsViewModel viewModel;
  final VerificationStatus? status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final complete = viewModel.canApprove;
    final rejected = status == VerificationStatus.rejected;
    final title = rejected
        ? 'Some documents need changes before approval.'
        : complete
            ? 'All documents are ready for admin review.'
            : 'Upload all required documents to continue.';
    final detail = rejected && (reason ?? '').trim().isNotEmpty
        ? reason!.trim()
        : 'Your documents are reviewed manually before you can go online.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: complete && !rejected
            ? RidonsColors.success.withValues(alpha: .1)
            : RidonsColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete && !rejected
              ? RidonsColors.success.withValues(alpha: .35)
              : RidonsColors.primaryLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              complete && !rejected
                  ? Icons.verified_outlined
                  : Icons.shield_outlined,
              color: complete && !rejected
                  ? RidonsColors.success
                  : RidonsColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title\n$detail',
                style: TextStyle(
                  color: context.ridonsInk,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.document,
    required this.uploading,
    required this.onUpload,
  });

  final DriverDocumentType type;
  final DriverDocument? document;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final status = document?.status;
    final statusColor = switch (status) {
      DriverDocumentStatus.approved => RidonsColors.success,
      DriverDocumentStatus.rejected => RidonsColors.primary,
      _ => context.ridonsMuted,
    };
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.ridonsLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.description_outlined, color: context.ridonsInk),
        title: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          document == null
              ? 'Required · not uploaded'
              : '${status?.name ?? 'pending'}${document!.rejectReason == null ? '' : ' · ${document!.rejectReason}'}',
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
        trailing: uploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: document == null ? 'Upload' : 'Replace document',
                onPressed: onUpload,
                icon: Icon(
                  document == null ? Icons.file_upload_outlined : Icons.refresh_rounded,
                ),
              ),
      ),
    );
  }
}
