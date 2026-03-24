import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';

final controlPanelSalesServiceProvider = Provider<ControlPanelSalesService>(
  (ref) => ControlPanelSalesService(ref.watch(appDbProvider)),
);

enum SalesListingKind { allSales, salesReturns, creditSales, quotations }

class SalesDashboardData {
  const SalesDashboardData({
    required this.kind,
    required this.fromDate,
    required this.toDate,
    required this.searchQuery,
    required this.invoiceCount,
    required this.itemsCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.returnsAmount,
    required this.salesRows,
    required this.returnRows,
  });

  final SalesListingKind kind;
  final DateTime fromDate;
  final DateTime toDate;
  final String searchQuery;
  final int invoiceCount;
  final int itemsCount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final double returnsAmount;
  final List<ControlPanelSaleRow> salesRows;
  final List<ControlPanelSalesReturnRow> returnRows;
}

class ControlPanelSaleRow {
  const ControlPanelSaleRow({
    required this.sale,
    required this.customerName,
    required this.serviceName,
    required this.tableName,
    required this.shiftLabel,
    required this.returnsCount,
    required this.returnedTotal,
  });

  final SaleDb sale;
  final String customerName;
  final String serviceName;
  final String tableName;
  final String shiftLabel;
  final int returnsCount;
  final double returnedTotal;
}

class ControlPanelSalesReturnRow {
  const ControlPanelSalesReturnRow({
    required this.salesReturn,
    required this.originalInvoiceNo,
    required this.shiftLabel,
    required this.itemsCount,
    required this.originalCustomerName,
  });

  final SalesReturnDb salesReturn;
  final String originalInvoiceNo;
  final String shiftLabel;
  final int itemsCount;
  final String originalCustomerName;
}

class ControlPanelSaleDetailData {
  const ControlPanelSaleDetailData({
    required this.sale,
    required this.customerName,
    required this.serviceName,
    required this.tableName,
    required this.shiftLabel,
    required this.items,
    required this.payments,
    required this.linkedReturns,
  });

  final SaleDb sale;
  final String customerName;
  final String serviceName;
  final String tableName;
  final String shiftLabel;
  final List<SaleItemDb> items;
  final List<SalePaymentDb> payments;
  final List<SalesReturnDb> linkedReturns;
}

class ControlPanelSalesReturnDetailData {
  const ControlPanelSalesReturnDetailData({
    required this.salesReturn,
    required this.originalSale,
    required this.originalInvoiceNo,
    required this.originalCustomerName,
    required this.shiftLabel,
    required this.items,
  });

  final SalesReturnDb salesReturn;
  final SaleDb? originalSale;
  final String originalInvoiceNo;
  final String originalCustomerName;
  final String shiftLabel;
  final List<SalesReturnItemDb> items;
}

class ControlPanelSalesService {
  const ControlPanelSalesService(this._db);

  final AppDb _db;

  Future<SalesDashboardData> loadDashboard({
    required SalesListingKind kind,
    required DateTime fromDate,
    required DateTime toDate,
    String searchQuery = '',
  }) async {
    switch (kind) {
      case SalesListingKind.salesReturns:
        return _loadReturnsDashboard(
          fromDate: fromDate,
          toDate: toDate,
          searchQuery: searchQuery,
        );
      case SalesListingKind.allSales:
      case SalesListingKind.creditSales:
      case SalesListingKind.quotations:
        return _loadSalesDashboard(
          kind: kind,
          fromDate: fromDate,
          toDate: toDate,
          searchQuery: searchQuery,
        );
    }
  }

