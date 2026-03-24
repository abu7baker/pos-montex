import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../../core/payment_methods.dart';
import '../../../control_panel/cash_management/data/cash_voucher_service.dart';
import 'payment_method_select.dart';
import 'pos_select.dart';

const _receiptAccounts = [
  PosSelectOption(value: 'NONE', label: 'لا أحد'),
  PosSelectOption(value: 'MAIN_CASHBOX', label: 'الصندوق الرئيسي'),
];

class ReceiptVoucherDialog extends ConsumerStatefulWidget {
  const ReceiptVoucherDialog({super.key});

  @override
  ConsumerState<ReceiptVoucherDialog> createState() =>
      _ReceiptVoucherDialogState();
}

class _ReceiptVoucherDialogState extends ConsumerState<ReceiptVoucherDialog> {
  final _amountController = TextEditingController(text: '0');
  final _customerController = TextEditingController();
  final _noteController = TextEditingController();
  final _fileController = TextEditingController(text: 'لم يتم اختيار أي ملف');
  late final TextEditingController _dateController;

  int? _selectedCustomerId;
  String? _selectedPaymentMethod;
  String? _selectedAccount;
  DateTime _paidOn = DateTime.now();
  bool _saving = false;

  bool get _canSave {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return !_saving && amount > 0 && _selectedPaymentMethod != null;
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy hh:mm a').format(_paidOn),
    );
    _selectedPaymentMethod = PaymentMethods.defaultCode;
    _selectedAccount = _receiptAccounts.first.value;
    _amountController.addListener(_onFormChanged);
    _customerController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _customerController.removeListener(_onFormChanged);
    _amountController.dispose();
    _customerController.dispose();
    _noteController.dispose();
    _fileController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_paidOn),
    );
    if (time == null) return;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _paidOn = value;
      controller.text = DateFormat('dd-MM-yyyy hh:mm a').format(value);
    });
  }

  Future<void> _save(List<CustomerDb> customers) async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppFeedback.warning(context, 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() => _saving = true);
    try {
      final typedCustomerName = _customerController.text.trim();
      var customerId = _selectedCustomerId;
      var customerName = typedCustomerName.isEmpty ? null : typedCustomerName;

      if (customerName != null) {
        final normalizedCustomerName = customerName.toLowerCase();
        for (final customer in customers) {
          if (customer.name.trim().toLowerCase() == normalizedCustomerName) {
            customerId = customer.id;
            customerName = customer.name.trim();
            break;
          }
        }
      }

      if (customerId == null && customerName != null) {
        customerId = await ref
            .read(appDbProvider)
            .insertCustomer(
              CustomersCompanion.insert(name: customerName, mobile: ''),
            );
      }

      await ref
          .read(cashVoucherServiceProvider)
          .createReceiptVoucher(
            amount: amount,
            paymentMethodCode: _selectedPaymentMethod ?? 'CASH',
            customerId: customerId,
            customerName: customerName,
            reference: _selectedAccount == null || _selectedAccount == 'NONE'
                ? null
                : _selectedAccount,
            note: _noteController.text,
            createdAt: _paidOn,
          );

      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ سند القبض بنجاح');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ سند القبض: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({
    String? hint,
    Widget? prefixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.fieldHint,
      isDense: true,
      filled: true,
      fillColor: enabled
          ? AppColors.fieldBackground
          : AppColors.neutralGrey.withOpacity(0.2),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
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
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ],
      ),
    );
  }

  Widget _fieldBlock({
    required String label,
    required Widget child,
    bool required = false,
    Widget? trailing,
  }) {
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: StreamBuilder<List<CustomerDb>>(
          stream: db.watchCustomers(),
          builder: (context, snapshot) {
            final customers = snapshot.data ?? const <CustomerDb>[];
            final customerOptions = <PosSelectOption<int?>>[
              const PosSelectOption<int?>(value: null, label: 'عميل عام'),
              ...customers.map(
                (c) => PosSelectOption<int?>(
                  value: c.id,
                  label: c.name.trim().isEmpty ? 'عميل #${c.id}' : c.name,
                ),
              ),
            ];

            if (!customerOptions.any((o) => o.value == _selectedCustomerId)) {
              _selectedCustomerId = null;
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    textDirection: ui.TextDirection.rtl,
                    children: [
                      Text(
                        'إضافة سند قبض',
                        style: AppTextStyles.topbarTitle.copyWith(fontSize: 14),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _fieldBlock(
                    label: 'عميل',
                    required: true,
                    child: PosSelect<int?>(
                      options: customerOptions,
                      value: _selectedCustomerId,
                      hintText: 'يرجى الاختيار',
                      height: 34,
                      borderRadius: 6,
                      fieldPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      enableSearch: true,
                      leadingIcon: AppIcons.user,
                      leadingIconBoxed: true,
                      leadingIconBoxSize: 20,
                      leadingIconSize: 14,
                      onChanged: (value) =>
                          setState(() => _selectedCustomerId = value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _fieldBlock(
                    label: 'اسم العميل اليدوي',
                    child: TextField(
                      controller: _customerController,
                      textAlign: TextAlign.right,
                      textDirection: ui.TextDirection.rtl,
                      decoration: _fieldDecoration(
                        hint: 'اكتب اسم العميل إذا لم يكن موجوداً',
                        prefixIcon: const Icon(
                          AppIcons.user,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: AppTextStyles.fieldText,
                    ),
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
                            onChanged: (value) =>
                                setState(() => _selectedPaymentMethod = value ?? PaymentMethods.defaultCode),
                            hintText: 'كاش',
                            height: 34,
                            borderRadius: 6,
                            fieldPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            enableSearch: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _fieldBlock(
                          label: 'المبلغ',
                          required: true,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: ui.TextDirection.rtl,
                            decoration: _fieldDecoration(
                              prefixIcon: const Icon(
                                AppIcons.cash,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
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
                          label: 'حساب',
                          child: PosSelect<String>(
                            options: _receiptAccounts,
                            value: _selectedAccount,
                            hintText: 'لا أحد',
                            height: 34,
                            borderRadius: 6,
                            fieldPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            enableSearch: false,
                            leadingIcon: AppIcons.cash,
                            leadingIconBoxed: true,
                            leadingIconBoxSize: 20,
                            leadingIconSize: 14,
                            onChanged: (value) =>
                                setState(() => _selectedAccount = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _fieldBlock(
                          label: 'المدفوعة على',
                          required: true,
                          child: TextField(
                            controller: _dateController,
                            readOnly: true,
                            onTap: () => _pickDateTime(_dateController),
                            textAlign: TextAlign.right,
                            textDirection: ui.TextDirection.rtl,
                            decoration: _fieldDecoration(
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            style: AppTextStyles.fieldText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _fieldBlock(
                    label: 'إرفاق وثيقة',
                    child: Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fileController,
                            readOnly: true,
                            textAlign: TextAlign.right,
                            textDirection: ui.TextDirection.rtl,
                            decoration: _fieldDecoration(),
                            style: AppTextStyles.fieldHint,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () {
                            AppFeedback.info(
                              context,
                              'إرفاق الملفات غير مفعل حالياً',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(
                              color: AppColors.fieldBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                            textStyle: AppTextStyles.buttonTextDark,
                          ),
                          child: const Text('اختيار ملف'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _fieldBlock(
                    label: 'ملاحظة الدفع',
                    child: TextField(
                      controller: _noteController,
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
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.fieldBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 10,
                          ),
                          textStyle: AppTextStyles.buttonTextDark,
                        ),
                        child: const Text('إغلاق'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _canSave ? () => _save(customers) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: 10,
                          ),
                          textStyle: AppTextStyles.buttonTextStyle,
                        ),
                        child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
