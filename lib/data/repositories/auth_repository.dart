import 'package:dio/dio.dart';

import '../../domain/models/app_role.dart';
import '../../domain/models/session_user.dart';
import '../config/api_errors.dart';
import '../services/api_client.dart';
import '../services/token_store.dart';

abstract class AuthRepository {
  Future<void> sendOtp({
    required String phone,
    String? intent,
    AppRole? role,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  });
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required AppRole role,
    String? intent,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  });
  Future<AuthSession> updateProfile({
    String? firstName,
    String? lastName,
    String? locale,
    String? avatarKey,
  });
  Future<AuthSession> switchMode(AppRole mode);
  Future<AuthSession> uploadAvatar(String filePath);
  Future<AuthSession?> restore();
  Future<AuthSession?> refreshSession();
  Future<void> logout();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _api = apiClient,
       _tokens = tokenStore;

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<void> sendOtp({
    required String phone,
    String? intent,
    AppRole? role,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  }) async {
    try {
      await _api.dio.post<Map<String, dynamic>>(
        '/auth/otp/send',
        data: {
          'phone': phone,
          if (intent != null) 'intent': intent,
          if (role != null) 'role': role.name,
          'termsAccepted': termsAccepted,
          'privacyAccepted': privacyAccepted,
          if (policyVersion != null) 'policyVersion': policyVersion,
          'consentSource': consentSource,
        },
      );
    } on DioException catch (e) {
      throw AuthException(
        apiErrorMessage(e, fallback: 'Could not send the code.'),
        code: errorCodeOf(e),
      );
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required AppRole role,
    String? intent,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {
          'phone': phone,
          'code': code,
          'role': role.name,
          if (intent != null) 'intent': intent,
          'termsAccepted': termsAccepted,
          'privacyAccepted': privacyAccepted,
          if (policyVersion != null) 'policyVersion': policyVersion,
          'consentSource': consentSource,
        },
      );
      return await _sessionFrom(response.data ?? const {});
    } on DioException catch (e) {
      throw AuthException(
        apiErrorMessage(e, fallback: 'Could not verify the code.'),
        code: errorCodeOf(e),
      );
    }
  }

  @override
  Future<AuthSession> updateProfile({
    String? firstName,
    String? lastName,
    String? locale,
    String? avatarKey,
  }) async {
    try {
      final response = await _api.dio.patch<Map<String, dynamic>>(
        '/me',
        data: {
          'firstName': ?firstName?.trim(),
          'lastName': ?lastName?.trim(),
          'locale': ?locale,
          'avatarKey': ?avatarKey,
        },
      );
      final token = await _tokens.readAccess();
      final userMap =
          (response.data?['user'] as Map<String, dynamic>?) ??
          response.data ??
          const {};
      return AuthSession(
        token: token ?? '',
        user: SessionUser.fromJson(userMap),
      );
    } on DioException catch (e) {
      throw AuthException(
        apiErrorMessage(e, fallback: 'Could not save your name.'),
      );
    }
  }

  @override
  Future<AuthSession> uploadAvatar(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
      });
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/me/avatar',
        data: form,
      );
      final token = await _tokens.readAccess();
      final userMap =
          (response.data?['user'] as Map<String, dynamic>?) ??
          response.data ??
          const {};
      return AuthSession(
        token: token ?? '',
        user: SessionUser.fromJson(userMap),
      );
    } on DioException catch (e) {
      throw AuthException(
        apiErrorMessage(e, fallback: 'Could not upload the photo.'),
      );
    }
  }

  @override
  Future<AuthSession> switchMode(AppRole mode) async {
    try {
      final response = await _api.dio.patch<Map<String, dynamic>>(
        '/auth/mode',
        data: {'mode': mode.name},
      );
      final json = response.data ?? const {};
      final token = '${json['token'] ?? ''}';
      if (token.isEmpty) {
        throw const AuthException('Could not switch account mode.');
      }
      await _tokens.saveAccess(token);
      final userMap = (json['user'] as Map<String, dynamic>?) ?? const {};
      return AuthSession(token: token, user: SessionUser.fromJson(userMap));
    } on DioException catch (e) {
      throw AuthException(
        apiErrorMessage(e, fallback: 'Could not switch account mode.'),
        code: errorCodeOf(e),
      );
    }
  }

  @override
  Future<AuthSession?> restore() async {
    final access = await _tokens.readAccess();
    if (access == null || access.isEmpty) return null;
    try {
      final response = await _api.dio.get<Map<String, dynamic>>('/me');
      final userMap =
          (response.data?['user'] as Map<String, dynamic>?) ?? const {};
      return AuthSession(token: access, user: SessionUser.fromJson(userMap));
    } on DioException catch (e) {
      // Only drop the session on auth failure — keep tokens on network/5xx.
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshSession();
        if (refreshed != null) return refreshed;
        await _tokens.clear();
      }
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    try {
      await _api.dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': refresh},
      );
    } catch (_) {}
    await _tokens.clear();
  }

  /// Re-issue a JWT with fresh claims from the DB (e.g. after verification
  /// status changes). Returns the updated session or null on failure.
  @override
  Future<AuthSession?> refreshSession() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final json = response.data ?? const {};
      final token = '${json['token'] ?? ''}';
      final newRefresh = json['refreshToken']?.toString();
      if (token.isEmpty) return null;
      await _tokens.save(access: token, refresh: newRefresh ?? refresh);
      final userMap = (json['user'] as Map<String, dynamic>?) ?? const {};
      return AuthSession(token: token, user: SessionUser.fromJson(userMap));
    } on DioException {
      return null;
    }
  }

  Future<AuthSession> _sessionFrom(Map<String, dynamic> json) async {
    final token = '${json['token'] ?? ''}';
    final refresh = '${json['refreshToken'] ?? ''}';
    if (token.isEmpty) {
      throw const AuthException('Missing access token.');
    }
    await _tokens.save(access: token, refresh: refresh);
    final userMap = (json['user'] as Map<String, dynamic>?) ?? const {};
    return AuthSession(token: token, user: SessionUser.fromJson(userMap));
  }
}
