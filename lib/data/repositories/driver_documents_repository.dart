import 'package:dio/dio.dart';

import '../../domain/models/driver_document.dart';
import '../config/api_errors.dart';
import '../services/driver_documents_service.dart';

class DriverDocumentsSnapshot {
  const DriverDocumentsSnapshot({
    required this.documents,
    required this.canApprove,
  });

  final List<DriverDocument> documents;
  final bool canApprove;
}

class DriverDocumentsRepository {
  DriverDocumentsRepository(this._service);

  final DriverDocumentsService _service;

  Future<DriverDocumentsSnapshot> list() async {
    try {
      final json = await _service.list();
      final raw = json['documents'];
      final documents = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => DriverDocument.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <DriverDocument>[];
      return DriverDocumentsSnapshot(
        documents: documents,
        canApprove: json['canApprove'] == true,
      );
    } on DioException catch (error) {
      throw StateError(
        apiErrorMessage(error, fallback: 'Could not load your documents.'),
      );
    }
  }

  Future<DriverDocument?> upload({
    required DriverDocumentType type,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final json = await _service.upload(
        type: type.apiValue,
        filePath: filePath,
        fileName: fileName,
      );
      final document = json['document'];
      if (document is! Map) return null;
      return DriverDocument.fromJson(Map<String, dynamic>.from(document));
    } on DioException catch (error) {
      throw StateError(
        apiErrorMessage(error, fallback: 'Could not upload this document.'),
      );
    }
  }
}
