import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Maps API failures to translation keys. Every string returned here will
/// have .tr() called on it by the caller — never return raw English.
String apiErrorMessage(DioException error, {required String fallback}) {
  final data = error.response?.data;
  final payload = errorPayload(data);
  final code = payload?['error']?.toString();
  final known = switch (code) {
    'invalid_phone_number' => 'valid_phone_number',
    'country_not_allowed' => 'country_not_allowed',
    'otp_service_unavailable' => 'otp_service_unavailable',
    'otp_mismatch' => 'otp_mismatch',
    'otp_expired' => 'otp_expired',
    'otp_not_found' => 'otp_not_found',
    'otp_locked' => 'otp_locked',
    'phone_taken' => phoneTakenKey(payload?['role']?.toString()),
    'user_not_found' => 'user_not_found',
    'legal_consent_required' => 'legal_consent_required',
    'invalid_google_token' => 'google_signin_failed',
    'google_signin_unavailable' => 'google_signin_unavailable',
    'google_account_already_linked' => 'google_account_link_conflict',
    'google_account_link_conflict' => 'google_account_link_conflict',
    _ => null,
  };
  if (known != null) return known;

  final unreachable =
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  if (kDebugMode) {
    if (unreachable) {
      final uri = error.requestOptions.uri;
      debugPrint(
        '[API] Cannot reach ${uri.host}:${uri.port} — '
        'emulator: use 10.0.2.2; USB phone: adb reverse tcp:8100 tcp:8100',
      );
    } else {
      final status = error.response?.statusCode;
      final service = _serviceName(error);
      debugPrint(
        '[API] $fallback [$service${status != null ? ' HTTP $status' : ''}]',
      );
    }
  }

  if (unreachable) {
    return 'no_internet_connection';
  }
  final status = error.response?.statusCode;
  if (status == 502 || status == 503 || status == 504) {
    return 'service_temporarily_unavailable';
  }
  return fallback;
}

String _serviceName(DioException error) {
  final status = error.response?.statusCode;
  final path = error.requestOptions.path;
  final downstream = _serviceForPath(path);
  final unreachable =
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
  if (unreachable) return 'gateway';
  if (status == 502 || status == 503 || status == 504) return downstream;
  return downstream;
}

String _serviceForPath(String path) {
  if (path.startsWith('/auth') || path == '/me' || path.startsWith('/me/')) {
    return 'identity';
  }
  if (path.startsWith('/driver/requests') ||
      path.startsWith('/driver/rides') ||
      path == '/driver/stats' ||
      path == '/driver/quests' ||
      path == '/driver/earnings' ||
      path == '/driver/ratings') {
    return 'trip';
  }
  if (path.startsWith('/location') || path == '/driver/online') {
    return 'location';
  }
  if (path.startsWith('/rides/request') || path.startsWith('/trips')) {
    return 'trip';
  }
  if (path.startsWith('/places')) return 'places';
  if (path.startsWith('/rides/estimate') || path.startsWith('/zones')) {
    return 'pricing';
  }
  if (path.startsWith('/payments') || path.startsWith('/payouts')) {
    return 'payment';
  }
  if (path.startsWith('/devices') || path.startsWith('/internal/push')) {
    return 'notification';
  }
  if (path.startsWith('/eta')) return 'eta';
  return 'gateway';
}

const _genericHttpErrors = {
  'Bad Request',
  'Unauthorized',
  'Forbidden',
  'Not Found',
  'Conflict',
  'Internal Server Error',
};

/// Returns a translation key for a phone-already-taken error.
String phoneTakenKey(String? role) {
  return switch (role) {
    'driver' => 'phone_taken_driver',
    'passenger' => 'phone_taken_passenger',
    _ => 'phone_taken',
  };
}

String? errorCodeOf(DioException error) =>
    errorPayload(error.response?.data)?['error']?.toString();

Map<String, dynamic>? errorPayload(dynamic data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final direct = map['error'];
  if (direct is String && !_genericHttpErrors.contains(direct)) {
    return map;
  }
  final message = map['message'];
  if (message is Map) {
    return Map<String, dynamic>.from(message);
  }
  return null;
}
