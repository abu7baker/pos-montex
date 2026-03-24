import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_api_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(secureStorageProvider),
    ref.read(appDbProvider),
    ref.read(dioProvider),
    ref.read(authApiServiceProvider),
  );
});

class SignInResult {
  const SignInResult({
    required this.productsSynced,
    required this.userName,
    this.usedOfflineCache = false,
    this.syncStartedInBackground = false,
  });

  final int productsSynced;
  final String? userName;
  final bool usedOfflineCache;
  final bool syncStartedInBackground;
}

class SavedLoginCredentials {
  const SavedLoginCredentials({this.username, this.password});

  final String? username;
  final String? password;
}

class AuthConnectionConfig {
  const AuthConnectionConfig({
    required this.baseUrl,
    required this.clientId,
    required this.clientSecret,
  });

  final String baseUrl;
  final String clientId;
  final String clientSecret;
}

class AuthRepository {
  AuthRepository(this._storage, this._db, this._dio, this._authApiService);

  final SecureStorage _storage;
  final AppDb _db;
  final Dio _dio;
  final AuthApiService _authApiService;

  Future<String?> readToken() => _storage.readToken();

  Future<void> saveToken(String token) => _storage.saveToken(token);

  Future<void> clearToken() => _storage.clearSession();

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  Future<SavedLoginCredentials> readSavedLogin() async {
    return SavedLoginCredentials(
      username: await _storage.readSavedUsername(),
      password: await _storage.readSavedPassword(),
    );
  }

  Future<AuthConnectionConfig> readConnectionConfig() async {
    final storedBaseUrl = (await _storage.readApiBaseUrl())?.trim();
    final storedClientId = (await _storage.readOauthClientId())?.trim() ?? '';
    final storedClientSecret =
        (await _storage.readOauthClientSecret())?.trim() ?? '';

    return AuthConnectionConfig(
      baseUrl: _normalizeBaseUrl(storedBaseUrl ?? AppConfig.defaultBaseUrl),
      clientId: storedClientId,
      clientSecret: storedClientSecret,
    );
  }

