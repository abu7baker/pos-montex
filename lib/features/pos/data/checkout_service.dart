import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../domain/checkout_models.dart';
import '../presentation/cart_provider.dart';

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  final db = ref.watch(appDbProvider);
  return CheckoutService(db);
});

class CheckoutService {
  CheckoutService(this._db);

  final AppDb _db;
  static const double _fixedTaxRate = 0.15;

  Future<CheckoutResult> checkoutCash(
    CartState cart,
    double discount, {
    String? invoiceNo,
    int? customerId,
    DeliveryPrintInput? delivery,
    ServiceInput? service,
    TableInput? table,
  }) {
    final total = _calculateTotal(
      cart,
      discount,
      serviceCost: service?.cost ?? 0,
      deliveryFee: delivery?.fee ?? 0,
    );
    return _checkout(
      cart: cart,
      discount: discount,
      invoiceNo: invoiceNo,
      customerId: customerId,
      delivery: delivery,
      service: service,
      table: table,
      payments: [PaymentInput(methodCode: 'CASH', amount: total)],
    );
  }

  Future<CheckoutResult> checkoutCard(
    CartState cart, {
    String? reference,
    int? customerId,
    double discount = 0,
    DeliveryPrintInput? delivery,
    ServiceInput? service,
    TableInput? table,
  }) {
    final total = _calculateTotal(
      cart,
      discount,
      serviceCost: service?.cost ?? 0,
      deliveryFee: delivery?.fee ?? 0,
    );
    return _checkout(
      cart: cart,
      discount: discount,
      customerId: customerId,
      delivery: delivery,
      service: service,
      table: table,
      payments: [
        PaymentInput(methodCode: 'CARD', amount: total, reference: reference),
      ],
    );
  }

  Future<CheckoutResult> checkoutCredit(
    CartState cart, {
    String? note,
    int? customerId,
    double discount = 0,
    DeliveryPrintInput? delivery,
    ServiceInput? service,
    TableInput? table,
  }) {
    return _checkout(
      cart: cart,
      discount: discount,
      customerId: customerId,
      delivery: delivery,
      service: service,
      table: table,
      payments: const [],
      creditNote: note,
    );
  }

  Future<CheckoutResult> checkoutMulti(
    CartState cart,
    List<PaymentInput> payments, {
    int? customerId,
    double discount = 0,
    DeliveryPrintInput? delivery,
    ServiceInput? service,
    TableInput? table,
  }) {
    if (payments.isEmpty) {
      throw Exception('يجب إضافة دفعة واحدة على الأقل');
    }
    return _checkout(
      cart: cart,
      discount: discount,
      customerId: customerId,
      delivery: delivery,
      service: service,
      table: table,
      payments: payments,
    );
  }

  double _calculateSubtotal(CartState cart) {
    return cart.items.fold(0.0, (sum, item) => sum + item.total);
  }

  double _calculateTotal(
    CartState cart,
    double discount, {
    double serviceCost = 0,
    double deliveryFee = 0,
  }) {
    final subtotal = _calculateSubtotal(cart);
    final tax = _calculateFixedTax(
      subtotal: subtotal,
      discount: discount,
      serviceCost: serviceCost,
      deliveryFee: deliveryFee,
    );
    return _round2(subtotal + tax + serviceCost + deliveryFee - discount);
  }

