import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_db.dart';
import '../database/db_provider.dart';

class PosFeatureSettings {
  const PosFeatureSettings({
    required this.showServices,
    required this.showTables,
    required this.showBrands,
    required this.showReceiptVoucher,
    required this.showPaymentVoucher,
    required this.showSalesReturn,
    required this.showExpense,
    required this.printServiceInInvoice,
    required this.printTableInInvoice,
    required this.printCategoryInInvoice,
  });

  final bool showServices;
  final bool showTables;
  final bool showBrands;
  final bool showReceiptVoucher;
  final bool showPaymentVoucher;
  final bool showSalesReturn;
  final bool showExpense;
  final bool printServiceInInvoice;
  final bool printTableInInvoice;
  final bool printCategoryInInvoice;

  static const String showServicesKey = 'pos.show_services';
  static const String showTablesKey = 'pos.show_tables';
  static const String showBrandsKey = 'pos.show_brands';
  static const String showReceiptVoucherKey = 'pos.show_receipt_voucher';
  static const String showPaymentVoucherKey = 'pos.show_payment_voucher';
  static const String showSalesReturnKey = 'pos.show_sales_return';
  static const String showExpenseKey = 'pos.show_expense';
  static const String printServiceInInvoiceKey = 'pos.print_service_in_invoice';
  static const String printTableInInvoiceKey = 'pos.print_table_in_invoice';
  static const String printCategoryInInvoiceKey =
      'pos.print_category_in_invoice';

  static const List<String> allKeys = [
    showServicesKey,
    showTablesKey,
    showBrandsKey,
    showReceiptVoucherKey,
    showPaymentVoucherKey,
    showSalesReturnKey,
    showExpenseKey,
    printServiceInInvoiceKey,
    printTableInInvoiceKey,
    printCategoryInInvoiceKey,
  ];

  static const Map<String, bool> defaultsByKey = {
    showServicesKey: true,
    showTablesKey: true,
    showBrandsKey: true,
    showReceiptVoucherKey: true,
    showPaymentVoucherKey: true,
    showSalesReturnKey: true,
    showExpenseKey: true,
    printServiceInInvoiceKey: true,
    printTableInInvoiceKey: true,
    printCategoryInInvoiceKey: true,
  };

  factory PosFeatureSettings.defaults() {
    return const PosFeatureSettings(
      showServices: true,
      showTables: true,
      showBrands: true,
      showReceiptVoucher: true,
      showPaymentVoucher: true,
      showSalesReturn: true,
      showExpense: true,
      printServiceInInvoice: true,
      printTableInInvoice: true,
      printCategoryInInvoice: true,
    );
  }

  factory PosFeatureSettings.fromMap(Map<String, String?> map) {
    bool readBool(String key) {
      final fallback = defaultsByKey[key] ?? true;
      return _parseBool(map[key], fallback: fallback);
    }

    return PosFeatureSettings(
      showServices: readBool(showServicesKey),
      showTables: readBool(showTablesKey),
      showBrands: readBool(showBrandsKey),
      showReceiptVoucher: readBool(showReceiptVoucherKey),
      showPaymentVoucher: readBool(showPaymentVoucherKey),
      showSalesReturn: readBool(showSalesReturnKey),
      showExpense: readBool(showExpenseKey),
      printServiceInInvoice: readBool(printServiceInInvoiceKey),
      printTableInInvoice: readBool(printTableInInvoiceKey),
      printCategoryInInvoice: readBool(printCategoryInInvoiceKey),
    );
  }

  bool valueForKey(String key) {
    switch (key) {
      case showServicesKey:
        return showServices;
      case showTablesKey:
        return showTables;
      case showBrandsKey:
        return showBrands;
      case showReceiptVoucherKey:
        return showReceiptVoucher;
      case showPaymentVoucherKey:
        return showPaymentVoucher;
      case showSalesReturnKey:
        return showSalesReturn;
      case showExpenseKey:
        return showExpense;
      case printServiceInInvoiceKey:
        return printServiceInInvoice;
      case printTableInInvoiceKey:
        return printTableInInvoice;
      case printCategoryInInvoiceKey:
        return printCategoryInInvoice;
      default:
        return defaultsByKey[key] ?? true;
    }
  }
}

bool _parseBool(String? raw, {required bool fallback}) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return fallback;

  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on' ||
      normalized == 'enabled') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'off' ||
      normalized == 'disabled') {
    return false;
  }
  return fallback;
}

String boolSettingValue(bool value) => value ? '1' : '0';

final posFeatureSettingsProvider =
    StreamProvider.autoDispose<PosFeatureSettings>((ref) {
      final db = ref.watch(appDbProvider);
      return (db.select(db.settings)
            ..where((t) => t.key.isIn(PosFeatureSettings.allKeys)))
          .watch()
          .map((rows) {
            final values = <String, String?>{
              for (final key in PosFeatureSettings.allKeys) key: null,
            };
            for (final row in rows) {
              values[row.key] = row.value;
            }
            return PosFeatureSettings.fromMap(values);
          });
    });

class PosFeatureSettingsActions {
  const PosFeatureSettingsActions(this._db);

  final AppDb _db;

  Future<void> setToggle(String key, bool enabled) async {
    await _db.setSetting(key, boolSettingValue(enabled));
  }
}

final posFeatureSettingsActionsProvider = Provider<PosFeatureSettingsActions>(
  (ref) => PosFeatureSettingsActions(ref.watch(appDbProvider)),
);
