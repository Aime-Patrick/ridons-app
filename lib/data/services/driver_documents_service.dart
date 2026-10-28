import 'package:dio/dio.dart';

import 'api_client.dart';

class DriverDocumentsService {
  DriverDocumentsService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> list() async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/me/driver-documents',
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> upload({
    required String type,
    required String filePath,
    required String fileName,
    DateTime? expiresAt,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/me/driver-documents/$type',
      data: form,
    );
    return response.data ?? const {};
  }
}
