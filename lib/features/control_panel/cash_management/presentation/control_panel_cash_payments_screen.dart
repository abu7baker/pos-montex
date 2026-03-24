import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../pos/presentation/widgets/payment_method_select.dart';
import '../../../pos/presentation/widgets/pos_select.dart';
import '../../presentation/control_panel_shell.dart';
import '../data/cash_voucher_service.dart';
import 'cash_voucher_printing.dart';
import 'widgets/cash_management_nav_strip.dart';
import 'widgets/cash_voucher_preview_dialog.dart';

const _accountOptions = [
  PosSelectOption(value: 'NONE', label: 'لا أحد'),
  PosSelectOption(value: 'MAIN_CASHBOX', label: 'الصندوق الرئيسي'),
];

class ControlPanelCashPaymentsScreen extends ConsumerStatefulWidget {
  const ControlPanelCashPaymentsScreen({super.key});

  @override
  ConsumerState<ControlPanelCashPaymentsScreen> createState() =>
      _ControlPanelCashPaymentsScreenState();
}

class _ControlPanelCashPaymentsScreenState
    extends ConsumerState<ControlPanelCashPaymentsScreen> {
  final _amountController = TextEditingController(text: '0');
  final _supplierController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final _fileController = TextEditingController(text: 'لم يتم اختيار أي ملف');

  int? _editingId;
  int? _selectedSupplierId;
  String _selectedPaymentMethod = 'CASH';
  String _selectedAccount = 'NONE';
  String _selectedStatus = CashVoucherService.statusActive;
  DateTime _createdAt = DateTime.now();
  bool _includeHidden = false;
  bool _saving = false;
  bool get _canSave {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return !_saving && amount > 0 && _selectedPaymentMethod.trim().isNotEmpty;
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onFormChanged);
    _supplierController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _supplierController.removeListener(_onFormChanged);
    _amountController.dispose();
    _supplierController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    _fileController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      DateFormat('yyyy-MM-dd hh:mm a').format(date);

  bool _isActiveStatus(String status) {
    final v = status.trim().toUpperCase();
    if (v.isEmpty) return true;
    return v != 'VOID' && v != 'CANCELED' && v != 'CANCELLED' && v != 'DELETED';
  }

  String _methodLabel(String code) => PaymentMethods.labelForCode(code);

  String _accountLabel(String code) {
    final normalized = code.trim().toUpperCase();
    final option = _accountOptions.firstWhere(
      (o) => o.value == normalized,
      orElse: () => const PosSelectOption(value: 'NONE', label: 'لا أحد'),
    );
    return option.label;
  }

  String _extractPart(String? reference, String key, {String fallback = ''}) {
    final raw = (reference ?? '').trim();
    if (raw.isEmpty) return fallback;

    final chunks = raw.split('|').map((e) => e.trim());
    for (final chunk in chunks) {
      if (!chunk.contains(':')) continue;
      final parts = chunk.split(':');
      if (parts.length < 2) continue;
      if (parts.first.trim().toUpperCase() == key.toUpperCase()) {
        return parts.sublist(1).join(':').trim();
      }
    }
    return fallback;
  }

  String _methodCodeFromReference(String? reference) {
    final method = _extractPart(
      reference,
      'PAYMENT',
      fallback: 'CASH',
    ).toUpperCase();
    return method.isEmpty ? 'CASH' : method;
  }

  String _accountCodeFromReference(String? reference) {
    final account = _extractPart(
      reference,
      'ACCOUNT',
      fallback: 'NONE',
    ).toUpperCase();
    return account.isEmpty ? 'NONE' : account;
  }

  void _resetForm() {
    _amountController.text = '0';
    _supplierController.clear();
    _noteController.clear();
    _fileController.text = 'لم يتم اختيار أي ملف';
    setState(() {
      _editingId = null;
      _selectedSupplierId = null;
      _selectedPaymentMethod = 'CASH';
      _selectedAccount = 'NONE';
      _selectedStatus = CashVoucherService.statusActive;
      _createdAt = DateTime.now();
    });
  }

  void _startEdit(PaymentVoucherDb row, List<CustomerDb> customers) {
    _amountController.text = row.amount.toStringAsFixed(2);
    _supplierController.text = row.expenseType.trim();
    _noteController.text = row.note ?? '';

    int? supplierId;
    final targetName = row.expenseType.trim().toLowerCase();
    if (targetName.isNotEmpty && targetName != 'جهة عامة') {
      for (final c in customers) {
        if (c.name.trim().toLowerCase() == targetName) {
          supplierId = c.id;
          break;
        }
      }
    }

    setState(() {
      _editingId = row.localId;
      _selectedSupplierId = supplierId;
      _selectedPaymentMethod = _methodCodeFromReference(row.reference);
      _selectedAccount = _accountCodeFromReference(row.reference);
      _selectedStatus = row.status.trim().isEmpty
          ? CashVoucherService.statusActive
          : row.status.trim().toUpperCase();
      _createdAt = row.createdAt;
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_createdAt),
    );
    if (time == null) return;
    setState(() {
      _createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(Map<int, CustomerDb> customersById) async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppFeedback.warning(context, 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    final expenseType = _selectedSupplierId == null
        ? 'جهة عامة'
        : (customersById[_selectedSupplierId!]?.name.trim().isNotEmpty == true
              ? customersById[_selectedSupplierId!]!.name.trim()
              : 'جهة #$_selectedSupplierId');

    final manualSupplierName = _supplierController.text.trim();
    final effectiveExpenseType = manualSupplierName.isNotEmpty
        ? manualSupplierName
        : expenseType;

    final reference =
        'PAYMENT:${_selectedPaymentMethod.toUpperCase()} | ACCOUNT:${_selectedAccount.toUpperCase()}';

    setState(() => _saving = true);
    try {
      final service = ref.read(cashVoucherServiceProvider);
      if (_editingId == null) {
        await service.createPaymentVoucher(
          amount: amount,
          expenseType: effectiveExpenseType,
          reference: reference,
          note: _noteController.text,
          status: CashVoucherService.statusActive,
          createdAt: _createdAt,
        );
      } else {
        await service.updatePaymentVoucher(
          localId: _editingId!,
          amount: amount,
          expenseType: effectiveExpenseType,
          reference: reference,
          note: _noteController.text,
          status: _selectedStatus,
          createdAt: _createdAt,
        );
      }

      if (!mounted) return;
      AppFeedback.success(
        context,
        _editingId == null ? 'تم حفظ سند الصرف' : 'تم تحديث سند الصرف',
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ السند: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleHidden(PaymentVoucherDb row) async {
    final hiddenTarget = !row.isDeleted;
    await ref
        .read(cashVoucherServiceProvider)
        .setPaymentVoucherHidden(row.localId, hiddenTarget);
    if (!mounted) return;
    AppFeedback.success(
      context,
      hiddenTarget ? 'تم الإخفاء' : 'تمت إعادة الإظهار',
    );
  }

  Future<void> _toggleVoid(PaymentVoucherDb row) async {
    final isVoid =
        row.status.trim().toUpperCase() == CashVoucherService.statusVoid;
    final next = isVoid
        ? CashVoucherService.statusActive
        : CashVoucherService.statusVoid;
    await ref
        .read(cashVoucherServiceProvider)
        .setPaymentVoucherStatus(row.localId, next);
    if (!mounted) return;
    AppFeedback.success(
      context,
      next == CashVoucherService.statusVoid
          ? 'تم إبطال السند'
          : 'تم تفعيل السند',
    );
  }

  Future<void> _delete(PaymentVoucherDb row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text(
          'هل تريد حذف السند ${row.voucherNo ?? row.localId} نهائيًا؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: AppTextStyles.buttonTextStyle),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(cashVoucherServiceProvider)
        .deletePaymentVoucher(row.localId);
    if (!mounted) return;
    if (_editingId == row.localId) _resetForm();
    AppFeedback.success(context, 'تم حذف السند');
  }

  Future<void> _printVoucher(PaymentVoucherDb row) async {
    final supplierName = row.expenseType.trim().isEmpty
        ? 'جهة عامة'
        : row.expenseType.trim();
    try {
      await CashVoucherPrinting.printPaymentVoucher(
        voucher: row,
        supplierName: supplierName,
        paymentMethod: _methodLabel(_methodCodeFromReference(row.reference)),
        accountName: _accountLabel(_accountCodeFromReference(row.reference)),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر طباعة السند: $e');
    }
  }

  String _voucherStatusLabel(String status, {required bool hidden}) {
    if (hidden) return 'مخفي';
    final normalized = status.trim().toUpperCase();
    if (normalized == CashVoucherService.statusVoid) return 'مبطل';
    return 'نشط';
  }

  Future<void> _previewVoucher(PaymentVoucherDb row) {
    final supplierName = row.expenseType.trim().isEmpty
        ? 'جهة عامة'
        : row.expenseType.trim();
    final note = (row.note ?? '').trim();
    return showDialog<void>(
      context: context,
      builder: (_) => CashVoucherPreviewDialog(
        data: CashVoucherPreviewData(
          title: 'سند صرف',
          voucherNo: row.voucherNo?.trim().isNotEmpty == true
              ? row.voucherNo!.trim()
              : '#${row.localId}',
          date: _formatDate(row.createdAt),
          status: _voucherStatusLabel(row.status, hidden: row.isDeleted),
          partyLabel: 'الجهة',
          partyValue: supplierName,
          paymentMethod: _methodLabel(_methodCodeFromReference(row.reference)),
          accountName: _accountLabel(_accountCodeFromReference(row.reference)),
          amountLabel: '${NumberFormat('#,##0.00').format(row.amount)} ريال',
          description: note.isEmpty ? 'سند صرف للجهة $supplierName' : note,
          note: note.isEmpty ? null : note,
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        required ? '$text*' : text,
        style: AppTextStyles.fieldText,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _fieldBlock({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label, required: required),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.pillPurple],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.outbox_outlined,
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
                  'سند صرف',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تصميم موحد مع مودل الكاشير ومتكامل مع قاعدة البيانات.',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.82),
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

  Widget _buildForm(List<CustomerDb> customers) {
    final suppliers = <PosSelectOption<int?>>[
      const PosSelectOption<int?>(value: null, label: 'جهة عامة'),
      ...customers.map(
        (c) => PosSelectOption<int?>(
          value: c.id,
          label: c.name.trim().isEmpty ? 'جهة #${c.id}' : c.name,
        ),
      ),
    ];

    if (!suppliers.any((o) => o.value == _selectedSupplierId)) {
      _selectedSupplierId = null;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'بيانات سند الصرف',
                  style: AppTextStyles.topbarTitle,
                ),
              ),
              if (_editingId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'وضع التعديل',
                    style: AppTextStyles.fieldHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldBlock(
            label: 'المورد',
            required: true,
            child: PosSelect<int?>(
              options: suppliers,
              value: _selectedSupplierId,
              hintText: 'يرجى الاختيار',
              height: 36,
              borderRadius: 8,
              fieldPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              enableSearch: true,
              leadingIcon: AppIcons.user,
              leadingIconBoxed: true,
              leadingIconBoxSize: 20,
              leadingIconSize: 14,
              onChanged: (value) => setState(() => _selectedSupplierId = value),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _fieldBlock(
            label: 'اسم المورد/الجهة اليدوي',
            child: TextField(
              controller: _supplierController,
              textAlign: TextAlign.right,
              decoration: _fieldDecoration(
                hint: 'اكتب اسم المورد أو الجهة إذا لم يكن موجوداً',
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
            children: [
              Expanded(
                child: _fieldBlock(
                  label: 'طريقة الدفع',
                  required: true,
                  child: PaymentMethodSelect(
                    value: _selectedPaymentMethod,
                    onChanged: (value) => setState(
                      () => _selectedPaymentMethod = value ?? PaymentMethods.defaultCode,
                    ),
                    hintText: 'كاش',
                    height: 36,
                    borderRadius: 8,
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
            children: [
              Expanded(
                child: _fieldBlock(
                  label: 'حساب',
                  child: PosSelect<String>(
                    options: _accountOptions,
                    value: _selectedAccount,
                    hintText: 'لا أحد',
                    height: 36,
                    borderRadius: 8,
                    fieldPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    enableSearch: false,
                    leadingIcon: AppIcons.cash,
                    leadingIconBoxed: true,
                    leadingIconBoxSize: 20,
                    leadingIconSize: 14,
                    onChanged: (value) =>
                        setState(() => _selectedAccount = value ?? 'NONE'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _fieldBlock(
                  label: 'المدفوعة على',
                  required: true,
                  child: OutlinedButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _formatDate(_createdAt),
                      style: AppTextStyles.buttonTextDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldBlock(
            label: 'إرفاق وثيقة',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fileController,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    decoration: _fieldDecoration(),
                    style: AppTextStyles.fieldHint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () {
                    AppFeedback.info(context, 'إرفاق الملفات غير مفعل حالياً');
                  },
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
              maxLines: 3,
              decoration: _fieldDecoration(),
              style: AppTextStyles.fieldText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('تفريغ / جديد'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canSave
                      ? () => _save({for (final c in customers) c.id: c})
                      : null,
                  icon: const Icon(
                    Icons.save_outlined,
                    size: 18,
                    color: AppColors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  label: Text(
                    _saving
                        ? 'جاري الحفظ...'
                        : (_editingId == null ? 'حفظ السند' : 'تحديث السند'),
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<PaymentVoucherDb> rows, List<CustomerDb> customers) {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = rows.where((r) {
      if (q.isEmpty) return true;
      final method = _methodLabel(_methodCodeFromReference(r.reference));
      final account = _accountLabel(_accountCodeFromReference(r.reference));
      return (r.voucherNo ?? '').toLowerCase().contains(q) ||
          r.localId.toString().contains(q) ||
          r.expenseType.toLowerCase().contains(q) ||
          method.toLowerCase().contains(q) ||
          account.toLowerCase().contains(q) ||
          (r.note ?? '').toLowerCase().contains(q) ||
          r.amount.toStringAsFixed(2).contains(q);
    }).toList();

    final total = filtered
        .where((r) => !r.isDeleted && _isActiveStatus(r.status))
        .fold<double>(0, (s, r) => s + r.amount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('سندات الصرف', style: AppTextStyles.topbarTitle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration(
                    hint: 'بحث',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'إظهار المخفي',
                        style: AppTextStyles.fieldText,
                      ),
                    ),
                    Switch.adaptive(
                      value: _includeHidden,
                      activeColor: AppColors.successGreen,
                      onChanged: (v) => setState(() => _includeHidden = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'إجمالي السندات الفعالة: ${NumberFormat('#,##0.00').format(total)} ريال',
            style: AppTextStyles.fieldText,
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'لا توجد سندات صرف',
                textAlign: TextAlign.center,
                style: AppTextStyles.fieldHint,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTextStyles.topbarTitle,
                columns: const [
                  DataColumn(label: Text('رقم السند')),
                  DataColumn(label: Text('المورد')),
                  DataColumn(label: Text('المبلغ')),
                  DataColumn(label: Text('طريقة الدفع')),
                  DataColumn(label: Text('الحساب')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الإجراءات')),
                ],
                rows: filtered.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          r.voucherNo?.trim().isNotEmpty == true
                              ? r.voucherNo!.trim()
                              : '#${r.localId}',
                        ),
                      ),
                      DataCell(
                        Text(
                          r.expenseType.trim().isEmpty
                              ? '-'
                              : r.expenseType.trim(),
                        ),
                      ),
                      DataCell(Text(NumberFormat('#,##0.00').format(r.amount))),
                      DataCell(
                        Text(
                          _methodLabel(_methodCodeFromReference(r.reference)),
                        ),
                      ),
                      DataCell(
                        Text(
                          _accountLabel(_accountCodeFromReference(r.reference)),
                        ),
                      ),
                      DataCell(
                        _StatusChip(status: r.status, hidden: r.isDeleted),
                      ),
                      DataCell(Text(_formatDate(r.createdAt))),
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _IconAction(
                              icon: Icons.edit_outlined,
                              color: AppColors.topbarIconDeepBlue,
                              onTap: () => _startEdit(r, customers),
                              tooltip: 'تعديل السند',
                            ),
                            _IconAction(
                              icon: Icons.preview_outlined,
                              color: AppColors.primaryBlue,
                              onTap: () => _previewVoucher(r),
                              tooltip: 'معاينة السند',
                            ),
                            _IconAction(
                              icon: r.isDeleted
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.topbarIconIndigo,
                              onTap: () => _toggleHidden(r),
                              tooltip: r.isDeleted
                                  ? 'إظهار السند'
                                  : 'إخفاء السند',
                            ),
                            _IconAction(
                              icon:
                                  r.status.trim().toUpperCase() ==
                                      CashVoucherService.statusVoid
                                  ? Icons.check_circle_outline
                                  : Icons.block_outlined,
                              color: AppColors.warningPurple,
                              onTap: () => _toggleVoid(r),
                              tooltip:
                                  r.status.trim().toUpperCase() ==
                                      CashVoucherService.statusVoid
                                  ? 'تفعيل السند'
                                  : 'إبطال السند',
                            ),
                            _IconAction(
                              icon: Icons.print_outlined,
                              color: AppColors.successGreen,
                              onTap: () => _printVoucher(r),
                              tooltip: 'طباعة السند',
                            ),
                            _IconAction(
                              icon: Icons.delete_outline,
                              color: AppColors.dangerRed,
                              onTap: () => _delete(r),
                              tooltip: 'حذف السند',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    final stream = ref
        .read(cashVoucherServiceProvider)
        .watchPaymentVouchers(includeHidden: _includeHidden);
    return ControlPanelShell(
      section: ControlPanelSection.cashPayments,
      child: StreamBuilder<List<CustomerDb>>(
        stream: db.watchCustomers(),
        builder: (context, customerSnap) {
          final customers = customerSnap.data ?? const <CustomerDb>[];
          return StreamBuilder<List<PaymentVoucherDb>>(
            stream: stream,
            builder: (context, snap) {
              final rows = snap.data ?? const <PaymentVoucherDb>[];
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _hero(),
                  const SizedBox(height: AppSpacing.md),
                  const CashManagementNavStrip(
                    current: ControlPanelSection.cashPayments,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildForm(customers),
                  const SizedBox(height: AppSpacing.lg),
                  _buildList(rows, customers),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.hidden});

  final String status;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final value = status.trim().toUpperCase();
    final isVoid = value == CashVoucherService.statusVoid;
    final label = hidden
        ? 'مخفي'
        : (isVoid ? 'مبطل' : (value.isEmpty ? 'نشط' : value));
    final color = hidden
        ? AppColors.textMuted
        : (isVoid ? AppColors.warningPurple : AppColors.successGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