  Future<ControlPanelSaleDetailData> loadSaleDetail(int saleLocalId) async {
    final sale =
        await (_db.select(_db.sales)
              ..where((t) => t.localId.equals(saleLocalId))
              ..limit(1))
            .getSingle();

    final customerName = await _resolveCustomerName(sale.customerId);
    final serviceName = await _resolveServiceName(
      sale.serviceId,
      sale.serviceNameSnapshot,
    );
    final tableName = await _resolveTableName(
      sale.tableId,
      sale.tableNameSnapshot,
    );
    final shiftLabel = await _resolveShiftLabel(sale.shiftLocalId);

    final items =
        await (_db.select(_db.saleItems)
              ..where((t) => t.saleLocalId.equals(saleLocalId))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
            .get();
    final payments =
        await (_db.select(_db.salePayments)
              ..where((t) => t.saleLocalId.equals(saleLocalId))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
            .get();
    final linkedReturns =
        await (_db.select(_db.salesReturns)
              ..where((t) => t.originalSaleLocalId.equals(saleLocalId))
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.createdAt,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    return ControlPanelSaleDetailData(
      sale: sale,
      customerName: customerName,
      serviceName: serviceName,
      tableName: tableName,
      shiftLabel: shiftLabel,
      items: items,
      payments: payments,
      linkedReturns: linkedReturns,
    );
  }

  Future<ControlPanelSalesReturnDetailData> loadReturnDetail(
    int returnLocalId,
  ) async {
    final salesReturn =
        await (_db.select(_db.salesReturns)
              ..where((t) => t.localId.equals(returnLocalId))
              ..limit(1))
            .getSingle();

    final originalSale = salesReturn.originalSaleLocalId == null
        ? null
        : await (_db.select(_db.sales)
                ..where(
                  (t) => t.localId.equals(salesReturn.originalSaleLocalId!),
                )
                ..limit(1))
              .getSingleOrNull();
    final originalInvoiceNo = _resolveInvoiceNo(
      originalSale?.invoiceNo,
      originalSale?.localId,
      fallback: salesReturn.originalSaleLocalId,
    );
    final originalCustomerName = originalSale == null
        ? 'عميل غير محدد'
        : await _resolveCustomerName(originalSale.customerId);
    final shiftLabel = await _resolveShiftLabel(salesReturn.shiftLocalId);
    final items =
        await (_db.select(_db.salesReturnItems)
              ..where((t) => t.returnLocalId.equals(returnLocalId))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
            .get();

    return ControlPanelSalesReturnDetailData(
      salesReturn: salesReturn,
      originalSale: originalSale,
      originalInvoiceNo: originalInvoiceNo,
      originalCustomerName: originalCustomerName,
      shiftLabel: shiftLabel,
      items: items,
    );
  }

  Future<SalesDashboardData> _loadSalesDashboard({
    required SalesListingKind kind,
    required DateTime fromDate,
    required DateTime toDate,
    required String searchQuery,
  }) async {
    final start = _startOfDay(fromDate);
    final endExclusive = _endExclusiveOfDay(toDate);
    final query = _db.select(_db.sales)
      ..where((t) => t.createdAt.isBiggerOrEqualValue(start))
      ..where((t) => t.createdAt.isSmallerThanValue(endExclusive))
      ..orderBy([
        (t) => drift.OrderingTerm(
          expression: t.createdAt,
          mode: drift.OrderingMode.desc,
        ),
        (t) => drift.OrderingTerm(
          expression: t.localId,
          mode: drift.OrderingMode.desc,
        ),
      ]);

    switch (kind) {
      case SalesListingKind.allSales:
        query.where((t) => t.status.isNotIn(const ['QUOTATION', 'quotation']));
        break;
      case SalesListingKind.creditSales:
        query.where(
          (t) =>
              t.status.isNotIn(const ['QUOTATION', 'quotation']) &
              t.remaining.isBiggerThanValue(0.01),
        );
        break;
      case SalesListingKind.quotations:
        query.where(
          (t) => t.status.equals('QUOTATION') | t.status.equals('quotation'),
        );
        break;
      case SalesListingKind.salesReturns:
        break;
    }

    final sales = await query.get();
    final salesRows = await _buildSaleRows(sales);
    final filteredRows = _filterSaleRows(salesRows, searchQuery);

    return SalesDashboardData(
      kind: kind,
      fromDate: start,
      toDate: _startOfDay(toDate),
      searchQuery: searchQuery,
      invoiceCount: filteredRows.length,
      itemsCount: filteredRows.fold<int>(
        0,
        (sum, row) => sum + row.sale.itemsCount,
      ),
      totalAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.sale.total,
      ),
      paidAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.sale.paidTotal,
      ),
      remainingAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.sale.remaining,
      ),
      returnsAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.returnedTotal,
      ),
      salesRows: filteredRows,
      returnRows: const [],
    );
  }