  Future<CheckoutResult> _checkout({
    required CartState cart,
    required double discount,
    required List<PaymentInput> payments,
    int? customerId,
    DeliveryPrintInput? delivery,
    ServiceInput? service,
    TableInput? table,
    String? invoiceNo,
    String? creditNote,
  }) async {
    final subtotal = _round2(_calculateSubtotal(cart));
    final normalizedServiceName = (service?.name ?? '').trim();
    final serviceCost = _round2(service?.cost ?? 0);
    final deliveryFee = _round2(delivery?.fee ?? 0);
    final normalizedTableName = (table?.name ?? '').trim();
    final tax = _calculateFixedTax(
      subtotal: subtotal,
      discount: discount,
      serviceCost: serviceCost,
      deliveryFee: deliveryFee,
    );
    final total = _round2(
      subtotal + tax + serviceCost + deliveryFee - discount,
    );
    if (total <= 0) {
      throw Exception('لا يمكن حفظ فاتورة بإجمالي أقل من أو يساوي صفر');
    }

    if (payments.isNotEmpty) {
      final sum = payments.fold(0.0, (acc, p) => acc + p.amount);
      if (sum <= 0) {
        throw Exception('إجمالي الدفعات يجب أن يكون أكبر من صفر');
      }
    }

    final paidTotal = _round2(payments.fold(0.0, (acc, p) => acc + p.amount));
    var remaining = _round2(total - paidTotal);
    var change = 0.0;
    if (remaining < 0) {
      change = _round2(-remaining);
      remaining = 0.0;
    }

    final status = _resolveStatus(total, paidTotal, remaining);
    final completedAt = status == 'completed' ? DateTime.now() : null;
    final uuid = const Uuid().v4();

    final productIds = cart.items.map((e) => e.product.id).toSet().toList();
    final productRows = productIds.isEmpty
        ? <ProductDb>[]
        : await (_db.select(
            _db.products,
          )..where((t) => t.id.isIn(productIds))).get();
    final categoryIds = productRows
        .map((p) => p.categoryId)
        .whereType<int>()
        .toSet()
        .toList();
    final categoryRows = categoryIds.isEmpty
        ? <ProductCategoryDb>[]
        : await (_db.select(
            _db.productCategories,
          )..where((t) => t.id.isIn(categoryIds))).get();
    final stationByCategory = {
      for (final row in categoryRows) row.id: (row.stationCode ?? '').trim(),
    };
    final stationById = {
      for (final row in productRows)
        row.id: (stationByCategory[row.categoryId] ?? row.stationCode).trim(),
    };
    final productRowById = {for (final row in productRows) row.id: row};

    final shiftContext = await _resolveActiveShiftContext();

    final saleLocalId = await _db.transaction(() async {
      final createdAt = DateTime.now();
      final dailyOrderNo = await _db.nextDailyOrderNo(now: createdAt);
      final saleId = await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              uuid: uuid,
              invoiceNo: drift.Value(invoiceNo),
              dailyOrderNo: drift.Value(dailyOrderNo),
              subtotal: drift.Value(subtotal),
              tax: drift.Value(tax),
              discount: drift.Value(discount),
              serviceId: drift.Value(service?.id),
              serviceNameSnapshot: drift.Value(
                normalizedServiceName.isEmpty ? null : normalizedServiceName,
              ),
              serviceCost: drift.Value(serviceCost),
              tableId: drift.Value(table?.id),
              tableNameSnapshot: drift.Value(
                normalizedTableName.isEmpty ? null : normalizedTableName,
              ),
              customerId: drift.Value(customerId),
              branchServerId: drift.Value(shiftContext.branchServerId),
              cashierServerId: drift.Value(shiftContext.cashierServerId),
              shiftLocalId: drift.Value(shiftContext.shiftLocalId),
              total: total,
              paidTotal: drift.Value(paidTotal),
              remaining: drift.Value(remaining),
              status: drift.Value(status),
              createdAt: drift.Value(createdAt),
              completedAtLocal: drift.Value(completedAt),
              syncStatus: const drift.Value('PENDING'),
            ),
          );

      if (cart.items.isNotEmpty) {
        for (final item in cart.items) {
          final saleItemId = await _db
              .into(_db.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  saleLocalId: saleId,
                  productId: item.product.id,
                  categoryId: drift.Value(item.product.categoryId),
                  categoryNameSnapshot: drift.Value(item.product.categoryName),
                  serverProductId: drift.Value(
                    productRowById[item.product.id]?.serverId,
                  ),
                  nameSnapshot: drift.Value(item.product.name),
                  qty: item.qty,
                  price: item.unitPrice,
                  total: drift.Value(item.total),
                  stationCode: drift.Value(stationById[item.product.id] ?? ''),
                  note: drift.Value(_buildItemNote(item.selectedAddons)),
                ),
              );
          if (item.selectedAddons.isNotEmpty) {
            await _db.batch((b) {
              b.insertAll(_db.saleItemAddons, [
                for (final addon in item.selectedAddons)
                  SaleItemAddonsCompanion.insert(
                    saleItemId: saleItemId,
                    groupId: drift.Value(addon.groupId),
                    itemId: drift.Value(addon.itemId),
                    groupNameSnapshot: drift.Value(addon.groupName),
                    itemNameSnapshot: drift.Value(addon.itemName),
                    price: drift.Value(addon.price),
                  ),
              ]);
            });
          }
        }
      }

      if (payments.isNotEmpty) {
        final paymentRows = payments
            .map(
              (p) => SalePaymentsCompanion.insert(
                saleLocalId: saleId,
                methodCode: p.methodCode,
                amount: p.amount,
                reference: drift.Value(p.reference),
                note: drift.Value(p.note ?? creditNote),
              ),
            )
            .toList();
        await _db.batch((b) => b.insertAll(_db.salePayments, paymentRows));
      }

