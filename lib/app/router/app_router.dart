import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/control_panel/database/presentation/control_panel_database_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_settings_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_sync_settings_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_invoice_settings_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_services_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_tables_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_brands_screen.dart';
import '../../features/control_panel/settings/presentation/control_panel_addons_screen.dart';
import '../../features/control_panel/printers/presentation/control_panel_printers_screen.dart';
import '../../features/control_panel/shifts/presentation/control_panel_shift_create_screen.dart';
import '../../features/control_panel/shifts/presentation/control_panel_shift_settings_screen.dart';
import '../../features/control_panel/products/presentation/control_panel_add_product_screen.dart';
import '../../features/control_panel/products/presentation/control_panel_add_category_screen.dart';
import '../../features/control_panel/reports/presentation/control_panel_reports_screen.dart';
import '../../features/control_panel/cash_management/presentation/control_panel_cash_receipts_screen.dart';
import '../../features/control_panel/cash_management/presentation/control_panel_cash_payments_screen.dart';
import '../../features/control_panel/cash_management/presentation/control_panel_cash_expenses_screen.dart';
import '../../features/control_panel/cash_management/presentation/control_panel_cash_movements_screen.dart';
import '../../features/control_panel/sales/presentation/control_panel_sales_screen.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute(builder: (_) => const SplashScreen());
    case AppRoutes.pos:
      return MaterialPageRoute(builder: (_) => const PosScreen());
    case AppRoutes.controlPanelDatabase:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelDatabaseScreen(),
      );
    case AppRoutes.controlPanelSettings:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSettingsScreen(),
      );
    case AppRoutes.controlPanelSettingsSync:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSyncSettingsScreen(),
      );
    case AppRoutes.controlPanelSettingsServices:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelServicesScreen(),
      );
    case AppRoutes.controlPanelSettingsTables:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelTablesScreen(),
      );
    case AppRoutes.controlPanelSettingsAddons:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelAddonsScreen(),
      );
    case AppRoutes.controlPanelProductsBrands:
    case AppRoutes.controlPanelSettingsBrands:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelBrandsScreen(),
      );
    case AppRoutes.controlPanelInvoiceSettings:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelInvoiceSettingsScreen(),
      );
    case AppRoutes.controlPanelPrinters:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelPrintersScreen(),
      );
    case AppRoutes.controlPanelPrintersStations:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelPrintersScreen.stations(),
      );
    case AppRoutes.controlPanelPrintersAdd:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelPrintersScreen.addPrinter(),
      );
    case AppRoutes.controlPanelPrintersList:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelPrintersScreen.addedPrinters(),
      );
    case AppRoutes.controlPanelShiftSettings:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelShiftSettingsScreen(),
      );
    case AppRoutes.controlPanelShiftCreate:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelShiftCreateScreen(),
      );
    case AppRoutes.controlPanelCashReceipts:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelCashReceiptsScreen(),
      );
    case AppRoutes.controlPanelCashPayments:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelCashPaymentsScreen(),
      );
    case AppRoutes.controlPanelCashExpenses:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelCashExpensesScreen(),
      );
    case AppRoutes.controlPanelCashMovements:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelCashMovementsScreen(),
      );
    case AppRoutes.controlPanelSalesAll:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSalesScreen.all(),
      );
    case AppRoutes.controlPanelSalesReturns:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSalesScreen.returns(),
      );
    case AppRoutes.controlPanelSalesCredit:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSalesScreen.credit(),
      );
    case AppRoutes.controlPanelSalesQuotations:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelSalesScreen.quotations(),
      );
    case AppRoutes.controlPanelReportsOverview:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelReportsScreen.overview(),
      );
    case AppRoutes.controlPanelReportsSales:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelReportsScreen.sales(),
      );
    case AppRoutes.controlPanelReportsInventory:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelReportsScreen.inventory(),
      );
    case AppRoutes.controlPanelReportsShifts:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelReportsScreen.shifts(),
      );
    case AppRoutes.controlPanelReportsCash:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelReportsScreen.cash(),
      );
    case AppRoutes.controlPanelAddProduct:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelAddProductScreen(),
      );
    case AppRoutes.controlPanelAddCategory:
      return MaterialPageRoute(
        builder: (_) => const ControlPanelAddCategoryScreen(),
      );
    case AppRoutes.login:
    default:
      return MaterialPageRoute(builder: (_) => const LoginScreen());
  }
}