  Future<SalesDashboardData> _loadReturnsDashboard({
    required DateTime fromDate,
    required DateTime toDate,
    required String searchQuery,
  }) async {
    final start = _startOfDay(fromDate);
    final endExclusive = _endExclusiveOfDay(toDate);
    final returns =
        await (_db.select(_db.salesReturns)
              ..where((t) => t.createdAt.isBiggerOrEqualValue(start))
              ..where((t) => t.createdAt.isSmallerThanValue(endExclusive))
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.createdAt,
                  mode: drift.OrderingMode.desc,
                ),
                (t) => drift.OrderingTerm(
                  expression: t.localId,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    final returnRows = await _buildReturnRows(returns);
    final filteredRows = _filterReturnRows(returnRows, searchQuery);

    return SalesDashboardData(
      kind: SalesListingKind.salesReturns,
      fromDate: start,
      toDate: _startOfDay(toDate),
      searchQuery: searchQuery,
      invoiceCount: filteredRows.length,
      itemsCount: filteredRows.fold<int>(0, (sum, row) => sum + row.itemsCount),
      totalAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.salesReturn.total,
      ),
      paidAmount: 0,
      remainingAmount: 0,
      returnsAmount: filteredRows.fold<double>(
        0,
        (sum, row) => sum + row.salesReturn.total,
      ),
      salesRows: const [],
      returnRows: filteredRows,
    );
  }

