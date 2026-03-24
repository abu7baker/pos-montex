import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../control_panel_shell.dart';

class ControlDrawer extends StatelessWidget {
  const ControlDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final ControlPanelSection selected;
  final ValueChanged<ControlPanelSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final isProductsSelected =
        selected == ControlPanelSection.productsAdd ||
        selected == ControlPanelSection.productsCategoryAdd ||
        selected == ControlPanelSection.productsBrands;
    final isSettingsSelected =
        selected == ControlPanelSection.settings ||
        selected == ControlPanelSection.settingsSync ||
        selected == ControlPanelSection.settingsServices ||
        selected == ControlPanelSection.settingsTables ||
        selected == ControlPanelSection.settingsAddons ||
        selected == ControlPanelSection.settingsInvoices;
    final isPrintersSelected =
        selected == ControlPanelSection.printers ||
        selected == ControlPanelSection.printersStations ||
        selected == ControlPanelSection.printersAdd ||
        selected == ControlPanelSection.printersList;
    final isShiftsSelected =
        selected == ControlPanelSection.shiftSettings ||
        selected == ControlPanelSection.shiftCreate;
    final isCashManagementSelected =
        selected == ControlPanelSection.cashReceipts ||
        selected == ControlPanelSection.cashPayments ||
        selected == ControlPanelSection.cashExpenses ||
        selected == ControlPanelSection.cashMovements;
    final isSalesSelected =
        selected == ControlPanelSection.salesAll ||
        selected == ControlPanelSection.salesReturns ||
        selected == ControlPanelSection.salesCredit ||
        selected == ControlPanelSection.salesQuotations;
    final isReportsSelected =
        selected == ControlPanelSection.reportsOverview ||
        selected == ControlPanelSection.reportsSales ||
        selected == ControlPanelSection.reportsInventory ||
        selected == ControlPanelSection.reportsShifts ||
        selected == ControlPanelSection.reportsCash;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 120,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(color: AppColors.primaryBlue),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dashboard,
                      color: AppColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'لوحة التحكم',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                children: [
                  ExpansionTile(
                    leading: Icon(
                      Icons.tune,
                      color: isSettingsSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'الإعدادات',
                      style: TextStyle(
                        color: isSettingsSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isSettingsSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'إعدادات الكاشير',
                        selected: selected == ControlPanelSection.settings,
                        onTap: () => onSelect(ControlPanelSection.settings),
                      ),
                      _DrawerSubItem(
                        label: 'إعدادات المزامنة',
                        selected: selected == ControlPanelSection.settingsSync,
                        onTap: () => onSelect(ControlPanelSection.settingsSync),
                      ),
                      _DrawerSubItem(
                        label: 'إدارة الخدمات',
                        selected:
                            selected == ControlPanelSection.settingsServices,
                        onTap: () =>
                            onSelect(ControlPanelSection.settingsServices),
                      ),
                      _DrawerSubItem(
                        label: 'إدارة الطاولات',
                        selected:
                            selected == ControlPanelSection.settingsTables,
                        onTap: () =>
                            onSelect(ControlPanelSection.settingsTables),
                      ),
                      _DrawerSubItem(
                        label: 'الإضافات',
                        selected:
                            selected == ControlPanelSection.settingsAddons,
                        onTap: () =>
                            onSelect(ControlPanelSection.settingsAddons),
                      ),
                      _DrawerSubItem(
                        label: 'إعدادات الفواتير',
                        selected:
                            selected == ControlPanelSection.settingsInvoices,
                        onTap: () =>
                            onSelect(ControlPanelSection.settingsInvoices),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: isProductsSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'المنتجات',
                      style: TextStyle(
                        color: isProductsSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isProductsSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'قائمة / إضافة منتج',
                        selected: selected == ControlPanelSection.productsAdd,
                        onTap: () => onSelect(ControlPanelSection.productsAdd),
                      ),
                      _DrawerSubItem(
                        label: 'الأقسام',
                        selected:
                            selected == ControlPanelSection.productsCategoryAdd,
                        onTap: () =>
                            onSelect(ControlPanelSection.productsCategoryAdd),
                      ),
                      _DrawerSubItem(
                        label: 'العلامات التجارية',
                        selected:
                            selected == ControlPanelSection.productsBrands,
                        onTap: () =>
                            onSelect(ControlPanelSection.productsBrands),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: isCashManagementSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'إدارة النقدية',
                      style: TextStyle(
                        color: isCashManagementSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isCashManagementSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'سند قبض',
                        selected: selected == ControlPanelSection.cashReceipts,
                        onTap: () => onSelect(ControlPanelSection.cashReceipts),
                      ),
                      _DrawerSubItem(
                        label: 'سند صرف',
                        selected: selected == ControlPanelSection.cashPayments,
                        onTap: () => onSelect(ControlPanelSection.cashPayments),
                      ),
                      _DrawerSubItem(
                        label: 'المصاريف',
                        selected: selected == ControlPanelSection.cashExpenses,
                        onTap: () =>
                            onSelect(ControlPanelSection.cashExpenses),
                      ),
                      _DrawerSubItem(
                        label: 'حركة الصندوق',
                        selected: selected == ControlPanelSection.cashMovements,
                        onTap: () =>
                            onSelect(ControlPanelSection.cashMovements),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.point_of_sale_outlined,
                      color: isSalesSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'المبيعات',
                      style: TextStyle(
                        color: isSalesSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isSalesSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'كل المبيعات',
                        selected: selected == ControlPanelSection.salesAll,
                        onTap: () => onSelect(ControlPanelSection.salesAll),
                      ),
                      _DrawerSubItem(
                        label: 'مرتجعات المبيعات',
                        selected: selected == ControlPanelSection.salesReturns,
                        onTap: () => onSelect(ControlPanelSection.salesReturns),
                      ),
                      _DrawerSubItem(
                        label: 'المبيعات الآجلة',
                        selected: selected == ControlPanelSection.salesCredit,
                        onTap: () => onSelect(ControlPanelSection.salesCredit),
                      ),
                      _DrawerSubItem(
                        label: 'العروض السعرية',
                        selected:
                            selected == ControlPanelSection.salesQuotations,
                        onTap: () =>
                            onSelect(ControlPanelSection.salesQuotations),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.schedule_outlined,
                      color: isShiftsSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'الوردية',
                      style: TextStyle(
                        color: isShiftsSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isShiftsSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'إعدادات الوردية',
                        selected: selected == ControlPanelSection.shiftSettings,
                        onTap: () =>
                            onSelect(ControlPanelSection.shiftSettings),
                      ),
                      _DrawerSubItem(
                        label: 'إنشاء وردية جديدة',
                        selected: selected == ControlPanelSection.shiftCreate,
                        onTap: () => onSelect(ControlPanelSection.shiftCreate),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.assessment_outlined,
                      color: isReportsSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'التقارير',
                      style: TextStyle(
                        color: isReportsSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isReportsSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'التقارير الشاملة',
                        selected:
                            selected == ControlPanelSection.reportsOverview,
                        onTap: () =>
                            onSelect(ControlPanelSection.reportsOverview),
                      ),
                      _DrawerSubItem(
                        label: 'تقارير المبيعات',
                        selected: selected == ControlPanelSection.reportsSales,
                        onTap: () => onSelect(ControlPanelSection.reportsSales),
                      ),
                      _DrawerSubItem(
                        label: 'تقارير المخزون',
                        selected:
                            selected == ControlPanelSection.reportsInventory,
                        onTap: () =>
                            onSelect(ControlPanelSection.reportsInventory),
                      ),
                      _DrawerSubItem(
                        label: 'تقارير الورديات',
                        selected: selected == ControlPanelSection.reportsShifts,
                        onTap: () =>
                            onSelect(ControlPanelSection.reportsShifts),
                      ),
                      _DrawerSubItem(
                        label: 'تقارير النقدية',
                        selected: selected == ControlPanelSection.reportsCash,
                        onTap: () => onSelect(ControlPanelSection.reportsCash),
                      ),
                    ],
                  ),
                  _DrawerItem(
                    icon: Icons.storage_rounded,
                    label: 'قاعدة البيانات',
                    selected: selected == ControlPanelSection.database,
                    onTap: () => onSelect(ControlPanelSection.database),
                  ),
                  ExpansionTile(
                    leading: Icon(
                      Icons.print_outlined,
                      color: isPrintersSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'الطابعات',
                      style: TextStyle(
                        color: isPrintersSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    initiallyExpanded: isPrintersSelected,
                    childrenPadding: const EdgeInsets.only(
                      right: AppSpacing.lg,
                    ),
                    children: [
                      _DrawerSubItem(
                        label: 'محطات الطباعة',
                        selected:
                            selected == ControlPanelSection.printersStations,
                        onTap: () =>
                            onSelect(ControlPanelSection.printersStations),
                      ),
                      _DrawerSubItem(
                        label: 'إضافة طابعة',
                        selected: selected == ControlPanelSection.printersAdd,
                        onTap: () => onSelect(ControlPanelSection.printersAdd),
                      ),
                      _DrawerSubItem(
                        label: 'الطابعات المضافة',
                        selected: selected == ControlPanelSection.printersList,
                        onTap: () => onSelect(ControlPanelSection.printersList),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Montex POS', style: AppTextStyles.topbarInfo),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      selectedTileColor: AppColors.selectHover,
      onTap: onTap,
    );
  }
}

class _DrawerSubItem extends StatelessWidget {
  const _DrawerSubItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(
        right: AppSpacing.lg,
        left: AppSpacing.md,
      ),
      leading: Icon(Icons.chevron_left, size: 18, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      selectedTileColor: AppColors.selectHover,
      onTap: onTap,
    );
  }
}
