import 'package:flutter/material.dart';
import '../../features/pos/presentation/pos_models.dart';
import '../../features/pos/presentation/widgets/multi_payment_dialog.dart';
import '../../features/pos/presentation/widgets/discount_dialog.dart';
import '../../features/pos/presentation/widgets/sale_comment_dialog.dart';
import '../../features/pos/presentation/widgets/suspended_sales_dialog.dart';
import '../../features/pos/presentation/widgets/delivery_dialog.dart';
import '../../features/pos/presentation/widgets/card_payment_confirm_dialog.dart';
import '../../features/pos/presentation/widgets/expense_dialog.dart';
import '../../features/pos/presentation/widgets/disbursement_voucher_dialog.dart';
import '../../features/pos/presentation/widgets/receipt_voucher_dialog.dart';
import '../../features/pos/presentation/widgets/sales_returns_dialog.dart';
import '../../features/pos/presentation/widgets/shift_details_dialog.dart';

class AppDialogs {
  static Future<T?> showMultiPayment<T>(
    BuildContext context, {
    required PosState state,
    required MultiPaymentCallbacks callbacks,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: MultiPaymentDialog(state: state, callbacks: callbacks),
      ),
    );
  }

  static Future<T?> showDiscount<T>(
    BuildContext context, {
    required DiscountInput initial,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DiscountDialog(initial: initial),
      ),
    );
  }

  static Future<String?> showSaleComment<T>(
    BuildContext context, {
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SaleCommentDialog(initial: initial),
      ),
    );
  }

  static Future<T?> showDelivery<T>(
    BuildContext context, {
    required DeliveryInput initial,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DeliveryDialog(initial: initial),
      ),
    );
  }

  static Future<T?> showSuspendedSales<T>(BuildContext context) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: const SuspendedSalesDialog(),
      ),
    );
  }

  static Future<bool?> showCardPaymentConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CardPaymentConfirmDialog(),
    );
  }

  static Future<void> showExpenseDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ExpenseDialog(),
      ),
    );
  }

  static Future<void> showDisbursementVoucherDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: DisbursementVoucherDialog(),
      ),
    );
  }

  static Future<void> showReceiptVoucherDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ReceiptVoucherDialog(),
      ),
    );
  }

  static Future<void> showSalesReturnsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: SalesReturnsDialog(),
      ),
    );
  }

  static Future<void> showShiftDetailsDialog(
    BuildContext context, {
    ShiftDetailsDialogMode mode = ShiftDetailsDialogMode.details,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftDetailsDialog(mode: mode),
    );
  }

  static Future<void> showShiftCloseDialog(BuildContext context) {
    return showShiftDetailsDialog(
      context,
      mode: ShiftDetailsDialogMode.closeShift,
    );
  }

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'نعم',
    String cancelText = 'لا',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.only(
            top: 40,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          title: Text(title, textAlign: TextAlign.right),
          content: Text(message, textAlign: TextAlign.right),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }
}
