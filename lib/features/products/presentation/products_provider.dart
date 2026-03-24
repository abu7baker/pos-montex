import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../data/products_repository.dart';
import '../domain/product_entity.dart';

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productsRepositoryProvider).watchProducts();
});

final productCategoriesStreamProvider = StreamProvider<List<ProductCategoryDb>>(
  (ref) {
    final db = ref.watch(appDbProvider);
    return db.watchProductCategories();
  },
);

final productsActionsProvider =
    AutoDisposeAsyncNotifierProvider<ProductsActions, void>(
      ProductsActions.new,
    );

class ProductsActions extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> resetProductsWithDefaults() async {
    // Intentionally no-op: do not insert any demo products/categories.
    state = const AsyncData(null);
  }

  Future<void> clearProducts() async {
    state = const AsyncLoading();
    await ref.read(productsRepositoryProvider).clearProducts();
    state = const AsyncData(null);
  }
}
