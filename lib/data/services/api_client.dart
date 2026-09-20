import 'package:dio/dio.dart';

import 'token_store.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this._tokenStore,
    Dio? dio,
  }) : _dio = dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 12),
               headers: const {'Content-Type': 'application/json'},
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.readAccess();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
            options.headers.remove('content-type');
          }
          handler.next(options);
        },
      ),
    );
  }

  final String baseUrl;
  final TokenStore _tokenStore;
  final Dio _dio;

  Dio get dio => _dio;
}
