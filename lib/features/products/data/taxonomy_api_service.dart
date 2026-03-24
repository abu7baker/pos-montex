import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/dio_provider.dart';

final taxonomyApiServiceProvider = Provider<TaxonomyApiService>((ref) {
  return TaxonomyApiService(ref.watch(dioProvider));
});

class TaxonomyApiService {
  TaxonomyApiService(this._dio);

  final Dio _dio;

  /// endpoint حسب الدوكيومنت: GET /connector/api/taxonomy/...
  /// الدوكيومنت لا يوضح المسار الفرعي، لذلك نوفّر استدعاء عام
  /// يمكن تمرير `pathSuffix` مثل: `/product` أو `/categories` عند الحاجة.
  Future<dynamic> fetchTaxonomy({String pathSuffix = ''}) async {
    final suffix = pathSuffix.trim();
    final path = suffix.isEmpty
        ? AppConfig.connectorTaxonomyPath
        : '${AppConfig.connectorTaxonomyPath}/${_trimSlashes(suffix)}';
    final response = await _dio.get<dynamic>(path);
    return response.data;
  }
}

String _trimSlashes(String value) {
  var v = value.trim();
  while (v.startsWith('/')) v = v.substring(1);
  while (v.endsWith('/')) v = v.substring(0, v.length - 1);
  return v;
}

