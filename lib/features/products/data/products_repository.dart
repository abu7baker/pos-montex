import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product_entity.dart';
import 'products_local_datasource.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final local = ref.watch(productsLocalDataSourceProvider);
  return ProductsRepository(local);
});

class ProductsRepository {
  ProductsRepository(this._local);

  final ProductsLocalDataSource _local;

  Stream<List<Product>> watchProducts() => _local.watchProducts();

  Future<bool> hasProducts() => _local.hasProducts();

  Future<void> upsertProducts(List<Product> list) => _local.upsertProducts(list);

  Future<void> clearProducts() => _local.clearProducts();
}
