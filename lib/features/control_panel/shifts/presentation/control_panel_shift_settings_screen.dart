import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelShiftSettingsScreen extends ConsumerStatefulWidget {
  const ControlPanelShiftSettingsScreen({super.key});

  @override
  ConsumerState<ControlPanelShiftSettingsScreen> createState() =>
      _ControlPanelShiftSettingsScreenState();
}

class _ControlPanelShiftSettingsScreenState
    extends ConsumerState<ControlPanelShiftSettingsScreen> {
  static const String _requireOpeningCashKey = 'shift.require_opening_cash';
  static const String _allowMultipleOpenKey = 'shift.allow_multiple_open';
  static const String _autoClosePreviousKey = 'shift.auto_close_previous';
  static const String _linkSalesToOpenShiftKey =
      'shift.link_sales_to_open_shift';
  static const String _printReportOnCloseKey = 'shift.print_report_on_close';
  static const String _shiftPrefixKey = 'shift.prefix';

  static const List<String> _openingCashKeys = [
    'opening_cash_drawer',
    'opening_cash',
    'shift_opening_cash',
    'cash_drawer_opening',
  ];

  final _defaultOpeningCashController = TextEditingController();
  final _shiftPrefixController = TextEditingController();

  bool _requireOpeningCash = true;
  bool _allowMultipleOpen = false;
  bool _autoClosePrevious = true;
  bool _linkSalesToOpenShift = true;
  bool _printReportOnClose = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSettings);
  }

  @override
  void dispose() {
    _defaultOpeningCashController.dispose();
    _shiftPrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(appDbProvider);

    final openingRaw = await _firstSetting(db, _openingCashKeys);
    final prefixRaw = await db.getSetting(_shiftPrefixKey);

    final requireOpeningRaw = await db.getSetting(_requireOpeningCashKey);
    final allowMultipleRaw = await db.getSetting(_allowMultipleOpenKey);
    final autoCloseRaw = await db.getSetting(_autoClosePreviousKey);
    final linkSalesRaw = await db.getSetting(_linkSalesToOpenShiftKey);
    final printReportRaw = await db.getSetting(_printReportOnCloseKey);

    if (!mounted) return;
    setState(() {
      _defaultOpeningCashController.text = openingRaw?.trim().isNotEmpty == true
          ? openingRaw!.trim()
          : '0';
      _shiftPrefixController.text = prefixRaw?.trim().isNotEmpty == true
          ? prefixRaw!.trim()
          : 'SHIFT';

      _requireOpeningCash = _parseBool(requireOpeningRaw, fallback: true);
      _allowMultipleOpen = _parseBool(allowMultipleRaw, fallback: false);
      _autoClosePrevious = _parseBool(autoCloseRaw, fallback: true);
      _linkSalesToOpenShift = _parseBool(linkSalesRaw, fallback: true);
      _printReportOnClose = _parseBool(printReportRaw, fallback: true);
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;

    final openingCash =
        double.tryParse(_defaultOpeningCashController.text.trim()) ?? 0;
    final prefix = _shiftPrefixController.text.trim().isEmpty
        ? 'SHIFT'
        : _shiftPrefixController.text.trim();

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);

      await db.setSetting(
        _requireOpeningCashKey,
        _boolSettingValue(_requireOpeningCash),
      );
      await db.setSetting(
        _allowMultipleOpenKey,
        _boolSettingValue(_allowMultipleOpen),
      );
      await db.setSetting(
        _autoClosePreviousKey,
        _boolSettingValue(_autoClosePrevious),
      );
      await db.setSetting(
        _linkSalesToOpenShiftKey,
        _boolSettingValue(_linkSalesToOpenShift),
      );
      await db.setSetting(
        _printReportOnCloseKey,
        _boolSettingValue(_printReportOnClose),
      );
      await db.setSetting(_shiftPrefixKey, prefix);

      final openingValue = openingCash.toStringAsFixed(2);
      for (final key in _openingCashKeys) {
        await db.setSetting(key, openingValue);
      }

      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ إعدادات الوردية بنجاح');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ الإعدادات: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
          Switch.adaptive(
            value: value,
            activeColor: AppColors.successGreen,
            onChanged: _saving ? null : onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ControlPanelShell(
      section: ControlPanelSection.shiftSettings,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
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
                    Icons.schedule,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'إعدادات الوردية',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اضبط قواعد فتح الوردية والإعدادات الأساسية للحسابات',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.neutralGrey.withOpacity(0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إعدادات مهمة', style: AppTextStyles.topbarTitle),
                  const SizedBox(height: AppSpacing.md),
                  _buildToggleTile(
                    title: 'إلزام رصيد افتتاحي',
                    subtitle: 'يمنع فتح وردية بدون إدخال رصيد افتتاحي',
                    value: _requireOpeningCash,
                    onChanged: (value) =>
                        setState(() => _requireOpeningCash = value),
                  ),
                  _buildToggleTile(
                    title: 'السماح بأكثر من وردية مفتوحة',
                    subtitle: 'إذا كان مفعّل يمكن فتح ورديات متعددة بنفس الوقت',
                    value: _allowMultipleOpen,
                    onChanged: (value) =>
                        setState(() => _allowMultipleOpen = value),
                  ),
                  _buildToggleTile(
                    title: 'إغلاق الوردية السابقة تلقائياً',
                    subtitle:
                        'عند فتح وردية جديدة يتم إغلاق المفتوحة السابقة تلقائياً',
                    value: _autoClosePrevious,
                    onChanged: (value) =>
                        setState(() => _autoClosePrevious = value),
                  ),
                  _buildToggleTile(
                    title: 'ربط المبيعات بالوردية المفتوحة',
                    subtitle: 'تجهيز للنظام لربط كل عملية بيع بالوردية الحالية',
                    value: _linkSalesToOpenShift,
                    onChanged: (value) =>
                        setState(() => _linkSalesToOpenShift = value),
                  ),
                  _buildToggleTile(
                    title: 'طباعة تقرير عند إغلاق الوردية',
                    subtitle: 'يجهّز النظام لطباعة تقرير الوردية بشكل تلقائي',
                    value: _printReportOnClose,
                    onChanged: (value) =>
                        setState(() => _printReportOnClose = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _defaultOpeningCashController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي الافتراضي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _shiftPrefixController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'بادئة رقم الوردية',
                      hintText: 'مثال: SHIFT',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                      ),
                      icon: const Icon(Icons.save, color: AppColors.white),
                      label: Text(
                        _saving ? 'جاري الحفظ...' : 'حفظ إعدادات الوردية',
                        style: AppTextStyles.buttonTextStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutralGrey),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('طريقة العمل السريعة', style: AppTextStyles.topbarTitle),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    '1. اضبط الرصيد الافتتاحي الافتراضي.',
                    style: AppTextStyles.fieldText,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2. فعّل أو عطّل السماح بورديات متعددة حسب سياسة المحل.',
                    style: AppTextStyles.fieldText,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '3. انتقل إلى صفحة إنشاء وردية جديدة وابدأ الوردية.',
                    style: AppTextStyles.fieldText,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _parseBool(String? raw, {required bool fallback}) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return fallback;
  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'off') {
    return false;
  }
  return fallback;
}

String _boolSettingValue(bool value) => value ? '1' : '0';

Future<String?> _firstSetting(AppDb db, List<String> keys) async {
  for (final key in keys) {
    final value = await db.getSetting(key);
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}
