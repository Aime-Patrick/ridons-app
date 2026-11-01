import 'package:flutter/foundation.dart';

import '../../../../data/repositories/driver_documents_repository.dart';
import '../../../../data/services/pending_driver_document_store.dart';
import '../../../../domain/models/driver_document.dart';

class DriverDocumentsViewModel extends ChangeNotifier {
  DriverDocumentsViewModel(this._repository);

  final DriverDocumentsRepository _repository;
  final PendingDriverDocumentStore _pendingStore =
      PendingDriverDocumentStore();

  List<DriverDocument> documents = const [];
  bool canApprove = false;
  Set<DriverDocumentType> requiredTypes = <DriverDocumentType>{};
  bool loading = false;
  DriverDocumentType? uploading;
  double uploadProgress = 0;
  Set<DriverDocumentType> pendingUploadTypes = <DriverDocumentType>{};
  String? errorMessage;

  bool hasPendingUpload(DriverDocumentType type) =>
      pendingUploadTypes.contains(type);

  bool get allRequiredUploaded {
    final required = requiredTypes.isEmpty
        ? DriverDocumentType.values.toSet()
        : requiredTypes;
    return required.every((type) => documentFor(type) != null);
  }

  DriverDocument? documentFor(DriverDocumentType type) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _repository.list();
      documents = snapshot.documents;
      canApprove = snapshot.canApprove;
      requiredTypes = snapshot.requiredTypes;
    } catch (error) {
      errorMessage = _message(error, 'could_not_load_documents');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> upload({
    required String ownerId,
    required DriverDocumentType type,
    required String filePath,
    required String fileName,
    DateTime? expiresAt,
  }) async {
    if (uploading != null) {
      errorMessage = 'document_upload_in_progress';
      notifyListeners();
      return false;
    }
    try {
      final pending = await _pendingStore.add(
        ownerId: ownerId,
        type: type,
        sourcePath: filePath,
        fileName: fileName,
        expiresAt: expiresAt,
      );
      pendingUploadTypes = {...pendingUploadTypes, type};
      errorMessage = null;
      notifyListeners();
      return await _attemptUpload(pending);
    } catch (error) {
      errorMessage = _message(error, 'could_not_upload_document');
      notifyListeners();
      return false;
    }
  }

  Future<void> resumePendingUploads({required String ownerId}) async {
    if (uploading != null) return;
    final pending = await _pendingStore.list(ownerId: ownerId);
    pendingUploadTypes = pending.map((item) => item.type).toSet();
    notifyListeners();
    for (final item in pending) {
      if (uploading != null) return;
      await _attemptUpload(item);
    }
  }

  Future<bool> retryPendingUploads({required String ownerId}) async {
    if (uploading != null) return false;
    final pending = await _pendingStore.list(ownerId: ownerId);
    pendingUploadTypes = pending.map((item) => item.type).toSet();
    notifyListeners();
    var completed = false;
    for (final item in pending) {
      completed = await _attemptUpload(item) || completed;
    }
    return completed;
  }

  Future<bool> _attemptUpload(PendingDriverDocumentUpload pending) async {
    uploading = pending.type;
    uploadProgress = 0;
    errorMessage = null;
    notifyListeners();
    Object? lastError;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _repository.upload(
            type: pending.type,
            filePath: pending.filePath,
            fileName: pending.fileName,
            expiresAt: pending.expiresAt,
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              uploadProgress = (sent / total).clamp(0.0, 1.0).toDouble();
              notifyListeners();
            },
          );
          uploadProgress = 1;
          await _pendingStore.remove(pending);
          pendingUploadTypes = {...pendingUploadTypes}
            ..remove(pending.type);
          await load();
          return true;
        } catch (error) {
          lastError = error;
          final retryable = error is DriverDocumentUploadException &&
              error.retryable;
          if (!retryable || attempt == 2) break;
          await Future<void>.delayed(
            Duration(seconds: attempt == 0 ? 2 : 5),
          );
        }
      }
      errorMessage = _message(lastError, 'could_not_upload_document');
      return false;
    } finally {
      uploading = null;
      uploadProgress = 0;
      notifyListeners();
    }
  }

  String _message(Object? error, String fallback) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty || message == 'null' ? fallback : message;
  }
}
