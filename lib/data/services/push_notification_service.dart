import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class PushNotificationService {
  PushNotificationService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  StreamSubscription<String>? _tokenSubscription;
  String? _userId;
  bool _firebaseReady = false;

  Future<void> registerForUser(String userId) async {
    if (userId.isEmpty || _userId == userId) return;
    try {
      await _ensureFirebase();
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      _userId = userId;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(userId, token);
      }
      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen((next) {
        if (next.isNotEmpty) unawaited(_registerToken(userId, next));
      });
    } catch (error) {
      debugPrint('push registration skipped: $error');
    }
  }

  Future<void> unregisterForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _ensureFirebase();
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.dio.delete<void>(
          '/devices/register',
          data: {'token': token},
        );
      }
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('push unregistration skipped: $error');
    } finally {
      _userId = null;
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
    }
  }

  Future<void> _registerToken(String userId, String token) async {
    await _api.dio.post<void>(
      '/devices/register',
      data: {'token': token, 'platform': _platform, 'appId': 'com.ridons.app'},
    );
  }

  Future<void> _ensureFirebase() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    _firebaseReady = true;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