  Future<void> saveConnectionConfig({
    required String baseUrl,
    required String clientId,
    required String clientSecret,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    await _storage.saveApiBaseUrl(normalizedBaseUrl);
    await _storage.saveOauthClient(
      clientId: clientId.trim(),
      clientSecret: clientSecret.trim(),
    );
    await _db.setSetting('api_base_url', normalizedBaseUrl);
  }

  Future<bool> canResumeSavedSession() async {
    final hasProducts = await _hasCachedProducts();
    if (!hasProducts) return false;

    final token = await _storage.readToken();
    if (token != null && token.trim().isNotEmpty) {
      return true;
    }

    final saved = await readSavedLogin();
    return (saved.username?.trim().isNotEmpty ?? false) &&
        (saved.password?.isNotEmpty ?? false);
  }

  Future<void> warmUpSavedSession() async {
    final saved = await readSavedLogin();
    final currentUsername = await _db.getApiMeta('current_username');
    if ((currentUsername?.trim().isEmpty ?? true) &&
        (saved.username?.trim().isNotEmpty ?? false)) {
      await _db.setApiMeta('current_username', saved.username!.trim());
    }
  }

  Future<SignInResult> signIn({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final connectionConfig = await readConnectionConfig();
    final normalizedBaseUrl = connectionConfig.baseUrl;
    final clientId = connectionConfig.clientId.trim();
    final clientSecret = connectionConfig.clientSecret.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw Exception(
        'أدخل Passport Client ID و Client Secret في إعدادات الاتصال قبل تسجيل الدخول',
      );
    }

    if (!await _hasUsableNetwork()) {
      return _signInOffline(username: normalizedUsername, password: password);
    }

    try {
      final tokens = await _authApiService.loginWithPassport(
        baseUrl: normalizedBaseUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        username: normalizedUsername,
        password: password,
      );

      await _storage.saveToken(tokens.accessToken);
      if (tokens.refreshToken.trim().isNotEmpty) {
        await _storage.saveRefreshToken(tokens.refreshToken);
      }
      await _storage.saveLoginCredentials(
        username: normalizedUsername,
        password: password,
      );

      final user = await _fetchCurrentUser(username: normalizedUsername);
      await _persistUserMeta(user, username: normalizedUsername);

      return SignInResult(
        productsSynced: 0,
        userName:
            _readString(user?['first_name']) ??
            _readString(user?['username']) ??
            normalizedUsername,
      );
    } catch (error) {
      if (_isInvalidCredentialsError(error)) {
        await _storage.clearSession();
      } else if (await _canUseOfflineSession(
        username: normalizedUsername,
        password: password,
      )) {
        return _signInOffline(username: normalizedUsername, password: password);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }

  Future<Map<dynamic, dynamic>?> _fetchCurrentUser({
    required String username,
  }) async {
    final response = await _dio.get<dynamic>(AppConfig.connectorUserPath);
    final payload = response.data;
    if (payload is Map) {
      final data = payload['data'];
      if (data is List && data.isNotEmpty) {
        final normalizedUsername = username.trim().toLowerCase();
        for (final item in data) {
          if (item is! Map) continue;
          final row = item.cast<dynamic, dynamic>();
          final rowUsername = (_readString(row['username']) ?? '')
              .trim()
              .toLowerCase();
          if (rowUsername == normalizedUsername) {
            return row;
          }
        }
        if (data.first is Map) {
          return (data.first as Map).cast<dynamic, dynamic>();
        }
      }
      if (data is Map) {
        return data.cast<dynamic, dynamic>();
      }
    }
    return null;
  }

  Future<void> _persistUserMeta(
    Map<dynamic, dynamic>? user, {
    required String username,
  }) async {
    if (user == null) {
      await _db.setApiMeta('current_username', username);
      return;
    }

    await _db.setApiMeta(
      'current_user_server_id',
      _readString(user['id']) ?? '',
    );
    await _db.setApiMeta(
      'current_business_id',
      _readString(user['business_id']) ?? '',
    );
    await _db.setApiMeta(
      'current_username',
      _readString(user['username']) ?? username,
    );
    await _db.setApiMeta(
      'current_user_name',
      _readString(user['first_name']) ??
          _readString(user['username']) ??
          username,
    );
  }

  Future<SignInResult> _signInOffline({
    required String username,
    required String password,
  }) async {
    final saved = await readSavedLogin();
    final savedUsername = (saved.username ?? '').trim();
    final savedPassword = saved.password ?? '';

    if (savedUsername.isEmpty || savedPassword.isEmpty) {
      throw Exception(
        'لا يوجد حساب محفوظ محلياً لهذا الجهاز. يلزم تسجيل دخول ناجح مرة واحدة مع الإنترنت.',
      );
    }

    if (savedUsername != username.trim() || savedPassword != password) {
      throw Exception(
        'بيانات الدخول المحلية لا تطابق المدخلات. استخدم آخر حساب تم تسجيله على هذا الجهاز.',
      );
    }

    if (!await _hasCachedProducts()) {
      throw Exception(
        'لا توجد منتجات محفوظة محلياً بعد. يلزم مزامنة ناجحة مرة واحدة مع الإنترنت.',
      );
    }

    final savedName = await _db.getApiMeta('current_user_name');
    await _db.setApiMeta('current_username', savedUsername);

    return SignInResult(
      productsSynced: 0,
      userName: _readString(savedName) ?? savedUsername,
      usedOfflineCache: true,
    );
  }

  Future<bool> _canUseOfflineSession({
    required String username,
    required String password,
  }) async {
    final saved = await readSavedLogin();
    final savedUsername = (saved.username ?? '').trim();
    final savedPassword = saved.password ?? '';

    if (savedUsername.isEmpty || savedPassword.isEmpty) {
      return false;
    }
    if (savedUsername != username.trim() || savedPassword != password) {
      return false;
    }
    return _hasCachedProducts();
  }

  Future<bool> _hasCachedProducts() async {
    final row = await (_db.select(_db.products)..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<bool> _hasUsableNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.any((item) => item != ConnectivityResult.none)) {
        return false;
      }
      return _canReachConfiguredApiHost();
    } catch (_) {
      return true;
    }
  }

  Future<bool> _canReachConfiguredApiHost() async {
    try {
      final storedBaseUrl = await _storage.readApiBaseUrl();
      final configuredBaseUrl = (storedBaseUrl?.trim().isNotEmpty ?? false)
          ? storedBaseUrl!.trim()
          : AppConfig.defaultBaseUrl;
      final uri = Uri.tryParse(_normalizeBaseUrl(configuredBaseUrl));
      final host = uri?.host.trim() ?? '';
      if (host.isEmpty) return false;

      final isHttps = (uri?.scheme.toLowerCase() ?? 'https') == 'https';
      final port = uri?.hasPort == true ? uri!.port : (isHttps ? 443 : 80);
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isInvalidCredentialsError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode ?? 0;
      return statusCode == 400 || statusCode == 401;
    }

    final message = error.toString().toLowerCase();
    return message.contains('غير صحيحة') ||
        message.contains('اسم المستخدم') && message.contains('كلمة المرور');
  }

  String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      normalized = AppConfig.defaultBaseUrl;
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

String? _readString(dynamic value) {
  if (value == null) return null;
  if (value is SocketException) return value.message.trim();
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
