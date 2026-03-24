import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../control_panel/cash_management/data/cash_voucher_service.dart';

final creditSettlementServiceProvider = Provider<CreditSettlementService>((
  ref,
) {
  return CreditSettlementService(
    ref.watch(appDbProvider),
    ref.watch(cashVoucherServiceProvider),
  );
});

class CreditSettlementResult {
  const CreditSettlementResult({
    required this.saleLocalId,
    required this.paidAmount,
    required this.paidTotal,
    required this.remaining,
    required this.status,
    required this.receiptVoucherLocalId,
  });

  final int saleLocalId;
  final double paidAmount;
  final double paidTotal;
  final double remaining;
  final String status;
  final int receiptVoucherLocalId;
}

class CreditSettlementService {
  CreditSettlementService(this._db, this._cashVoucherService);

  final AppDb _db;
  final CashVoucherService _cashVoucherService;

  Future<CreditSettlementResult> settleSale({
    required SaleDb sale,
    required double amount,
    required String paymentMethodCode,
    String? note,
    DateTime? paidAt,
  }) async {
    final safeAmount = _round2(amount);
    if (safeAmount <= 0) {
      throw Exception('مبلغ السداد يجب أن يكون أكبر من صفر');
    }

    final remainingBefore = _round2(sale.remaining);
    if (remainingBefore <= 0.01) {
      throw Exception('هذه الفاتورة لا تحتوي على رصيد أجل متبقٍ');
    }

    if (safeAmount - remainingBefore > 0.01) {
      throw Exception('مبلغ السداد أكبر من المتبقي على الفاتورة');
    }

    final paymentCode = paymentMethodCode.trim().toUpperCase();
    if (paymentCode.isEmpty || paymentCode == 'CREDIT') {
      throw Exception('اختر طريقة دفع فعلية لسداد الأجل');
    }

    final createdAt = paidAt ?? DateTime.now();
    final reference = 'SALE:${sale.invoiceNo ?? sale.localId}';
    final settlementNote = _buildSettlementNote(sale, note);

    final result = await _db.transaction(() async {
      final newPaidTotal = _round2(sale.paidTotal + safeAmount);
      final newRemaining = _round2(sale.total - newPaidTotal);
      final normalizedRemaining = newRemaining <= 0.01 ? 0.0 : newRemaining;
      final nextStatus = normalizedRemaining <= 0.01 ? 'completed' : 'partial';
      final nextSyncStatus = sale.serverSaleId == null
          ? 'PENDING'
          : sale.syncStatus;

      await _db
          .into(_db.salePayments)
          .insert(
            SalePaymentsCompanion.insert(
              saleLocalId: sale.localId,
              methodCode: paymentCode,
              amount: safeAmount,
              reference: drift.Value(reference),
              note: drift.Value(settlementNote),
            ),
          );

      await (_db.update(
        _db.sales,
      )..where((t) => t.localId.equals(sale.localId))).write(
        SalesCompanion(
          paidTotal: drift.Value(newPaidTotal),
          remaining: drift.Value(normalizedRemaining),
          status: drift.Value(nextStatus),
          completedAtLocal: drift.Value(
            normalizedRemaining <= 0.01 ? createdAt : null,
          ),
          syncStatus: drift.Value(nextSyncStatus),
        ),
      );

      final receiptVoucherLocalId = await _cashVoucherService
          .createReceiptVoucher(
            amount: safeAmount,
            paymentMethodCode: paymentCode,
            customerId: sale.customerId,
            reference: reference,
            note: settlementNote,
            createdAt: createdAt,
          );

      return CreditSettlementResult(
        saleLocalId: sale.localId,
        paidAmount: safeAmount,
        paidTotal: newPaidTotal,
        remaining: normalizedRemaining,
        status: nextStatus,
        receiptVoucherLocalId: receiptVoucherLocalId,
      );
    });

    if (sale.serverSaleId == null) {
      await _db.enqueueSaleForSync(sale.localId);
    }

    return result;
  }

  String _buildSettlementNote(SaleDb sale, String? note) {
    final invoiceNo = sale.invoiceNo ?? sale.localId.toString();
    final cleanNote = (note ?? '').trim();
    if (cleanNote.isEmpty) {
      return 'سداد أجل للفاتورة رقم $invoiceNo';
    }
    return 'سداد أجل للفاتورة رقم $invoiceNo - $cleanNote';
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
