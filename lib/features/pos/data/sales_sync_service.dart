import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../../core/payment_methods.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/data/auth_api_service.dart';

final salesSyncServiceProvider = Provider<SalesSyncService>((ref) {
  return SalesSyncService(
    ref.watch(appDbProvider),
    ref.watch(secureStorageProvider),
    ref.watch(authApiServiceProvider),
  );
});

class SalesSyncResult {
  const SalesSyncResult({
    required this.syncedCount,
    required this.failedCount,
    required this.skippedCount,
  });

  final int syncedCount;
  final int failedCount;
  final int skippedCount;
}

class SalesSyncService {
  SalesSyncService(this._db, this._storage, this._authApiService);

  final AppDb _db;
  final SecureStorage _storage;
  final AuthApiService _authApiService;

  Future<SalesSyncResult> syncPendingSales({int limit = 50}) async {
    final sales = await _loadPendingSales(limit: limit);
    if (sales.isEmpty) {
      await _db.setApiMeta(
        'last_sales_sync_at',
        DateTime.now().toIso8601String(),
      );
      return const SalesSyncResult(
        syncedCount: 0,
        failedCount: 0,
        skippedCount: 0,
      );
    }

    final saleIds = sales.map((sale) => sale.localId).toList(growable: false);
    final saleItems = await (_db.select(
      _db.saleItems,
    )..where((t) => t.saleLocalId.isIn(saleIds))).get();
    final salePayments = await (_db.select(
      _db.salePayments,
    )..where((t) => t.saleLocalId.isIn(saleIds))).get();

    final productIds = saleItems.map((item) => item.productId).toSet().toList();
    final products = productIds.isEmpty
        ? const <ProductDb>[]
        : await (_db.select(
            _db.products,
          )..where((t) => t.id.isIn(productIds))).get();

    final customers = await (_db.select(_db.customers)).get();

    final itemsBySaleId = <int, List<SaleItemDb>>{};
    for (final item in saleItems) {
      (itemsBySaleId[item.saleLocalId] ??= <SaleItemDb>[]).add(item);
    }

    final paymentsBySaleId = <int, List<SalePaymentDb>>{};
    for (final payment in salePayments) {
      (paymentsBySaleId[payment.saleLocalId] ??= <SalePaymentDb>[]).add(
        payment,
      );
    }

    final productsById = {for (final product in products) product.id: product};
    final customersById = {
      for (final customer in customers) customer.id: customer,
    };

    final uploadBaseUrl = await _resolveUploadBaseUrl();
    final initialToken = (await _storage.readToken())?.trim();
    var uploadToken = initialToken != null && initialToken.isNotEmpty
        ? initialToken
        : null;

    var syncedCount = 0;
    var failedCount = 0;
    var skippedCount = 0;

    for (final sale in sales) {
      try {
        final payload = await _buildSalePayload(
          sale,
          items: itemsBySaleId[sale.localId] ?? const <SaleItemDb>[],
          payments: paymentsBySaleId[sale.localId] ?? const <SalePaymentDb>[],
          productsById: productsById,
          customersById: customersById,
        );

        if (payload == null) {
          skippedCount++;
          await _markSaleSkipped(sale.localId);
          continue;
        }

        Map<String, dynamic> uploadedSale;
        try {
          uploadedSale = await _uploadSale(
            payload: payload,
            uploadBaseUrl: uploadBaseUrl,
            bearerToken: uploadToken,
          );
        } on DioException catch (error) {
          if (!_isUnauthorized(error)) rethrow;
          uploadToken = await _restoreUploadToken(uploadBaseUrl);
          uploadedSale = await _uploadSale(
            payload: payload,
            uploadBaseUrl: uploadBaseUrl,
            bearerToken: uploadToken,
          );
        }

        await _markSaleSynced(
          sale: sale,
          uploadedSale: uploadedSale,
          payments: paymentsBySaleId[sale.localId] ?? const <SalePaymentDb>[],
        );
        syncedCount++;
      } catch (error) {
        failedCount++;
        await _markSaleFailed(sale.localId, _normalizeErrorMessage(error));
      }
    }

    await _db.setApiMeta(
      'last_sales_sync_at',
      DateTime.now().toIso8601String(),
    );
    return SalesSyncResult(
      syncedCount: syncedCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
    );
  }

  Future<List<SaleDb>> _loadPendingSales({required int limit}) {
    final query = _db.select(_db.sales)
      ..where((t) => t.syncStatus.isIn(const ['PENDING', 'FAILED']))
      ..where((t) => t.serverSaleId.isNull())
      ..where((t) => t.status.equals('QUOTATION').not())
      ..where((t) => t.status.equals('quotation').not())
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.createdAt),
        (t) => drift.OrderingTerm(expression: t.localId),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<Map<String, dynamic>> _uploadSale({
    required Map<String, dynamic> payload,
    required String uploadBaseUrl,
    required String? bearerToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: uploadBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          if (bearerToken != null && bearerToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${bearerToken.trim()}',
        },
      ),
    );