      return saleId;
    });

    await _db.enqueueSaleForSync(saleLocalId);
    await _db.createPrintJobsForSale(
      saleLocalId,
      payload: _buildPrintPayload(delivery),
    );

    return CheckoutResult(
      saleLocalId: saleLocalId,
      total: total,
      paidTotal: paidTotal,
      remaining: remaining,
      change: change,
      status: status,
    );
  }

  double _calculateFixedTax({
    required double subtotal,
    required double discount,
    required double serviceCost,
    required double deliveryFee,
  }) {
    final taxableBase = subtotal + serviceCost + deliveryFee - discount;
    if (taxableBase <= 0) return 0;
    return _round2(taxableBase * _fixedTaxRate);
  }

  String? _buildItemNote(List<CartAddonSelection> selectedAddons) {
    if (selectedAddons.isEmpty) return null;
    return selectedAddons.map((addon) => addon.invoiceLabel).join('\n');
  }

  String _resolveStatus(double total, double paidTotal, double remaining) {
    const epsilon = 0.01;
    if (paidTotal <= epsilon && (remaining - total).abs() <= epsilon) {
      return 'credit';
    }
    if (remaining <= epsilon) {
      return 'completed';
    }
    if (paidTotal > epsilon && remaining > epsilon) {
      return 'partial';
    }
    return 'queued';
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  Future<_ActiveShiftContext> _resolveActiveShiftContext() async {
    final linkSalesRaw = await _db.getSetting('shift.link_sales_to_open_shift');
    final shouldLinkSales = _parseBool(linkSalesRaw, fallback: true);
    final fallbackBranchServerId = await _resolveSelectedBranchServerId();
    final fallbackCashierServerId = await _resolveCurrentCashierServerId();
    if (!shouldLinkSales) {
      return _ActiveShiftContext(
        branchServerId: fallbackBranchServerId,
        cashierServerId: fallbackCashierServerId,
      );
    }

    final raw = (await _db.getSetting('current_shift_local_id'))?.trim();
    final shiftId = int.tryParse(raw ?? '');
    if (shiftId == null || shiftId <= 0) {
      return _ActiveShiftContext(
        branchServerId: fallbackBranchServerId,
        cashierServerId: fallbackCashierServerId,
      );
    }

    final shift = await (_db.select(
      _db.shifts,
    )..where((t) => t.localId.equals(shiftId))).getSingleOrNull();
    if (shift == null) {
      return _ActiveShiftContext(
        branchServerId: fallbackBranchServerId,
        cashierServerId: fallbackCashierServerId,
      );
    }

    final isOpen =
        shift.status.trim().toLowerCase() == 'open' && shift.closedAt == null;
    if (!isOpen) {
      return _ActiveShiftContext(
        branchServerId: fallbackBranchServerId,
        cashierServerId: fallbackCashierServerId,
      );
    }

    return _ActiveShiftContext(
      shiftLocalId: shift.localId,
      branchServerId: shift.branchServerId ?? fallbackBranchServerId,
      cashierServerId: shift.cashierServerId ?? fallbackCashierServerId,
    );
  }

  Future<int?> _resolveSelectedBranchServerId() async {
    final raw = (await _db.getSetting('branch_server_id'))?.trim() ?? '';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Future<int?> _resolveCurrentCashierServerId() async {
    final raw = (await _db.getApiMeta('current_user_server_id'))?.trim() ?? '';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  bool _parseBool(String? raw, {required bool fallback}) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return fallback;
    return value == '1' || value == 'true' || value == 'yes';
  }

  String? _buildPrintPayload(DeliveryPrintInput? delivery) {
    if (delivery == null || !delivery.hasPrintableDetails) return null;
    return jsonEncode({
      'schema': 'montex.print.payload.v1',
      'delivery': {
        'enabled': delivery.enabled || delivery.fee > 0,
        'fee': delivery.fee,
        'details': delivery.details.trim(),
        'address': delivery.address.trim(),
        'assignee': delivery.assignee.trim(),
      },
    });
  }
}

class _ActiveShiftContext {
  const _ActiveShiftContext({
    this.shiftLocalId,
    this.branchServerId,
    this.cashierServerId,
  });

  final int? shiftLocalId;
  final int? branchServerId;
  final int? cashierServerId;
}
