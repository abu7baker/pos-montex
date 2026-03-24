import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import 'widgets/control_drawer.dart';

enum ControlPanelSection {
  settings,
  settingsSync,
  settingsServices,
  settingsTables,
  settingsAddons,
  productsBrands,
  settingsInvoices,
  database,
  printers,
  printersStations,
  printersAdd,
  printersList,
  shiftSettings,
  shiftCreate,
  cashReceipts,
  cashPayments,
  cashExpenses,
  cashMovements,
  salesAll,
  salesReturns,
  salesCredit,
  salesQuotations,
  reportsOverview,
  reportsSales,
  reportsInventory,
  reportsShifts,
  reportsCash,
  productsAdd,
  productsCategoryAdd,
}

class ControlPanelShell extends StatelessWidget {
  const ControlPanelShell({
    super.key,
    required this.section,
    required this.child,
  });

  final ControlPanelSection section;
  final Widget child;

  void _navigate(BuildContext context, ControlPanelSection target) {
    Navigator.pop(context);
    if (target == section) return;
    final route = _routeFor(target);
    if (route == null) return;
    Navigator.pushReplacementNamed(context, route);
  }

  String? _routeFor(ControlPanelSection target) {
    switch (target) {
      case ControlPanelSection.database:
        return AppRoutes.controlPanelDatabase;
      case ControlPanelSection.settings:
        return AppRoutes.controlPanelSettings;
      case ControlPanelSection.settingsSync:
        return AppRoutes.controlPanelSettingsSync;
      case ControlPanelSection.settingsServices:
        return AppRoutes.controlPanelSettingsServices;
      case ControlPanelSection.settingsTables:
        return AppRoutes.controlPanelSettingsTables;
      case ControlPanelSection.settingsAddons:
        return AppRoutes.controlPanelSettingsAddons;
      case ControlPanelSection.productsBrands:
        return AppRoutes.controlPanelProductsBrands;
      case ControlPanelSection.settingsInvoices:
        return AppRoutes.controlPanelInvoiceSettings;
      case ControlPanelSection.printers:
        return AppRoutes.controlPanelPrinters;
      case ControlPanelSection.printersStations:
        return AppRoutes.controlPanelPrintersStations;
      case ControlPanelSection.printersAdd:
        return AppRoutes.controlPanelPrintersAdd;
      case ControlPanelSection.printersList:
        return AppRoutes.controlPanelPrintersList;
      case ControlPanelSection.shiftSettings:
        return AppRoutes.controlPanelShiftSettings;
      case ControlPanelSection.shiftCreate:
        return AppRoutes.controlPanelShiftCreate;
      case ControlPanelSection.cashReceipts:
        return AppRoutes.controlPanelCashReceipts;
      case ControlPanelSection.cashPayments:
        return AppRoutes.controlPanelCashPayments;
      case ControlPanelSection.cashExpenses:
        return AppRoutes.controlPanelCashExpenses;
      case ControlPanelSection.cashMovements:
        return AppRoutes.controlPanelCashMovements;
      case ControlPanelSection.salesAll:
        return AppRoutes.controlPanelSalesAll;
      case ControlPanelSection.salesReturns:
        return AppRoutes.controlPanelSalesReturns;
      case ControlPanelSection.salesCredit:
        return AppRoutes.controlPanelSalesCredit;
      case ControlPanelSection.salesQuotations:
        return AppRoutes.controlPanelSalesQuotations;
      case ControlPanelSection.reportsOverview:
        return AppRoutes.controlPanelReportsOverview;
      case ControlPanelSection.reportsSales:
        return AppRoutes.controlPanelReportsSales;
      case ControlPanelSection.reportsInventory:
        return AppRoutes.controlPanelReportsInventory;
      case ControlPanelSection.reportsShifts:
        return AppRoutes.controlPanelReportsShifts;
      case ControlPanelSection.reportsCash:
        return AppRoutes.controlPanelReportsCash;
      case ControlPanelSection.productsAdd:
        return AppRoutes.controlPanelAddProduct;
      case ControlPanelSection.productsCategoryAdd:
        return AppRoutes.controlPanelAddCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.controlPanelHeaderBlue,
          foregroundColor: AppColors.white,
          surfaceTintColor: AppColors.controlPanelHeaderBlue,
          elevation: 0,
          title: const Text('لوحة التحكم'),
          actions: [
            IconButton(
              tooltip: 'العودة إلى الكاشير',
              icon: const Icon(Icons.point_of_sale),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.pos),
            ),
          ],
        ),
        drawer: ControlDrawer(
          selected: section,
          onSelect: (value) => _navigate(context, value),
        ),
        body: Container(color: AppColors.backgroundColor, child: child),
      ),
    );
  }
}

class ControlPanelPlaceholder extends StatelessWidget {
  const ControlPanelPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutralGrey),
        ),
        child: Text(title, style: AppTextStyles.topbarTitle),
      ),
    );
  }
}
