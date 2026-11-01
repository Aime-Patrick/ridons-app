import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
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
import '../../core/widgets/widgets.dart';
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
  static const _maxUploadBytes = 10 * 1024 * 1024;

  Timer? _statusTimer;
  Timer? _uploadRetryTimer;
  bool _statusRefreshBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadDocuments());
      unawaited(_retryPendingDocuments(showSuccess: true));
      _uploadRetryTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_retryPendingDocuments()),
      );
      if (widget.onboarding) {
        _statusTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => unawaited(_refreshVerificationStatus()),
        );
      }
    });
  }

  Future<void> _loadDocuments({bool showError = false}) async {
    final viewModel = ref.read(driverDocumentsViewModelProvider);
    await viewModel.load();
    if (!mounted || !showError) return;
    final error = viewModel.errorMessage;
    if (error != null) _showUploadMessage(error.tr(), success: false);
  }

  Future<void> _retryPendingDocuments({bool showSuccess = false}) async {
    final ownerId = ref.read(authSessionProvider).asData?.value?.user.id;
    if (ownerId == null || ownerId.isEmpty) return;
    try {
      final completed = await ref
          .read(driverDocumentsViewModelProvider)
          .retryPendingUploads(ownerId: ownerId);
      if (completed && showSuccess && mounted) {
        RidonsNotice.success(context, 'documents_uploaded_after_wait'.tr());
      }
    } catch (_) {
      // A local queue or network failure must not escape the periodic retry.
      if (showSuccess && mounted) {
        RidonsNotice.error(context, 'could_not_upload_document'.tr());
      }
    }
  }

  Future<void> _refreshVerificationStatus({bool reloadDocuments = false}) async {
    if (!mounted || !widget.onboarding || _statusRefreshBusy) return;
    _statusRefreshBusy = true;
    try {
      await ref
          .read(authSessionProvider.notifier)
          .refreshProfile(onlyIfChanged: !reloadDocuments);
      if (reloadDocuments && mounted) {
        await _loadDocuments(showError: true);
      }
    } finally {
      _statusRefreshBusy = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _uploadRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _pick(DriverDocumentType type) async {
    final activeUpload = ref.read(driverDocumentsViewModelProvider).uploading;
    if (activeUpload != null) {
      _showUploadMessage('document_upload_in_progress'.tr(), success: false);
      return;
    }
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
                _documentTypeLabel(type),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _documentPurposeLabel(type),
                style: TextStyle(color: context.ridonsMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'document_upload_description'.tr(),
                style: TextStyle(color: context.ridonsMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _DocumentPickChoice.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('take_photo'.tr()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _DocumentPickChoice.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('choose_gallery'.tr()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _DocumentPickChoice.pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('choose_pdf'.tr()),
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
        _showUploadMessage('could_not_access_pdf'.tr(), success: false);
        return;
      }
      final size = await picked.length();
      if (!_isUploadSizeValid(size ?? 0)) return;
      await _upload(type: type, filePath: path, fileName: picked.name);
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
    final size = await picked.length();
    if (!_isUploadSizeValid(size)) return;

    await _upload(type: type, filePath: picked.path, fileName: picked.name);
  }

  bool _isUploadSizeValid(int size) {
    if (size <= 0) {
      _showUploadMessage('empty_document'.tr(), success: false);
      return false;
    }
    if (size > _maxUploadBytes) {
      _showUploadMessage('document_too_large'.tr(), success: false);
      return false;
    }
    return true;
  }

  Future<void> _upload({
    required DriverDocumentType type,
    required String filePath,
    required String fileName,
  }) async {
    if (!mounted) return;

    final viewModel = ref.read(driverDocumentsViewModelProvider);
    final ownerId = ref.read(authSessionProvider).asData?.value?.user.id;
    if (ownerId == null || ownerId.isEmpty) return;
    if (viewModel.uploading != null) {
      _showUploadMessage('document_upload_in_progress'.tr(), success: false);
      return;
    }
    final success = await viewModel.upload(
      ownerId: ownerId,
      type: type,
      filePath: filePath,
      fileName: fileName,
    );
    if (!mounted) return;
    _showUploadMessage(
      success
          ? '${_documentTypeLabel(type)} ${'uploaded_for_review'.tr()}'
          : (viewModel.errorMessage ?? 'could_not_upload_document').tr(),
      success: success,
    );
  }

  void _showUploadMessage(String message, {required bool success}) {
    if (success) {
      RidonsNotice.success(context, message);
    } else {
      RidonsNotice.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(driverDocumentsViewModelProvider);
    final session = ref.watch(authSessionProvider).asData?.value;
    final verificationStatus = session?.user.verificationStatus;
    return AccountSubpage(
      title:
          widget.onboarding && verificationStatus == VerificationStatus.rejected
          ? 'update_documents'
          : widget.onboarding
          ? 'verify_driver_account'
          : 'driver_documents',
      showBack: !widget.onboarding,
      child: RefreshIndicator(
        color: RidonsColors.primary,
        onRefresh: () => _loadDocuments(showError: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'upload_documents_description'.tr(),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _DocumentsLoadingState(),
              ),
            for (final type in DriverDocumentType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentTile(
                  type: type,
                  document: viewModel.documentFor(type),
                  pendingUpload: viewModel.hasPendingUpload(type),
                  uploading: viewModel.uploading == type,
                  uploadProgress: viewModel.uploadProgress,
                  onUpload: () => _pick(type),
                ),
              ),
            if (widget.onboarding) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: viewModel.loading
                    ? null
                    : () => _refreshVerificationStatus(reloadDocuments: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('check_verification_status'.tr()),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text('continue_to_app'.tr()),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  await ref.read(authSessionProvider.notifier).clear();
                  if (context.mounted) context.go(AppRoutes.onboarding);
                },
                child: Text('sign_out'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DocumentPickChoice { camera, gallery, pdf }

String _documentTypeLabel(DriverDocumentType type) {
  return switch (type) {
    DriverDocumentType.nationalId => 'national_id'.tr(),
    DriverDocumentType.drivingLicense => 'driving_license'.tr(),
    DriverDocumentType.vehicleRegistration => 'vehicle_registration'.tr(),
    DriverDocumentType.motorcycleAuthorisation =>
      'motorcycle_authorisation'.tr(),
    DriverDocumentType.insurance => 'insurance'.tr(),
    DriverDocumentType.selfie => 'selfie'.tr(),
  };
}

String _documentPurposeLabel(DriverDocumentType type) {
  return switch (type) {
    DriverDocumentType.nationalId => 'national_id_help'.tr(),
    DriverDocumentType.drivingLicense => 'driving_license_help'.tr(),
    DriverDocumentType.vehicleRegistration => 'vehicle_registration_help'.tr(),
    DriverDocumentType.motorcycleAuthorisation =>
      'motorcycle_authorisation_help'.tr(),
    DriverDocumentType.insurance => 'insurance_help'.tr(),
    DriverDocumentType.selfie => 'selfie_help'.tr(),
  };
}

String _documentStatusLabel(DriverDocumentStatus? status, String? reason) {
  final label = (status?.name ?? 'pending').tr();
  final cleanReason = reason?.trim() ?? '';
  return cleanReason.isEmpty ? label : '$label · ${cleanReason.tr()}';
}

enum _DocumentVisualState { missing, rejected, queued, uploaded, approved }

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
    final uploaded = viewModel.allRequiredUploaded;
    final rejected = status == VerificationStatus.rejected;
    final title = rejected
        ? 'documents_need_changes'
        : complete
        ? 'documents_ready_review'
        : uploaded
        ? 'documents_uploaded_waiting'
        : 'upload_required_documents';
    final detail = rejected && (reason ?? '').trim().isNotEmpty
        ? reason!.trim()
        : 'documents_manual_review';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ready = complete && !rejected;
    final accent = ready
        ? RidonsColors.success
        : (dark ? RidonsColors.primaryLight : RidonsColors.primary);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ready
            ? RidonsColors.success.withValues(alpha: .1)
            : dark
            ? RidonsColors.primary.withValues(alpha: .18)
            : RidonsColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ready
              ? RidonsColors.success.withValues(alpha: .35)
              : dark
              ? RidonsColors.primaryLight.withValues(alpha: .65)
              : RidonsColors.primaryLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready
                  ? Icons.verified_outlined
                  : Icons.shield_outlined,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${title.tr()}\n${detail.tr()}',
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

class _DocumentsLoadingState extends StatelessWidget {
  const _DocumentsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.ridonsDark
                ? RidonsColors.primaryLight
                : RidonsColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'documents_loading'.tr(),
          style: TextStyle(color: context.ridonsMuted),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.document,
    required this.pendingUpload,
    required this.uploading,
    required this.uploadProgress,
    required this.onUpload,
  });

  final DriverDocumentType type;
  final DriverDocument? document;
  final bool pendingUpload;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final status = document?.status;
    final visualState = pendingUpload
        ? _DocumentVisualState.queued
        : document == null
        ? _DocumentVisualState.missing
        : switch (status) {
            DriverDocumentStatus.approved => _DocumentVisualState.approved,
            DriverDocumentStatus.rejected => _DocumentVisualState.rejected,
            _ => _DocumentVisualState.uploaded,
          };
    final isGreen = visualState == _DocumentVisualState.uploaded ||
        visualState == _DocumentVisualState.approved;
    final isRed = visualState == _DocumentVisualState.missing ||
        visualState == _DocumentVisualState.rejected ||
        visualState == _DocumentVisualState.queued;
    final statusColor = isGreen
        ? RidonsColors.success
        : isRed
        ? (context.ridonsDark
              ? RidonsColors.primaryLight
              : RidonsColors.primary)
        : context.ridonsMuted;
    final backgroundColor = isGreen
        ? RidonsColors.success.withValues(
            alpha: context.ridonsDark ? .14 : .07,
          )
        : isRed
        ? (context.ridonsDark
              ? RidonsColors.primary.withValues(alpha: .14)
              : RidonsColors.primarySoft)
        : Colors.transparent;
    final icon = switch (visualState) {
      _DocumentVisualState.missing => Icons.error_outline_rounded,
      _DocumentVisualState.rejected => Icons.error_rounded,
      _DocumentVisualState.queued => Icons.cloud_upload_outlined,
      _DocumentVisualState.uploaded => Icons.check_circle_outline_rounded,
      _DocumentVisualState.approved => Icons.verified_rounded,
    };
    final detail = switch (visualState) {
      _DocumentVisualState.missing => 'required_not_uploaded'.tr(),
      _DocumentVisualState.rejected =>
        _documentStatusLabel(status, document?.rejectReason),
      _DocumentVisualState.queued => uploading
          ? 'document_uploading'.tr()
          : 'document_upload_waiting'.tr(),
      _DocumentVisualState.uploaded => 'document_uploaded'.tr(),
      _DocumentVisualState.approved => _documentStatusLabel(status, null),
    };
    final expiry = document?.expiresAt;
    final expiryLabel = expiry == null
        ? null
        : '${'expires_on'.tr()}: ${expiry.toLocal().toIso8601String().split('T').first}';
    final motionDuration = MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return AnimatedContainer(
      duration: motionDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGreen || isRed
              ? statusColor.withValues(alpha: .45)
              : context.ridonsLine,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: AnimatedSwitcher(
            duration: motionDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Icon(
              icon,
              key: ValueKey(visualState),
              color: statusColor,
            ),
          ),
          title: Text(
            _documentTypeLabel(type),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            expiryLabel == null ? detail : '$detail\n$expiryLabel',
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
          trailing: uploading
              ? SizedBox(
                  width: 86,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LinearProgressIndicator(
                        value: uploadProgress > 0 ? uploadProgress : null,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(5),
                        color: context.ridonsDark
                            ? RidonsColors.primaryLight
                            : RidonsColors.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uploadProgress > 0
                            ? '${(uploadProgress * 100).round()}%'
                            : 'document_uploading'.tr(),
                        style: TextStyle(
                          color: context.ridonsMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : IconButton(
                  tooltip: document == null
                      ? 'upload'.tr()
                      : 'replace_document'.tr(),
                  onPressed: onUpload,
                  icon: Icon(
                    document == null
                        ? Icons.file_upload_outlined
                        : Icons.refresh_rounded,
                  ),
                ),
        ),
      ),
    );
  }
}
