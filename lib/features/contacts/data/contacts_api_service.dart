import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/dio_provider.dart';

final contactsApiServiceProvider = Provider<ContactsApiService>((ref) {
  return ContactsApiService(ref.watch(dioProvider));
});

class ContactsApiService {
  ContactsApiService(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final response = await _dio.get<dynamic>(AppConfig.connectorContactsPath);
    final payload = response.data;
    final items = _extractItems(payload);
    return [
      for (final item in items)
        if (item is Map) item.cast<String, dynamic>(),
    ];
  }

  Future<Map<String, dynamic>?> fetchContactById(int id) async {
    final response = await _dio.get<dynamic>(
      '${AppConfig.connectorContactsPath}/$id',
    );
    final payload = response.data;

    if (payload is Map) {
      final data = payload['data'];
      if (data is Map) return data.cast<String, dynamic>();
    }

    if (payload is Map) return payload.cast<String, dynamic>();
    return null;
  }

  List<dynamic> _extractItems(dynamic payload) {
    if (payload is List) return payload;
    if (payload is! Map) return const <dynamic>[];

    final data = payload['data'];
    if (data is List) return data;
    if (data is Map) return [data];

    final result = payload['result'];
    if (result is List) return result;
    if (result is Map) return [result];

    return const <dynamic>[];
  }
}

