import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _access = 'ridons.accessToken';
  static const _refresh = 'ridons.refreshToken';

  Future<String?> readAccess() => _storage.read(key: _access);
  Future<String?> readRefresh() => _storage.read(key: _refresh);

  Future<void> save({required String access, required String refresh}) async {
    // Persist the rotated refresh token first so an interruption cannot leave
    // the new access token paired with the already-replaced refresh token.
    await _storage.write(key: _refresh, value: refresh);
    await _storage.write(key: _access, value: access);
  }

  Future<void> saveAccess(String access) =>
      _storage.write(key: _access, value: access);

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}
