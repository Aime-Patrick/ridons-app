import 'package:dio/dio.dart';

import '../../domain/models/driver_document.dart';
import '../config/api_errors.dart';
import '../services/driver_documents_service.dart';

class DriverDocumentsSnapshot {
  const DriverDocumentsSnapshot({
    required this.documents,
    required this.canApprove,
    required this.requiredTypes,
  });

  final List<DriverDocument> documents;
  final bool canApprove;
  final Set<DriverDocumentType> requiredTypes;
}

class DriverDocumentUploadException implements Exception {
  const DriverDocumentUploadException({
    required this.message,
    required this.retryable,
  });

  final String message;
  final bool retryable;

  @override
  String toString() => message;
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
      final requiredRaw = json['requiredDocuments'];
      final requiredTypes = requiredRaw is List
          ? requiredRaw
                .map((item) => item is Map ? item['type'] : item)
                .map((item) => '$item')
                .map(
                  (value) => DriverDocumentType.values.firstWhere(
                    (type) => type.apiValue == value,
                    orElse: () => DriverDocumentType.nationalId,
                  ),
                )
                .toSet()
          : <DriverDocumentType>{};
      return DriverDocumentsSnapshot(
        documents: documents,
        canApprove: json['canApprove'] == true,
        requiredTypes: requiredTypes,
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
    DateTime? expiresAt,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final json = await _service.upload(
        type: type.apiValue,
      filePath: filePath,
      fileName: fileName,
      expiresAt: expiresAt,
      onSendProgress: onSendProgress,
      );
      final document = json['document'];
      if (document is! Map) return null;
      return DriverDocument.fromJson(Map<String, dynamic>.from(document));
    } on DioException catch (error) {
      final retryable = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          (error.response?.statusCode ?? 0) >= 500 ||
          error.response?.statusCode == 408 ||
          error.response?.statusCode == 429;
      throw DriverDocumentUploadException(
        message: apiErrorMessage(
          error,
          fallback: 'Could not upload this document.',
        ),
        retryable: retryable,
      );
    }
  }
}