  Future<List<ControlPanelSaleRow>> _buildSaleRows(List<SaleDb> sales) async {
    if (sales.isEmpty) return const [];

    final customerIds = sales.map((e) => e.customerId).whereType<int>().toSet();
    final serviceIds = sales.map((e) => e.serviceId).whereType<int>().toSet();
    final tableIds = sales.map((e) => e.tableId).whereType<int>().toSet();
    final shiftIds = sales.map((e) => e.shiftLocalId).whereType<int>().toSet();
    final saleIds = sales.map((e) => e.localId).toList(growable: false);

    final customers = customerIds.isEmpty
        ? const <CustomerDb>[]
        : await (_db.select(
            _db.customers,
          )..where((t) => t.id.isIn(customerIds))).get();
    final services = serviceIds.isEmpty
        ? const <ServiceDb>[]
        : await (_db.select(
            _db.services,
          )..where((t) => t.id.isIn(serviceIds))).get();
    final tables = tableIds.isEmpty
        ? const <PosTableDb>[]
        : await (_db.select(
            _db.posTables,
          )..where((t) => t.id.isIn(tableIds))).get();
    final shifts = shiftIds.isEmpty
        ? const <ShiftDb>[]
        : await (_db.select(
            _db.shifts,
          )..where((t) => t.localId.isIn(shiftIds))).get();
    final linkedReturns = saleIds.isEmpty
        ? const <SalesReturnDb>[]
        : await (_db.select(
            _db.salesReturns,
          )..where((t) => t.originalSaleLocalId.isIn(saleIds))).get();

    final customerNamesById = {
      for (final customer in customers)
        customer.id: _normalizePartyName(customer.name),
    };
    final serviceNamesById = {
      for (final service in services) service.id: service.name.trim(),
    };
    final tableNamesById = {
      for (final table in tables) table.id: table.name.trim(),
    };
    final shiftLabelsById = {
      for (final shift in shifts) shift.localId: _resolveShiftNo(shift),
    };

    final returnsCountBySaleId = <int, int>{};
    final returnsTotalBySaleId = <int, double>{};
    for (final salesReturn in linkedReturns) {
      final originalSaleId = salesReturn.originalSaleLocalId;
      if (originalSaleId == null) continue;
      returnsCountBySaleId[originalSaleId] =
          (returnsCountBySaleId[originalSaleId] ?? 0) + 1;
      returnsTotalBySaleId[originalSaleId] =
          (returnsTotalBySaleId[originalSaleId] ?? 0) + salesReturn.total;
    }

    return sales
        .map(
          (sale) => ControlPanelSaleRow(
            sale: sale,
            customerName: sale.customerId == null
                ? 'عميل عام'
                : (customerNamesById[sale.customerId] ??
                      'عميل #${sale.customerId}'),
            serviceName: sale.serviceNameSnapshot?.trim().isNotEmpty == true
                ? sale.serviceNameSnapshot!.trim()
                : (sale.serviceId == null
                      ? ''
                      : (serviceNamesById[sale.serviceId] ?? '')),
            tableName: sale.tableNameSnapshot?.trim().isNotEmpty == true
                ? sale.tableNameSnapshot!.trim()
                : (sale.tableId == null
                      ? ''
                      : (tableNamesById[sale.tableId] ?? '')),
            shiftLabel: sale.shiftLocalId == null
                ? 'بدون وردية'
                : (shiftLabelsById[sale.shiftLocalId] ??
                      'وردية #${sale.shiftLocalId}'),
            returnsCount: returnsCountBySaleId[sale.localId] ?? 0,
            returnedTotal: returnsTotalBySaleId[sale.localId] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ControlPanelSalesReturnRow>> _buildReturnRows(
    List<SalesReturnDb> returns,
  ) async {
    if (returns.isEmpty) return const [];

    final originalSaleIds = returns
        .map((e) => e.originalSaleLocalId)
        .whereType<int>()
        .toSet();
    final shiftIds = returns
        .map((e) => e.shiftLocalId)
        .whereType<int>()
        .toSet();
    final returnIds = returns.map((e) => e.localId).toList(growable: false);

    final originalSales = originalSaleIds.isEmpty
        ? const <SaleDb>[]
        : await (_db.select(
            _db.sales,
          )..where((t) => t.localId.isIn(originalSaleIds))).get();
    final shifts = shiftIds.isEmpty
        ? const <ShiftDb>[]
        : await (_db.select(
            _db.shifts,
          )..where((t) => t.localId.isIn(shiftIds))).get();
    final returnItems = returnIds.isEmpty
        ? const <SalesReturnItemDb>[]
        : await (_db.select(
            _db.salesReturnItems,
          )..where((t) => t.returnLocalId.isIn(returnIds))).get();

    final customerIds = originalSales
        .map((e) => e.customerId)
        .whereType<int>()
        .toSet();
    final customers = customerIds.isEmpty
        ? const <CustomerDb>[]
        : await (_db.select(
            _db.customers,
          )..where((t) => t.id.isIn(customerIds))).get();

    final originalSalesById = {
      for (final sale in originalSales) sale.localId: sale,
    };
    final shiftLabelsById = {
      for (final shift in shifts) shift.localId: _resolveShiftNo(shift),
    };
    final customerNamesById = {
      for (final customer in customers)
        customer.id: _normalizePartyName(customer.name),
    };
    final itemsCountByReturnId = <int, int>{};
    for (final item in returnItems) {
      itemsCountByReturnId[item.returnLocalId] =
          (itemsCountByReturnId[item.returnLocalId] ?? 0) + item.qty;
    }

    return returns
        .map((salesReturn) {
          final originalSale = salesReturn.originalSaleLocalId == null
              ? null
              : originalSalesById[salesReturn.originalSaleLocalId!];
          final originalInvoiceNo = _resolveInvoiceNo(
            originalSale?.invoiceNo,
            originalSale?.localId,
            fallback: salesReturn.originalSaleLocalId,
          );
          final originalCustomerName = originalSale?.customerId == null
              ? 'عميل عام'
              : (customerNamesById[originalSale!.customerId] ??
                    'عميل #${originalSale.customerId}');

          return ControlPanelSalesReturnRow(
            salesReturn: salesReturn,
            originalInvoiceNo: originalInvoiceNo,
            shiftLabel: salesReturn.shiftLocalId == null
                ? 'بدون وردية'
                : (shiftLabelsById[salesReturn.shiftLocalId] ??
                      'وردية #${salesReturn.shiftLocalId}'),
            itemsCount: itemsCountByReturnId[salesReturn.localId] ?? 0,
            originalCustomerName: originalCustomerName,
          );
        })
        .toList(growable: false);
  }

  List<ControlPanelSaleRow> _filterSaleRows(
    List<ControlPanelSaleRow> rows,
    String searchQuery,
  ) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return rows;

    return rows
        .where((row) {
          final sale = row.sale;
          return _contains(row.customerName, normalizedQuery) ||
              _contains(row.serviceName, normalizedQuery) ||
              _contains(row.tableName, normalizedQuery) ||
              _contains(row.shiftLabel, normalizedQuery) ||
              _contains(sale.invoiceNo, normalizedQuery) ||
              _contains(sale.dailyOrderNo.toString(), normalizedQuery) ||
              _contains(sale.localId.toString(), normalizedQuery) ||
              _contains(sale.note, normalizedQuery) ||
              _contains(sale.status, normalizedQuery);
        })
        .toList(growable: false);
  }

  List<ControlPanelSalesReturnRow> _filterReturnRows(
    List<ControlPanelSalesReturnRow> rows,
    String searchQuery,
  ) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return rows;

    return rows
        .where((row) {
          final salesReturn = row.salesReturn;
          return _contains(row.originalInvoiceNo, normalizedQuery) ||
              _contains(row.originalCustomerName, normalizedQuery) ||
              _contains(row.shiftLabel, normalizedQuery) ||
              _contains(salesReturn.returnNo, normalizedQuery) ||
              _contains(salesReturn.localId.toString(), normalizedQuery) ||
              _contains(salesReturn.reason, normalizedQuery) ||
              _contains(salesReturn.status, normalizedQuery);
        })
        .toList(growable: false);
  }

  Future<String> _resolveCustomerName(int? customerId) async {
    if (customerId == null) return 'عميل عام';
    final customer =
        await (_db.select(_db.customers)
              ..where((t) => t.id.equals(customerId))
              ..limit(1))
            .getSingleOrNull();
    if (customer == null) return 'عميل #$customerId';
    return _normalizePartyName(customer.name);
  }

  Future<String> _resolveServiceName(
    int? serviceId,
    String? serviceSnapshot,
  ) async {
    final snapshot = serviceSnapshot?.trim() ?? '';
    if (snapshot.isNotEmpty) return snapshot;
    if (serviceId == null) return '';
    final service =
        await (_db.select(_db.services)
              ..where((t) => t.id.equals(serviceId))
              ..limit(1))
            .getSingleOrNull();
    return service?.name.trim() ?? '';
  }

  Future<String> _resolveTableName(int? tableId, String? tableSnapshot) async {
    final snapshot = tableSnapshot?.trim() ?? '';
    if (snapshot.isNotEmpty) return snapshot;
    if (tableId == null) return '';
    final table =
        await (_db.select(_db.posTables)
              ..where((t) => t.id.equals(tableId))
              ..limit(1))
            .getSingleOrNull();
    return table?.name.trim() ?? '';
  }

  Future<String> _resolveShiftLabel(int? shiftLocalId) async {
    if (shiftLocalId == null) return 'بدون وردية';
    final shift =
        await (_db.select(_db.shifts)
              ..where((t) => t.localId.equals(shiftLocalId))
              ..limit(1))
            .getSingleOrNull();
    if (shift == null) return 'وردية #$shiftLocalId';
    return _resolveShiftNo(shift);
  }

  String _resolveShiftNo(ShiftDb shift) {
    final shiftNo = shift.shiftNo?.trim() ?? '';
    if (shiftNo.isNotEmpty) return shiftNo;
    return 'وردية #${shift.localId}';
  }

  String _resolveInvoiceNo(String? invoiceNo, int? localId, {int? fallback}) {
    final normalized = invoiceNo?.trim() ?? '';
    if (normalized.isNotEmpty) return normalized;
    if (localId != null) return '#$localId';
    if (fallback != null) return '#$fallback';
    return '-';
  }

  String _normalizePartyName(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? 'غير محدد' : normalized;
  }

  bool _contains(String? source, String query) {
    return (source ?? '').trim().toLowerCase().contains(query);
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endExclusiveOfDay(DateTime value) {
    return _startOfDay(value).add(const Duration(days: 1));
  }
}
