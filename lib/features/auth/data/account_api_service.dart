import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/dio_provider.dart';

final accountApiServiceProvider = Provider<AccountApiService>((ref) {
  return AccountApiService(ref.watch(dioProvider));
});

class AccountApiService {
  AccountApiService(this._dio);

  final Dio _dio;

  /// تحديث كلمة المرور حسب الدوكيومنت:
  /// POST /api/update-password
  /// body: current_password, new_password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<dynamic>(
      AppConfig.updatePasswordPath,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );

    final payload = response.data;
    if (payload is Map) {
      final success = payload['success'];
      final msg = payload['msg']?.toString().trim();
      final ok = success == 1 || success == true || success?.toString() == '1';
      if (!ok) {
        throw Exception(msg?.isNotEmpty == true ? msg : 'تعذر تحديث كلمة المرور');
      }
      return;
    }
  }
}

