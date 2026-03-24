import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';

final cashVoucherServiceProvider = Provider<CashVoucherService>((ref) {
  return CashVoucherService(ref.watch(appDbProvider));
});

class CashVoucherService {
  CashVoucherService(this._db);

  final AppDb _db;

  static const String statusActive = 'ACTIVE';
  static const String statusVoid = 'VOID';

  Stream<List<ReceiptVoucherDb>> watchReceiptVouchers({
    bool includeHidden = false,
  }) {
    final query = _db.select(_db.receiptVouchers);
    if (!includeHidden) {
      query.where((t) => t.isDeleted.equals(false));
    }
    query.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.createdAt,
        mode: drift.OrderingMode.desc,
      ),
      (t) => drift.OrderingTerm(
        expression: t.localId,
        mode: drift.OrderingMode.desc,
      ),
    ]);
    return query.watch();
  }

  Stream<List<PaymentVoucherDb>> watchPaymentVouchers({
    bool includeHidden = false,
  }) {
    final query = _db.select(_db.paymentVouchers);
    if (!includeHidden) {
      query.where((t) => t.isDeleted.equals(false));
    }
    query.orderBy([
      (t) => drift.OrderingTerm(
        expression: t.createdAt,
        mode: drift.OrderingMode.desc,
      ),
      (t) => drift.OrderingTerm(
        expression: t.localId,
        mode: drift.OrderingMode.desc,
      ),
    ]);
    return query.watch();
  }

  Future<int> createReceiptVoucher({
    required double amount,
    required String paymentMethodCode,
    int? customerId,
    String? customerName,
    String? reference,
    String? note,
    String status = statusActive,
    DateTime? createdAt,
  }) async {
    final safeAmount = _normalizeAmount(amount);
    if (safeAmount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }

    final created = createdAt ?? DateTime.now();
    final context = await _resolveShiftContext();
    final voucherNo = await _nextVoucherNo(prefix: 'RCV', createdAt: created);
    final normalizedCustomerName = _nullIfEmpty(customerName);

    return _db
        .into(_db.receiptVouchers)
        .insert(
          ReceiptVouchersCompanion.insert(
            uuid: const Uuid().v4(),
            voucherNo: drift.Value(voucherNo),
            shiftLocalId: drift.Value(context.shiftLocalId),
            branchServerId: drift.Value(context.branchServerId),
            cashierServerId: drift.Value(context.cashierServerId),
            customerId: drift.Value(customerId),
            customerName: drift.Value(normalizedCustomerName),
            amount: safeAmount,
            paymentMethodCode: drift.Value(
              paymentMethodCode.trim().toUpperCase(),
            ),
            reference: drift.Value(_nullIfEmpty(reference)),
            note: drift.Value(_nullIfEmpty(note)),
            status: drift.Value(_normalizeStatus(status)),
            syncStatus: const drift.Value('PENDING'),
            createdAt: drift.Value(created),
            updatedAtLocal: drift.Value(DateTime.now()),
            isDeleted: const drift.Value(false),
          ),
        );
  }

  Future<void> updateReceiptVoucher({
    required int localId,
    required double amount,
    required String paymentMethodCode,
    int? customerId,
    String? customerName,
    String? reference,
    String? note,
    required String status,
    required DateTime createdAt,
  }) async {
    final safeAmount = _normalizeAmount(amount);
    if (safeAmount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }

    await (_db.update(
      _db.receiptVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      ReceiptVouchersCompanion(
        customerId: drift.Value(customerId),
        customerName: drift.Value(_nullIfEmpty(customerName)),
        amount: drift.Value(safeAmount),
        paymentMethodCode: drift.Value(paymentMethodCode.trim().toUpperCase()),
        reference: drift.Value(_nullIfEmpty(reference)),
        note: drift.Value(_nullIfEmpty(note)),
        status: drift.Value(_normalizeStatus(status)),
        syncStatus: const drift.Value('PENDING'),
        createdAt: drift.Value(createdAt),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> createPaymentVoucher({
    required double amount,
    required String expenseType,
    String? reference,
    String? note,
    String status = statusActive,
    DateTime? createdAt,
  }) async {
    final safeAmount = _normalizeAmount(amount);
    if (safeAmount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }
    final normalizedExpenseType = expenseType.trim();
    if (normalizedExpenseType.isEmpty) {
      throw Exception('الجهة أو الغرض مطلوب');
    }

    final created = createdAt ?? DateTime.now();
    final context = await _resolveShiftContext();
    final voucherNo = await _nextVoucherNo(prefix: 'PAY', createdAt: created);

    await _db
        .into(_db.paymentVouchers)
        .insert(
          PaymentVouchersCompanion.insert(
            uuid: const Uuid().v4(),
            voucherNo: drift.Value(voucherNo),
            shiftLocalId: drift.Value(context.shiftLocalId),
            branchServerId: drift.Value(context.branchServerId),
            cashierServerId: drift.Value(context.cashierServerId),
            amount: safeAmount,
            expenseType: drift.Value(normalizedExpenseType),
            reference: drift.Value(_nullIfEmpty(reference)),
            note: drift.Value(_nullIfEmpty(note)),
            status: drift.Value(_normalizeStatus(status)),
            syncStatus: const drift.Value('PENDING'),
            createdAt: drift.Value(created),
            updatedAtLocal: drift.Value(DateTime.now()),
            isDeleted: const drift.Value(false),
          ),
        );
  }

  Future<void> updatePaymentVoucher({
    required int localId,
    required double amount,
    required String expenseType,
    String? reference,
    String? note,
    required String status,
    required DateTime createdAt,
  }) async {
    final safeAmount = _normalizeAmount(amount);
    if (safeAmount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }
    final normalizedExpenseType = expenseType.trim();
    if (normalizedExpenseType.isEmpty) {
      throw Exception('الجهة أو الغرض مطلوب');
    }

    await (_db.update(
      _db.paymentVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      PaymentVouchersCompanion(
        amount: drift.Value(safeAmount),
        expenseType: drift.Value(normalizedExpenseType),
        reference: drift.Value(_nullIfEmpty(reference)),
        note: drift.Value(_nullIfEmpty(note)),
        status: drift.Value(_normalizeStatus(status)),
        syncStatus: const drift.Value('PENDING'),
        createdAt: drift.Value(createdAt),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> setReceiptVoucherHidden(int localId, bool hidden) {
    return (_db.update(
      _db.receiptVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      ReceiptVouchersCompanion(
        isDeleted: drift.Value(hidden),
        syncStatus: const drift.Value('PENDING'),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPaymentVoucherHidden(int localId, bool hidden) {
    return (_db.update(
      _db.paymentVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      PaymentVouchersCompanion(
        isDeleted: drift.Value(hidden),
        syncStatus: const drift.Value('PENDING'),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> setReceiptVoucherStatus(int localId, String status) {
    return (_db.update(
      _db.receiptVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      ReceiptVouchersCompanion(
        status: drift.Value(_normalizeStatus(status)),
        syncStatus: const drift.Value('PENDING'),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPaymentVoucherStatus(int localId, String status) {
    return (_db.update(
      _db.paymentVouchers,
    )..where((t) => t.localId.equals(localId))).write(
      PaymentVouchersCompanion(
        status: drift.Value(_normalizeStatus(status)),
        syncStatus: const drift.Value('PENDING'),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteReceiptVoucher(int localId) {
    return (_db.delete(
      _db.receiptVouchers,
    )..where((t) => t.localId.equals(localId))).go();
  }

  Future<void> deletePaymentVoucher(int localId) {
    return (_db.delete(
      _db.paymentVouchers,
    )..where((t) => t.localId.equals(localId))).go();
  }

  Future<List<CashMovementEntry>> getCashMovements({
    DateTime? from,
    DateTime? to,
    bool includeHidden = true,
    bool includeVoided = true,
    String query = '',
  }) async {
    final receiptQuery = _db.select(_db.receiptVouchers);
    if (!includeHidden) {
      receiptQuery.where((t) => t.isDeleted.equals(false));
    }
    if (from != null) {
      receiptQuery.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      receiptQuery.where((t) => t.createdAt.isSmallerOrEqualValue(to));
    }
    final receiptRows = await receiptQuery.get();

    final paymentQuery = _db.select(_db.paymentVouchers);
    if (!includeHidden) {
      paymentQuery.where((t) => t.isDeleted.equals(false));
    }
    if (from != null) {
      paymentQuery.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      paymentQuery.where((t) => t.createdAt.isSmallerOrEqualValue(to));
    }
    final paymentRows = await paymentQuery.get();

    final normalizedQuery = query.trim().toLowerCase();
    final entries = <CashMovementEntry>[
      ...receiptRows.map((row) {
        return CashMovementEntry(
          id: row.localId,
          direction: CashMovementDirection.incoming,
          source: 'سند قبض',
          voucherNo: row.voucherNo ?? '-',
          description: row.note?.trim().isNotEmpty == true
              ? row.note!.trim()
              : (row.reference?.trim().isNotEmpty == true
                    ? row.reference!.trim()
                    : 'تحصيل نقدي'),
          paymentMethodCode: row.paymentMethodCode,
          createdAt: row.createdAt,
          status: row.status,
          amount: row.amount,
          isHidden: row.isDeleted,
          affectsBalance:
              !row.isDeleted && _isFinancialStatusActive(row.status),
        );
      }),
      ...paymentRows.map((row) {
        final purpose = row.expenseType.trim().isEmpty
            ? 'مصروف'
            : row.expenseType.trim();
        return CashMovementEntry(
          id: row.localId,
          direction: CashMovementDirection.outgoing,
          source: 'سند صرف',
          voucherNo: row.voucherNo ?? '-',
          description: row.note?.trim().isNotEmpty == true
              ? '$purpose - ${row.note!.trim()}'
              : purpose,
          paymentMethodCode: '',
          createdAt: row.createdAt,
          status: row.status,
          amount: row.amount,
          isHidden: row.isDeleted,
          affectsBalance:
              !row.isDeleted && _isFinancialStatusActive(row.status),
        );
      }),
    ];

    final filtered =
        entries.where((entry) {
          if (!includeVoided && !_isFinancialStatusActive(entry.status)) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return entry.voucherNo.toLowerCase().contains(normalizedQuery) ||
              entry.description.toLowerCase().contains(normalizedQuery) ||
              entry.source.toLowerCase().contains(normalizedQuery);
        }).toList()..sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          if (byDate != 0) return byDate;
          return b.id.compareTo(a.id);
        });

    return filtered;
  }

  Future<CashMovementSummary> getMovementSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final entries = await getCashMovements(
      from: from,
      to: to,
      includeHidden: false,
      includeVoided: true,
      query: '',
    );

    var incoming = 0.0;
    var outgoing = 0.0;

    for (final entry in entries) {
      if (!entry.affectsBalance) continue;
      if (entry.direction == CashMovementDirection.incoming) {
        incoming += entry.amount;
      } else {
        outgoing += entry.amount;
      }
    }

    final roundedIn = _round2(incoming);
    final roundedOut = _round2(outgoing);
    return CashMovementSummary(
      totalIncoming: roundedIn,
      totalOutgoing: roundedOut,
      net: _round2(roundedIn - roundedOut),
    );
  }

  Future<List<CustomerDb>> getCustomers() {
    return (_db.select(
      _db.customers,
    )..orderBy([(t) => drift.OrderingTerm(expression: t.name)])).get();
  }

  Future<String> _nextVoucherNo({
    required String prefix,
    required DateTime createdAt,
  }) async {
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final end = start.add(const Duration(days: 1));
    final datePart =
        '${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}${createdAt.day.toString().padLeft(2, '0')}';

    int sequence;
    if (prefix == 'RCV') {
      final rows =
          await (_db.select(_db.receiptVouchers)..where(
                (t) =>
                    t.createdAt.isBiggerOrEqualValue(start) &
                    t.createdAt.isSmallerThanValue(end),
              ))
              .get();
      sequence = rows.length + 1;
    } else {
      final rows =
          await (_db.select(_db.paymentVouchers)..where(
                (t) =>
                    t.createdAt.isBiggerOrEqualValue(start) &
                    t.createdAt.isSmallerThanValue(end),
              ))
              .get();
      sequence = rows.length + 1;
    }

    return '$prefix-$datePart-${sequence.toString().padLeft(4, '0')}';
  }

  Future<_ShiftContext> _resolveShiftContext() async {
    final raw = (await _db.getSetting('current_shift_local_id'))?.trim();
    final shiftId = int.tryParse(raw ?? '');
    if (shiftId == null || shiftId <= 0) return const _ShiftContext();

    final shift = await (_db.select(
      _db.shifts,
    )..where((t) => t.localId.equals(shiftId))).getSingleOrNull();
    if (shift == null) return const _ShiftContext();

    final isOpen =
        shift.status.trim().toLowerCase() == 'open' && shift.closedAt == null;
    if (!isOpen) return const _ShiftContext();

    return _ShiftContext(
      shiftLocalId: shift.localId,
      branchServerId: shift.branchServerId,
      cashierServerId: shift.cashierServerId,
    );
  }

  bool _isFinancialStatusActive(String status) {
    final value = status.trim().toUpperCase();
    if (value.isEmpty) return true;
    return value != 'VOID' &&
        value != 'CANCELLED' &&
        value != 'CANCELED' &&
        value != 'DELETED';
  }

  String _normalizeStatus(String status) {
    final value = status.trim().toUpperCase();
    return value.isEmpty ? statusActive : value;
  }

  String? _nullIfEmpty(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  double _normalizeAmount(double amount) {
    return _round2(amount < 0 ? 0 : amount);
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class CashMovementSummary {
  const CashMovementSummary({
    required this.totalIncoming,
    required this.totalOutgoing,
    required this.net,
  });

  final double totalIncoming;
  final double totalOutgoing;
  final double net;
}

enum CashMovementDirection { incoming, outgoing }

class CashMovementEntry {
  const CashMovementEntry({
    required this.id,
    required this.direction,
    required this.source,
    required this.voucherNo,
    required this.description,
    required this.paymentMethodCode,
    required this.createdAt,
    required this.status,
    required this.amount,
    required this.isHidden,
    required this.affectsBalance,
  });

  final int id;
  final CashMovementDirection direction;
  final String source;
  final String voucherNo;
  final String description;
  final String paymentMethodCode;
  final DateTime createdAt;
  final String status;
  final double amount;
  final bool isHidden;
  final bool affectsBalance;
}

class _ShiftContext {
  const _ShiftContext({
    this.shiftLocalId,
    this.branchServerId,
    this.cashierServerId,
  });

  final int? shiftLocalId;
  final int? branchServerId;
  final int? cashierServerId;
}
