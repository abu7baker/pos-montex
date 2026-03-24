import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';

final authApiServiceProvider = Provider<AuthApiService>(
  (ref) => const AuthApiService(),
);

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final String? tokenType;
}

class AuthApiService {
  const AuthApiService();

  Future<AuthTokens> loginWithPassport({
    required String baseUrl,
    required String clientId,
    required String clientSecret,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/json'},
      ),
    );

    try {
      final response = await dio.post<Map<String, dynamic>>(
        AppConfig.oauthTokenPath,
        data: {
          'grant_type': 'password',
          'client_id': clientId,
          'client_secret': clientSecret,
          'username': username,
          'password': password,
          'scope': '',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final body = response.data ?? const <String, dynamic>{};
      final accessToken = (body['access_token'] ?? '').toString().trim();
      if (accessToken.isEmpty) {
        throw Exception('لم يرجع الخادم access_token من Passport');
      }

      return AuthTokens(
        accessToken: accessToken,
        refreshToken: (body['refresh_token'] ?? '').toString(),
        tokenType: body['token_type']?.toString(),
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 400 || statusCode == 401) {
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      if (statusCode == 429) {
        final retryAfter = error.response?.headers.value('retry-after');
        if (retryAfter != null && retryAfter.trim().isNotEmpty) {
          throw Exception(
            'تم رفض الطلب مؤقتاً بسبب كثرة المحاولات. انتظر $retryAfter ثانية ثم حاول مرة أخرى أو استخدم الدخول المحلي.',
          );
        }
        throw Exception(
          'تم رفض الطلب مؤقتاً بسبب كثرة المحاولات من الخادم (429). يمكنك الانتظار قليلاً أو استخدام الدخول المحلي.',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw Exception(
          'تعذر الوصول إلى الخادم الآن. إذا سبق لك تسجيل الدخول على هذا الجهاز فاستعمل الدخول المحلي بدون إنترنت.',
        );
      }
      rethrow;
    }
  }
}
