import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../control_panel/cash_management/data/cash_voucher_service.dart';
import 'payment_method_select.dart';
import 'pos_select.dart';

/// خيارات فئة المصروف (ثابتة؛ يمكن لاحقًا نقلها لإعدادات أو جدول).
const _expenseCategoryOptions = [
  PosSelectOption(value: 'general', label: 'عام'),
  PosSelectOption(value: 'purchases', label: 'مشتريات'),
  PosSelectOption(value: 'salaries', label: 'رواتب'),
  PosSelectOption(value: 'rent', label: 'إيجار'),
  PosSelectOption(value: 'maintenance', label: 'صيانة'),
  PosSelectOption(value: 'other', label: 'أخرى'),
];

const _accountOptions = [
  PosSelectOption(value: 'NONE', label: 'لا أحد'),
  PosSelectOption(value: 'MAIN_CASHBOX', label: 'الصندوق الرئيسي'),
];

class ExpenseDialog extends ConsumerStatefulWidget {
  const ExpenseDialog({super.key});

  @override
  ConsumerState<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController(text: '0');
  final _expenseForController = TextEditingController();
  final _expenseNoteController = TextEditingController();
  final _paymentNoteController = TextEditingController();
  late final TextEditingController _expenseDateController;
  late final TextEditingController _paymentDateController;

