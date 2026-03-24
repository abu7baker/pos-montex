import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../domain/product_entity.dart';

final productsLocalDataSourceProvider = Provider<ProductsLocalDataSource>((
  ref,
) {
  final db = ref.watch(appDbProvider);
  return ProductsLocalDataSource(db);
});

class ProductsLocalDataSource {
  ProductsLocalDataSource(this._db);

  final AppDb _db;

  Stream<List<Product>> watchProducts() {
    final controller = StreamController<List<Product>>.broadcast();
    final query = _db.select(_db.products).join([
      leftOuterJoin(
        _db.productCategories,
        _db.productCategories.id.equalsExp(_db.products.categoryId) &
            _db.productCategories.isDeleted.equals(false) &
            _db.productCategories.isActive.equals(true),
      ),
      leftOuterJoin(
        _db.brands,
        _db.brands.id.equalsExp(_db.products.brandId) &
            _db.brands.isDeleted.equals(false) &
            _db.brands.isActive.equals(true),
      ),
    ]);
    query.where(
      _db.products.isDeleted.equals(false) & _db.products.isActive.equals(true),
    );
    List<TypedResult> latestRows = const [];
    String selectedBranchKey = '';
    Map<String, List<String>> branchKeysByProduct = const {};
    Map<String, Map<String, int>> branchStocksByProduct = const {};

    Future<void> emit() async {
      if (controller.isClosed) return;
      final filtered = latestRows
          .where((row) {
            if (selectedBranchKey.isEmpty) return true;
            final product = row.readTable(_db.products);
            final serverId = product.serverId;
            if (serverId == null) return true;
            final branchKeys = branchKeysByProduct['$serverId'];
            if (branchKeys == null || branchKeys.isEmpty) return true;
            return branchKeys.contains(selectedBranchKey);
          })
          .map((row) {
            final product = row.readTable(_db.products);
            final category = row.readTableOrNull(_db.productCategories);
            final brand = row.readTableOrNull(_db.brands);
            var stock = product.stock;
            if (selectedBranchKey.isNotEmpty && product.serverId != null) {
              final branchStocks = branchStocksByProduct['${product.serverId}'];
              if (branchStocks != null &&
                  branchStocks.containsKey(selectedBranchKey)) {
                stock = branchStocks[selectedBranchKey] ?? stock;
              }
            }
            return Product(
              id: product.id,
              name: product.name,
              description: product.description,
              price: product.price,
              stock: stock,
              categoryId: product.categoryId,
              categoryName: category?.name,
              brandId: product.brandId,
              brandName: brand?.name,
              imagePath: product.imagePath,
              imageData: product.imageData,
              updatedAt: product.updatedAt,
            );
          })
          .toList(growable: false);
      controller.add(filtered);
    }

    final productsSub = query.watch().listen((rows) {
      latestRows = rows;
      emit();
    });
    final branchSelectionSub = _db.watchSetting('branch_selection_key').listen((
      value,
    ) {
      selectedBranchKey = (value ?? '').trim();
      emit();
    });
    final branchKeysSub = _db.watchSetting('product_branch_keys_json').listen((
      value,
    ) {
      branchKeysByProduct = _decodeBranchKeysMap(value);
      emit();
    });
    final branchStocksSub = _db
        .watchSetting('product_branch_stock_json')
        .listen((value) {
          branchStocksByProduct = _decodeBranchStocksMap(value);
          emit();
        });

    controller.onCancel = () async {
      await productsSub.cancel();
      await branchSelectionSub.cancel();
      await branchKeysSub.cancel();
      await branchStocksSub.cancel();
    };

    return controller.stream;
  }

  Future<bool> hasProducts() async {
    final row = await (_db.select(_db.products)..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<void> upsertProducts(List<Product> list) async {
    final items = list
        .map(
          (e) => ProductsCompanion.insert(
            id: Value(e.id),
            name: e.name,
            description: Value(e.description),
            price: Value(e.price),
            stock: Value(e.stock),
            categoryId: Value(e.categoryId),
            brandId: Value(e.brandId),
            imagePath: Value(e.imagePath),
            imageData: Value<Uint8List?>(e.imageData),
            updatedAt: Value(e.updatedAt),
          ),
        )
        .toList();
    await _db.upsertProducts(items);
  }

  Future<void> clearProducts() => _db.clearProducts();
}

Map<String, List<String>> _decodeBranchKeysMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    final output = <String, List<String>>{};
    decoded.forEach((key, value) {
      if (value is! List) return;
      output[key.toString()] = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    });
    return output;
  } catch (_) {
    return const {};
  }
}

Map<String, Map<String, int>> _decodeBranchStocksMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    final output = <String, Map<String, int>>{};
    decoded.forEach((key, value) {
      if (value is! Map) return;
      final stockMap = <String, int>{};
      value.forEach((branchKey, qty) {
        final parsedQty = qty is int ? qty : int.tryParse('$qty');
        if (parsedQty == null) return;
        stockMap[branchKey.toString()] = parsedQty;
      });
      output[key.toString()] = stockMap;
    });
    return output;
  } catch (_) {
    return const {};
  }
}
