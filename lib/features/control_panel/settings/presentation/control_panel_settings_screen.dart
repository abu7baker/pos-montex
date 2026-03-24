import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/settings/pos_feature_settings.dart';
import '../../../control_panel/presentation/control_panel_shell.dart';

class ControlPanelSettingsScreen extends ConsumerStatefulWidget {
  const ControlPanelSettingsScreen({super.key});

  @override
  ConsumerState<ControlPanelSettingsScreen> createState() =>
      _ControlPanelSettingsScreenState();
}

class _ControlPanelSettingsScreenState
    extends ConsumerState<ControlPanelSettingsScreen> {
  final Set<String> _savingKeys = <String>{};

  Future<void> _toggleSetting(String key, bool value) async {
    if (_savingKeys.contains(key)) return;
    setState(() => _savingKeys.add(key));
    try {
      await ref.read(posFeatureSettingsActionsProvider).setToggle(key, value);
    } finally {
      if (mounted) {
        setState(() => _savingKeys.remove(key));
      }
    }
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.topbarIconDeepBlue],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات شاشة الكاشير',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فعّل أو أخفِ عناصر الواجهة مع الحفاظ على تنسيق الشاشة تلقائيًا',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: AppTextStyles.topbarTitle)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String keyName,
    required String title,
    required String subtitle,
    required bool value,
  }) {
    final saving = _savingKeys.contains(keyName);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTextStyles.fieldText),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.fieldHint),
              ],
            ),
          ),
          if (saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              activeColor: AppColors.successGreen,
              onChanged: (next) => _toggleSetting(keyName, next),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(posFeatureSettingsProvider);

    return ControlPanelShell(
      section: ControlPanelSection.settings,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          settingsAsync.when(
            data: (settings) {
              return Column(
                children: [
                  _buildCard(
                    title: 'عناصر شاشة الكاشير',
                    icon: Icons.touch_app_outlined,
                    children: [
                      _buildToggle(
                        keyName: PosFeatureSettings.showServicesKey,
                        title: 'إظهار الخدمات',
                        subtitle: 'إظهار اختيار نوع الخدمة في أعلى سلة الكاشير',
                        value: settings.showServices,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showTablesKey,
                        title: 'إظهار الطاولات',
                        subtitle: 'إظهار اختيار الطاولة في أعلى سلة الكاشير',
                        value: settings.showTables,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showBrandsKey,
                        title: 'إظهار العلامات التجارية',
                        subtitle:
                            'إظهار فلتر العلامات التجارية في شاشة المنتجات',
                        value: settings.showBrands,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showSalesReturnKey,
                        title: 'إظهار زر مرتجع المبيعات',
                        subtitle:
                            'إظهار/إخفاء زر مرتجع المبيعات في الشريط العلوي',
                        value: settings.showSalesReturn,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showPaymentVoucherKey,
                        title: 'إظهار زر سند الصرف',
                        subtitle: 'إظهار/إخفاء زر سند الصرف في الشريط العلوي',
                        value: settings.showPaymentVoucher,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showReceiptVoucherKey,
                        title: 'إظهار زر سند القبض',
                        subtitle: 'إظهار/إخفاء زر سند القبض في الشريط العلوي',
                        value: settings.showReceiptVoucher,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.showExpenseKey,
                        title: 'إظهار زر إضافة المصاريف',
                        subtitle:
                            'إظهار/إخفاء زر إضافة المصاريف في الشريط العلوي',
                        value: settings.showExpense,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCard(
                    title: 'خيارات الطباعة',
                    icon: Icons.print_outlined,
                    children: [
                      _buildToggle(
                        keyName: PosFeatureSettings.printServiceInInvoiceKey,
                        title: 'طباعة الخدمة في الفاتورة',
                        subtitle: 'عند التعطيل لن يظهر سطر الخدمة في الفاتورة',
                        value: settings.printServiceInInvoice,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.printTableInInvoiceKey,
                        title: 'طباعة الطاولة في الفاتورة',
                        subtitle:
                            'عند التعطيل لن يظهر رقم/اسم الطاولة في الفاتورة',
                        value: settings.printTableInInvoice,
                      ),
                      _buildToggle(
                        keyName: PosFeatureSettings.printCategoryInInvoiceKey,
                        title: 'طباعة القسم في الفاتورة',
                        subtitle: 'عند التعطيل لن يظهر اسم القسم بجانب الأصناف',
                        value: settings.printCategoryInInvoice,
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => Container(
              height: 240,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutralGrey),
              ),
              child: Text(
                'تعذر تحميل الإعدادات: $error',
                style: AppTextStyles.fieldText,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