  String? _selectedCategory;
  String? _selectedAccount;
  String _selectedPaymentMethod = PaymentMethods.defaultCode;
  DateTime _expenseDate = DateTime.now();
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expenseDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy hh:mm a').format(_expenseDate),
    );
    _paymentDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy hh:mm a').format(_paymentDate),
    );
    _selectedCategory = _expenseCategoryOptions.first.value;
    _selectedAccount = _accountOptions.first.value;
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  Future<void> _pickDateTime(TextEditingController controller, bool isPayment) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isPayment) {
        _paymentDate = value;
      } else {
        _expenseDate = value;
      }
      controller.text = DateFormat('dd-MM-yyyy hh:mm a').format(value);
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _referenceController.dispose();
    _amountController.dispose();
    _expenseForController.dispose();
    _expenseNoteController.dispose();
    _paymentNoteController.dispose();
    _expenseDateController.dispose();
    _paymentDateController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0;
    return !_saving && amount > 0;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      AppFeedback.warning(context, 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    final expenseFor = _expenseForController.text.trim();
    final categoryLabel = _expenseCategoryOptions
        .firstWhere(
          (o) => o.value == _selectedCategory,
          orElse: () => _expenseCategoryOptions.first,
        )
        .label;
    final expenseType = expenseFor.isEmpty
        ? 'مصروف عام ($categoryLabel)'
        : '$categoryLabel - $expenseFor';

    final reference = 'PAYMENT:${_selectedPaymentMethod.toUpperCase()} | ACCOUNT:${(_selectedAccount ?? 'NONE').toUpperCase()}';
    final noteParts = <String>[];
    if (_expenseNoteController.text.trim().isNotEmpty) {
      noteParts.add(_expenseNoteController.text.trim());
    }
    if (_paymentNoteController.text.trim().isNotEmpty) {
      noteParts.add('ملاحظة الدفع: ${_paymentNoteController.text.trim()}');
    }
    final note = noteParts.isEmpty ? null : noteParts.join('\n');

    setState(() => _saving = true);
    try {
      await ref.read(cashVoucherServiceProvider).createPaymentVoucher(
            amount: amount,
            expenseType: expenseType,
            reference: reference,
            note: note,
            createdAt: _paymentDate,
          );
      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ المصروف بنجاح');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ المصروف: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({String? hint, Widget? prefixIcon, bool enabled = true}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.fieldHint,
      isDense: true,
      filled: true,
      fillColor: enabled ? AppColors.fieldBackground : AppColors.neutralGrey.withOpacity(0.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }

  Widget _label(String text, {bool required = false, Widget? trailing}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: ui.TextDirection.rtl,
        children: [
          Text(
            required ? '$text*' : text,
            style: AppTextStyles.fieldText,
            textAlign: TextAlign.right,
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _fieldBlock({required String label, required Widget child, bool required = false, Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label, required: required, trailing: trailing),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: ui.TextDirection.rtl,
                children: [
                  Text('إضافة المصاريف', style: AppTextStyles.topbarTitle.copyWith(fontSize: 14)),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _fieldBlock(
                      label: 'الفرع',
                      required: true,
                      child: StreamBuilder<String?>(
                        stream: db.watchSetting('branch_name'),
                        builder: (context, nameSnap) {
                          return StreamBuilder<String?>(
                            stream: db.watchSetting('branch_code'),
                            builder: (context, codeSnap) {
                              final name = (nameSnap.data ?? '').trim();
                              final code = (codeSnap.data ?? '').trim();
                              final display = name.isEmpty
                                  ? 'الفرع الافتراضي'
                                  : code.isEmpty
                                      ? name
                                      : '($code) $name';
                              return Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.neutralGrey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.fieldBorder),
                                ),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  display,
                                  style: AppTextStyles.fieldText,
                                  textDirection: ui.TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'فئة المصروف',
                      required: true,
                      child: PosSelect<String>(
                        options: _expenseCategoryOptions,
                        value: _selectedCategory,
                        hintText: 'يرجى الاختيار',
                        height: 34,
                        borderRadius: 6,
                        fieldPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        enableSearch: false,
                        onChanged: (value) => setState(() => _selectedCategory = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _fieldBlock(
                      label: 'الرقم المرجعي',
                      child: TextField(
                        controller: _referenceController,
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        decoration: _fieldDecoration(hint: 'يترك فارغًا ليتم التخصيص من البرنامج'),
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'تاريخ',
                      required: true,
                      child: TextField(
                        controller: _expenseDateController,
                        readOnly: true,
                        onTap: () => _pickDateTime(_expenseDateController, false),
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        decoration: _fieldDecoration(
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        ),
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _fieldBlock(
                      label: 'مصروف ل',
                      trailing: const Icon(AppIcons.info, size: 14, color: AppColors.borderBlue),
                      child: TextField(
                        controller: _expenseForController,
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        decoration: _fieldDecoration(hint: 'جهة عامة أو اسم المستفيد'),
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'الإجمالي',
                      required: true,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.neutralGrey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        alignment: Alignment.centerRight,
                        child: Text(
                          _amountController.text.trim().isEmpty
                              ? '0.00'
                              : (double.tryParse(_amountController.text.trim().replaceAll(',', ''))?.toStringAsFixed(2) ?? _amountController.text.trim()),
                          style: AppTextStyles.fieldText,
                          textDirection: ui.TextDirection.rtl,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _fieldBlock(
                label: 'ملاحظة حول المصاريف',
                child: TextField(
                  controller: _expenseNoteController,
                  textAlign: TextAlign.right,
                  textDirection: ui.TextDirection.rtl,
                  maxLines: 3,
                  decoration: _fieldDecoration(),
                  style: AppTextStyles.fieldText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Text('إضافة دفع:', style: AppTextStyles.topbarTitle.copyWith(fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _fieldBlock(
                      label: 'المبلغ',
                      required: true,
                      child: TextField(
                        controller: _amountController,
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _fieldDecoration(
                          prefixIcon: const Icon(AppIcons.cash, size: 16, color: AppColors.textSecondary),
                        ),
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'المدفوعة على',
                      required: true,
                      child: TextField(
                        controller: _paymentDateController,
                        readOnly: true,
                        onTap: () => _pickDateTime(_paymentDateController, true),
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        decoration: _fieldDecoration(
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        ),
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _fieldBlock(
                      label: 'طريقة الدفع',
                      required: true,
                      child: PaymentMethodSelect(
                        value: _selectedPaymentMethod,
                        onChanged: (v) => setState(() => _selectedPaymentMethod = v ?? PaymentMethods.defaultCode),
                        hintText: 'كاش',
                        height: 34,
                        borderRadius: 6,
                        fieldPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        enableSearch: true,
                        maxDropdownHeight: 220,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'حساب',
                      child: PosSelect<String>(
                        options: _accountOptions,
                        value: _selectedAccount,
                        hintText: 'لا أحد',
                        height: 34,
                        borderRadius: 6,
                        fieldPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        enableSearch: false,
                        leadingIcon: AppIcons.cash,
                        leadingIconBoxed: true,
                        leadingIconBoxSize: 20,
                        leadingIconSize: 14,
                        onChanged: (value) => setState(() => _selectedAccount = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _fieldBlock(
                label: 'ملاحظة الدفع',
                child: TextField(
                  controller: _paymentNoteController,
                  textAlign: TextAlign.right,
                  textDirection: ui.TextDirection.rtl,
                  maxLines: 3,
                  decoration: _fieldDecoration(),
                  style: AppTextStyles.fieldText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.fieldBorder),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: ui.TextDirection.rtl,
                children: [
                  Text(
                    'دفع مستحق: 0.00',
                    style: AppTextStyles.summaryLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: ui.TextDirection.rtl,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.fieldBorder),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                      textStyle: AppTextStyles.buttonTextDark,
                    ),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                      textStyle: AppTextStyles.buttonTextStyle,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
