import 'package:flutter/foundation.dart';

import '../../../../data/repositories/driver_documents_repository.dart';
import '../../../../domain/models/driver_document.dart';

class DriverDocumentsViewModel extends ChangeNotifier {
  DriverDocumentsViewModel(this._repository);

  final DriverDocumentsRepository _repository;

  List<DriverDocument> documents = const [];
  bool canApprove = false;
  bool loading = false;
  DriverDocumentType? uploading;
  String? errorMessage;

  DriverDocument? documentFor(DriverDocumentType type) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _repository.list();
      documents = snapshot.documents;
      canApprove = snapshot.canApprove;
    } catch (error) {
      errorMessage = _message(error, 'could_not_load_documents');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> upload({
    required DriverDocumentType type,
    required String filePath,
    required String fileName,
  }) async {
    uploading = type;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.upload(
        type: type,
        filePath: filePath,
        fileName: fileName,
      );
      await load();
      return true;
    } catch (error) {
      errorMessage = _message(error, 'could_not_upload_document');
      return false;
    } finally {
      uploading = null;
      notifyListeners();
    }
  }

  String _message(Object error, String fallback) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty ? fallback : message;
  }
}
