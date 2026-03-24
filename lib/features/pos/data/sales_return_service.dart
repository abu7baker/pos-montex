import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';

final salesReturnServiceProvider = Provider<SalesReturnService>(
  (ref) => SalesReturnService(ref.watch(appDbProvider)),
);

class SalesReturnDraftData {
  const SalesReturnDraftData({required this.sale, required this.items});

  final SaleDb sale;
  final List<ReturnableSaleItem> items;
}

class ReturnableSaleItem {
  const ReturnableSaleItem({
    required this.productId,
    required this.serverProductId,
    required this.name,
    required this.unitPrice,
    required this.soldQty,
    required this.returnedQty,
    required this.availableQty,
  });

  final int productId;
  final int? serverProductId;
  final String name;
  final double unitPrice;
  final int soldQty;
  final int returnedQty;
  final int availableQty;
}

class SalesReturnRequestItem {
  const SalesReturnRequestItem({
    required this.productId,
    required this.serverProductId,
    required this.nameSnapshot,
    required this.qty,
    required this.price,
  });

  final int productId;
  final int? serverProductId;
  final String nameSnapshot;
  final int qty;
  final double price;
}

class SalesReturnCreateResult {
  const SalesReturnCreateResult({
    required this.returnLocalId,
    required this.returnNo,
    required this.itemsCount,
    required this.total,
  });

  final int returnLocalId;
  final String returnNo;
  final int itemsCount;
  final double total;
}

class SalesReturnService {
  const SalesReturnService(this._db);

  final AppDb _db;

