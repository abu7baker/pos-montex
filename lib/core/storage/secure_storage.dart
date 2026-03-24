import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _apiBaseUrlKey = 'api_base_url';
  static const _oauthClientIdKey = 'oauth_client_id';
  static const _oauthClientSecretKey = 'oauth_client_secret';
  static const _savedUsernameKey = 'saved_username';
  static const _savedPasswordKey = 'saved_password';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveApiBaseUrl(String baseUrl) =>
      _storage.write(key: _apiBaseUrlKey, value: baseUrl);

  Future<String?> readApiBaseUrl() => _storage.read(key: _apiBaseUrlKey);

  Future<void> saveOauthClient({
    required String clientId,
    required String clientSecret,
  }) async {
    await _storage.write(key: _oauthClientIdKey, value: clientId);
    await _storage.write(key: _oauthClientSecretKey, value: clientSecret);
  }

  Future<String?> readOauthClientId() => _storage.read(key: _oauthClientIdKey);

  Future<String?> readOauthClientSecret() =>
      _storage.read(key: _oauthClientSecretKey);

  Future<void> saveLoginCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _savedUsernameKey, value: username);
    await _storage.write(key: _savedPasswordKey, value: password);
  }

  Future<String?> readSavedUsername() => _storage.read(key: _savedUsernameKey);

  Future<String?> readSavedPassword() => _storage.read(key: _savedPasswordKey);

  Future<void> clearSavedCredentials() async {
    await _storage.delete(key: _savedUsernameKey);
    await _storage.delete(key: _savedPasswordKey);
  }

  Future<void> clearToken() => clearSession();

  Future<void> clearSession({bool keepApiConfig = true}) async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    if (!keepApiConfig) {
      await _storage.delete(key: _apiBaseUrlKey);
      await _storage.delete(key: _oauthClientIdKey);
      await _storage.delete(key: _oauthClientSecretKey);
      await clearSavedCredentials();
    }
  }
}