    final response = await dio.post<dynamic>(
      AppConfig.connectorSellPath,
      data: {
        'sells': [payload],
      },
    );

    final uploadedSale = _extractUploadedSale(response.data);
    if (uploadedSale == null) {
      throw Exception('لم يرجع الخادم بيانات الفاتورة المرفوعة');
    }
    return uploadedSale;
  }

  Map<String, dynamic>? _extractUploadedSale(dynamic payload) {
    if (payload is List && payload.isNotEmpty && payload.first is Map) {
      return (payload.first as Map).cast<String, dynamic>();
    }
    if (payload is Map) {
      final data = payload['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return (data.first as Map).cast<String, dynamic>();
      }
      if (data is Map) return data.cast<String, dynamic>();
      return payload.cast<String, dynamic>();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _buildSalePayload(
    SaleDb sale, {
    required List<SaleItemDb> items,
    required List<SalePaymentDb> payments,
    required Map<int, ProductDb> productsById,
    required Map<int, CustomerDb> customersById,
  }) async {
    if (items.isEmpty) {
      throw Exception('الفاتورة المحلية #${sale.localId} لا تحتوي على أصناف');
    }

    final locationId = await _resolveLocationId(sale);
    final contactId = await _resolveContactId(
      sale,
      customersById: customersById,
    );
    final apiProducts = <Map<String, dynamic>>[];

    for (final item in items) {
      final product = productsById[item.productId];
      final productServerId = item.serverProductId ?? product?.serverId;
      if (productServerId == null || productServerId <= 0) {
        throw Exception(
          'الصنف "${item.nameSnapshot.trim().isEmpty ? item.productId : item.nameSnapshot}" غير مربوط بمعرف السيرفر',
        );
      }

      apiProducts.add({
        'product_id': productServerId,
        'variation_id': productServerId,
        'quantity': item.qty,
        'unit_price': _round2(item.price),
      });
    }

    final apiPayments = <Map<String, dynamic>>[
      for (final payment in payments)
        {
          'amount': _round2(payment.amount),
          'method': _mapPaymentMethodToApi(payment.methodCode),
        },
    ];

    final invoiceNo = (sale.invoiceNo?.trim().isNotEmpty ?? false)
        ? sale.invoiceNo!.trim()
        : 'POS-${sale.localId}';

    return {
      'location_id': locationId,
      'contact_id': contactId,
      'transaction_date': _formatApiDate(sale.createdAt),
      'invoice_no': invoiceNo,
      'source': 'api',
      'status': 'final',
      'discount_amount': _round2(sale.discount),
      'discount_type': 'fixed',
      'products': apiProducts,
      'payments': apiPayments,
    };
  }

  Future<int> _resolveLocationId(SaleDb sale) async {
    final saleBranchId = sale.branchServerId;
    if (saleBranchId != null && saleBranchId > 0) {
      return saleBranchId;
    }

    final raw = (await _db.getSetting('branch_server_id'))?.trim() ?? '';
    final parsed = int.tryParse(raw);
    if (parsed != null && parsed > 0) {
      return parsed;
    }

    throw Exception('لم يتم تحديد فرع صالح لرفع الفاتورة');
  }

  Future<int> _resolveContactId(
    SaleDb sale, {
    required Map<int, CustomerDb> customersById,
  }) async {
    final selectedCustomer = sale.customerId == null
        ? null
        : customersById[sale.customerId!];
    final selectedServerId = _extractServerCustomerId(selectedCustomer);
    if (selectedServerId != null && selectedServerId > 0) {
      return selectedServerId;
    }

    final defaultCustomer = await _findDefaultCustomer(customersById.values);
    final defaultServerId = _extractServerCustomerId(defaultCustomer);
    if (defaultServerId != null && defaultServerId > 0) {
      return defaultServerId;
    }

    throw Exception(
      'تعذر تحديد العميل الافتراضي على السيرفر. نفذ مزامنة العملاء أولاً.',
    );
  }

  Future<CustomerDb?> _findDefaultCustomer(
    Iterable<CustomerDb> customers,
  ) async {
    final savedDefaultId = int.tryParse(
      (await _db.getApiMeta('default_customer_server_id'))?.trim() ?? '',
    );

    if (savedDefaultId != null && savedDefaultId > 0) {
      for (final customer in customers) {
        if (_extractServerCustomerId(customer) == savedDefaultId) {
          return customer;
        }
      }
    }

    for (final customer in customers) {
      final normalizedName = customer.name.trim();
      if (normalizedName == 'عميل عام' ||
          normalizedName.toLowerCase() == 'walk-in customer') {
        return customer;
      }
    }

    return null;
  }

  int? _extractServerCustomerId(CustomerDb? customer) {
    if (customer == null) return null;
    final code = (customer.code ?? '').trim();
    if (code.toUpperCase().startsWith('SRV:')) {
      return int.tryParse(code.substring(4).trim());
    }
    return int.tryParse(code);
  }

  Future<void> _markSaleSynced({
    required SaleDb sale,
    required Map<String, dynamic> uploadedSale,
    required List<SalePaymentDb> payments,
  }) async {
    final serverSaleId = _readInt(uploadedSale['id']);
    final syncedAt = DateTime.now();
    final paymentLines = _extractResponseItems(uploadedSale['payment_lines']);

    await _db.transaction(() async {
      await (_db.update(
        _db.sales,
      )..where((t) => t.localId.equals(sale.localId))).write(
        SalesCompanion(
          serverSaleId: drift.Value(serverSaleId),
          syncStatus: const drift.Value('SYNCED'),
          syncError: const drift.Value(null),
          syncedAt: drift.Value(syncedAt),
        ),
      );

      for (var i = 0; i < payments.length; i++) {
        if (i >= paymentLines.length) break;
        final paymentServerId = _readInt(paymentLines[i]['id']);
        if (paymentServerId == null || paymentServerId <= 0) continue;
        await (_db.update(
          _db.salePayments,
        )..where((t) => t.id.equals(payments[i].id))).write(
          SalePaymentsCompanion(serverPaymentId: drift.Value(paymentServerId)),
        );
      }
    });

    await _markQueueState(sale.localId, success: true);
  }

  Future<void> _markSaleFailed(int saleLocalId, String error) async {
    await (_db.update(
      _db.sales,
    )..where((t) => t.localId.equals(saleLocalId))).write(
      SalesCompanion(
        syncStatus: const drift.Value('FAILED'),
        syncError: drift.Value(error),
      ),
    );
    await _markQueueState(saleLocalId, success: false, error: error);
  }

  Future<void> _markSaleSkipped(int saleLocalId) async {
    await (_db.update(
      _db.sales,
    )..where((t) => t.localId.equals(saleLocalId))).write(
      SalesCompanion(
        syncStatus: const drift.Value('SKIPPED'),
        syncError: const drift.Value(null),
        syncedAt: drift.Value(DateTime.now()),
      ),
    );
    await _markQueueState(saleLocalId, success: true);
  }

  Future<void> _markQueueState(
    int saleLocalId, {
    required bool success,
    String? error,
  }) async {
    final queueRow =
        await (_db.select(_db.syncQueue)
              ..where(
                (t) =>
                    t.entityType.equals('sale') &
                    t.entityLocalId.equals(saleLocalId) &
                    t.action.equals('UPSERT') &
                    t.status.isNotIn(const ['DONE']),
              )
              ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    if (queueRow == null) return;
    if (success) {
      await _db.markSyncQueueDone(queueRow.id);
    } else {
      await _db.markSyncQueueFailed(queueRow.id, error ?? 'unknown sync error');
    }
  }

  Future<String?> _restoreUploadToken(String uploadBaseUrl) async {
    final username = (await _storage.readSavedUsername())?.trim() ?? '';
    final password = await _storage.readSavedPassword() ?? '';
    final clientId = (await _storage.readOauthClientId())?.trim() ?? '';
    final clientSecret = (await _storage.readOauthClientSecret())?.trim() ?? '';

    if (username.isEmpty ||
        password.isEmpty ||
        clientId.isEmpty ||
        clientSecret.isEmpty) {
      return null;
    }

    final tokens = await _authApiService.loginWithPassport(
      baseUrl: uploadBaseUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      username: username,
      password: password,
    );
    return tokens.accessToken.trim().isEmpty ? null : tokens.accessToken.trim();
  }

  Future<String> _resolveUploadBaseUrl() async {
    final configured = AppConfig.salesUploadBaseUrl.trim();
    if (configured.isNotEmpty) return _normalizeBaseUrl(configured);
    final stored = (await _storage.readApiBaseUrl())?.trim();
    if (stored != null && stored.isNotEmpty) return _normalizeBaseUrl(stored);
    return _normalizeBaseUrl(AppConfig.defaultBaseUrl);
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

  bool _isUnauthorized(DioException error) {
    return error.response?.statusCode == 401;
  }

  String _formatApiDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
  }

  String _mapPaymentMethodToApi(String methodCode) {
    switch (PaymentMethods.normalizeCode(methodCode)) {
      case PaymentMethods.cash:
        return 'cash';
      case PaymentMethods.card:
        return 'card';
      case PaymentMethods.cheque:
        return 'cheque';
      case PaymentMethods.bankTransfer:
        return 'bank_transfer';
      case PaymentMethods.other:
        return 'other';
      case PaymentMethods.customPay1:
        return 'custom_pay_1';
      case PaymentMethods.customPay2:
        return 'custom_pay_2';
      case PaymentMethods.customPay3:
        return 'custom_pay_3';
      case PaymentMethods.customPay4:
        return 'custom_pay_4';
      case PaymentMethods.customPay5:
        return 'custom_pay_5';
      case PaymentMethods.customPay6:
        return 'custom_pay_6';
      case PaymentMethods.customPay7:
        return 'custom_pay_7';
      default:
        return methodCode.trim().toLowerCase();
    }
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _normalizeErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length).trim();
    }
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map) {
        final message = payload['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    }
    return text.isEmpty ? 'unknown sync error' : text;
  }
}

List<Map<String, dynamic>> _extractResponseItems(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().trim());
}