  Future<SalesReturnDraftData> loadDraft(int saleLocalId) async {
    final sale =
        await (_db.select(_db.sales)
              ..where((t) => t.localId.equals(saleLocalId))
              ..limit(1))
            .getSingle();

    final saleItems =
        await (_db.select(_db.saleItems)
              ..where((t) => t.saleLocalId.equals(saleLocalId))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
            .get();

    final linkedReturns = await (_db.select(
      _db.salesReturns,
    )..where((t) => t.originalSaleLocalId.equals(saleLocalId))).get();
    final returnIds = linkedReturns.map((e) => e.localId).toList();
    final returnedItems = returnIds.isEmpty
        ? const <SalesReturnItemDb>[]
        : await (_db.select(
            _db.salesReturnItems,
          )..where((t) => t.returnLocalId.isIn(returnIds))).get();

    final returnedQtyByProduct = <int, int>{};
    for (final item in returnedItems) {
      returnedQtyByProduct[item.productId] =
          (returnedQtyByProduct[item.productId] ?? 0) + item.qty;
    }

    final soldByProduct = <int, _SoldAccumulator>{};
    for (final item in saleItems) {
      soldByProduct.update(
        item.productId,
        (existing) => existing.copyWith(
          qty: existing.qty + item.qty,
          total: existing.total + item.total,
        ),
        ifAbsent: () => _SoldAccumulator(
          productId: item.productId,
          serverProductId: item.serverProductId,
          name: item.nameSnapshot.trim().isEmpty
              ? 'صنف #${item.productId}'
              : item.nameSnapshot.trim(),
          qty: item.qty,
          total: item.total,
          unitPrice: item.price,
        ),
      );
    }

    final items =
        soldByProduct.values
            .map((entry) {
              final returnedQty = returnedQtyByProduct[entry.productId] ?? 0;
              final availableQty = entry.qty - returnedQty;
              return ReturnableSaleItem(
                productId: entry.productId,
                serverProductId: entry.serverProductId,
                name: entry.name,
                unitPrice: entry.unitPrice,
                soldQty: entry.qty,
                returnedQty: returnedQty,
                availableQty: availableQty < 0 ? 0 : availableQty,
              );
            })
            .where((item) => item.availableQty > 0)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return SalesReturnDraftData(sale: sale, items: items);
  }

  Future<SalesReturnCreateResult> createSalesReturn({
    required SaleDb sale,
    required List<SalesReturnRequestItem> items,
    String? reason,
  }) async {
    final effectiveItems = items.where((item) => item.qty > 0).toList();
    if (effectiveItems.isEmpty) {
      throw Exception('اختر صنفاً واحداً على الأقل لعمل المرتجع');
    }

    final draft = await loadDraft(sale.localId);
    final availableQtyByProduct = {
      for (final item in draft.items) item.productId: item.availableQty,
    };

    for (final item in effectiveItems) {
      final available = availableQtyByProduct[item.productId] ?? 0;
      if (available <= 0) {
        throw Exception('الصنف ${item.nameSnapshot} لم يعد متاحاً للمرتجع');
      }
      if (item.qty > available) {
        throw Exception(
          'الكمية المرتجعة للصنف ${item.nameSnapshot} أكبر من الكمية المتاحة',
        );
      }
    }

    final now = DateTime.now();
    final itemsCount = effectiveItems.fold<int>(
      0,
      (sum, item) => sum + item.qty,
    );
    final subtotal = _round2(
      effectiveItems.fold<double>(
        0,
        (sum, item) => sum + (item.price * item.qty),
      ),
    );
    final returnNo =
        'RTN-${DateFormat('yyyyMMddHHmmss').format(now)}-${sale.localId}';

    final returnLocalId = await _db.transaction(() async {
      final newReturnLocalId = await _db
          .into(_db.salesReturns)
          .insert(
            SalesReturnsCompanion.insert(
              uuid: const Uuid().v4(),
              returnNo: drift.Value(returnNo),
              originalSaleLocalId: drift.Value(sale.localId),
              shiftLocalId: drift.Value(sale.shiftLocalId),
              subtotal: drift.Value(subtotal),
              tax: const drift.Value(0),
              discount: const drift.Value(0),
              total: drift.Value(subtotal),
              reason: drift.Value(
                (reason ?? '').trim().isEmpty ? null : reason,
              ),
              status: const drift.Value('completed'),
              syncStatus: const drift.Value('PENDING'),
              createdAt: drift.Value(now),
              updatedAtLocal: drift.Value(now),
            ),
          );

      await _db.batch((batch) {
        batch.insertAll(_db.salesReturnItems, [
          for (final item in effectiveItems)
            SalesReturnItemsCompanion.insert(
              returnLocalId: newReturnLocalId,
              productId: item.productId,
              serverProductId: drift.Value(item.serverProductId),
              nameSnapshot: drift.Value(item.nameSnapshot),
              qty: item.qty,
              price: item.price,
              total: drift.Value(_round2(item.price * item.qty)),
            ),
        ]);
      });

      for (final item in effectiveItems) {
        final product =
            await (_db.select(_db.products)
                  ..where((t) => t.id.equals(item.productId))
                  ..limit(1))
                .getSingleOrNull();
        if (product == null) continue;
        await (_db.update(
          _db.products,
        )..where((t) => t.id.equals(product.id))).write(
          ProductsCompanion(
            stock: drift.Value(product.stock + item.qty),
            updatedAt: drift.Value(now),
          ),
        );
      }

      await (_db.update(_db.sales)
            ..where((t) => t.localId.equals(sale.localId)))
          .write(SalesCompanion(syncStatus: const drift.Value('PENDING')));

      return newReturnLocalId;
    });

    return SalesReturnCreateResult(
      returnLocalId: returnLocalId,
      returnNo: returnNo,
      itemsCount: itemsCount,
      total: subtotal,
    );
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;
}

class _SoldAccumulator {
  const _SoldAccumulator({
    required this.productId,
    required this.serverProductId,
    required this.name,
    required this.qty,
    required this.total,
    required this.unitPrice,
  });

  final int productId;
  final int? serverProductId;
  final String name;
  final int qty;
  final double total;
  final double unitPrice;

  _SoldAccumulator copyWith({int? qty, double? total}) {
    return _SoldAccumulator(
      productId: productId,
      serverProductId: serverProductId,
      name: name,
      qty: qty ?? this.qty,
      total: total ?? this.total,
      unitPrice: unitPrice,
    );
  }
}
