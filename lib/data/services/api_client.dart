import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'token_store.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this._tokenStore, Dio? dio})
    : _dio =
          dio ??
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
          try {
            if (options.extra['skipSessionRefresh'] != true &&
                options.extra['skipProactiveSessionRefresh'] != true &&
                !_isAuthEndpoint(options.path)) {
              await _refreshIfAccessExpiresSoon();
            }
          } catch (_) {
            // Continue with the current access token if a proactive refresh fails.
          }
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
        onError: (error, handler) async {
          final request = error.requestOptions;
          final canRetry =
              error.response?.statusCode == 401 &&
              request.extra['sessionRefreshRetried'] != true &&
              request.extra['skipSessionRefresh'] != true &&
              !_isAuthEndpoint(request.path);
          if (!canRetry) {
            handler.next(error);
            return;
          }

          request.extra['sessionRefreshRetried'] = true;
          final tokens = await refreshSessionTokens();
          final access = tokens?['token']?.toString();
          if (access == null || access.isEmpty) {
            handler.next(error);
            return;
          }
          // FormData streams are one-shot. Refresh the session, but let the
          // caller retry an upload explicitly rather than replaying its body.
          if (request.data is FormData) {
            handler.next(error);
            return;
          }

          request.headers['Authorization'] = 'Bearer $access';
          request.extra['skipProactiveSessionRefresh'] = true;
          try {
            handler.resolve(await _dio.fetch<dynamic>(request));
          } on DioException catch (retryError) {
            handler.next(retryError);
          } catch (retryError) {
            handler.next(
              DioException(requestOptions: request, error: retryError),
            );
          }
        },
      ),
    );
  }

  final String baseUrl;
  final TokenStore _tokenStore;
  final Dio _dio;
  Future<Map<String, dynamic>?>? _refreshInFlight;
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  bool _lastRefreshWasRejected = false;

  Dio get dio => _dio;
  Stream<void> get sessionExpired => _sessionExpiredController.stream;
  bool get lastRefreshWasRejected => _lastRefreshWasRejected;

  Future<void> dispose() => _sessionExpiredController.close();

  Future<Map<String, dynamic>?> refreshSessionTokens() {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _performSessionRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<Map<String, dynamic>?> _performSessionRefresh() async {
    _lastRefreshWasRejected = false;
    try {
      final refreshToken = await _tokenStore.readRefresh();
      if (refreshToken == null || refreshToken.isEmpty) {
        _lastRefreshWasRejected = true;
        return null;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {'skipSessionRefresh': true}),
      );
      final result = response.data;
      final access = result?['token']?.toString();
      final rotatedRefresh = result?['refreshToken']?.toString();
      if (access == null ||
          access.isEmpty ||
          rotatedRefresh == null ||
          rotatedRefresh.isEmpty) {
        return null;
      }
      await _tokenStore.save(access: access, refresh: rotatedRefresh);
      return result;
    } on DioException catch (error) {
      _lastRefreshWasRejected =
          error.response?.statusCode == 401 ||
          error.response?.statusCode == 403;
      if (_lastRefreshWasRejected) {
        _sessionExpiredController.add(null);
      }
      return null;
    } catch (_) {
      // Session restoration decides whether to clear tokens after auth failure.
      return null;
    }
  }

  Future<void> _refreshIfAccessExpiresSoon() async {
    final access = await _tokenStore.readAccess();
    if (access == null || access.isEmpty || !_expiresWithin(access, 90)) return;
    await refreshSessionTokens();
  }

  bool _expiresWithin(String token, int seconds) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiry = (payload as Map<String, dynamic>)['exp'];
      if (expiry is! num) return false;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiry <= now + seconds;
    } catch (_) {
      return false;
    }
  }

  bool _isAuthEndpoint(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/') ||
        normalized.startsWith('auth/') ||
        normalized == 'auth';
  }
}
