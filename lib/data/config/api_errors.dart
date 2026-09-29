import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Maps API failures to copy. Debug builds name the service; release stays
/// user-facing.
String apiErrorMessage(
  DioException error, {
  required String fallback,
}) {
  final data = error.response?.data;
  final payload = errorPayload(data);
  final code = payload?['error']?.toString();
  final known = switch (code) {
    'otp_mismatch' => 'That code is incorrect.',
    'otp_expired' => 'That code expired. Request a new one.',
    'otp_not_found' => 'Request a new code first.',
    'otp_locked' => 'Too many attempts. Try again later.',
    'phone_taken' => phoneTakenMessage(payload?['role']?.toString()),
    _ => null,
  };
  if (known != null) return known;

  final service = _serviceName(error);
  final unreachable = error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  if (kDebugMode) {
    if (unreachable) {
      final uri = error.requestOptions.uri;
      return 'Cannot reach gateway at ${uri.host}:${uri.port}. '
          'Emulator uses 10.0.2.2; USB phone: adb reverse tcp:8100 tcp:8100';
    }
    final status = error.response?.statusCode;
    return status == null
        ? '$fallback [$service]'
        : '$fallback [$service HTTP $status]';
  }

  if (unreachable) {
    return 'We couldn\'t connect. Check your internet and try again.';
  }
  final status = error.response?.statusCode;
  if (status == 502 || status == 503 || status == 504) {
    return 'Ridons is temporarily unavailable. Please try again shortly.';
  }
  return fallback;
}

String _serviceName(DioException error) {
  final status = error.response?.statusCode;
  final path = error.requestOptions.path;
  final downstream = _serviceForPath(path);
  final unreachable = error.type == DioExceptionType.connectionError ||
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

String phoneTakenMessage(String? role) {
  return switch (role) {
    'driver' =>
      'This number already has a driver account. Sign in instead.',
    'passenger' =>
      'This number already has a passenger account. Sign in instead.',
    _ => 'This number is already registered. Sign in instead.',
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
