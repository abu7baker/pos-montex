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

class ControlPanelCashReceiptsScreen extends ConsumerStatefulWidget {
  const ControlPanelCashReceiptsScreen({super.key});

  @override
  ConsumerState<ControlPanelCashReceiptsScreen> createState() =>
      _ControlPanelCashReceiptsScreenState();
}

class _ControlPanelCashReceiptsScreenState
    extends ConsumerState<ControlPanelCashReceiptsScreen> {
  final _amountController = TextEditingController(text: '0');
  final _customerController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final _fileController = TextEditingController(text: 'لم يتم اختيار أي ملف');

  int? _editingId;
  int? _selectedCustomerId;
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
    _customerController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _customerController.removeListener(_onFormChanged);
    _amountController.dispose();
    _customerController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    _fileController.dispose();
    super.dispose();
  }

  bool _isActiveStatus(String status) {
    final v = status.trim().toUpperCase();
    if (v.isEmpty) return true;
    return v != 'VOID' && v != 'CANCELED' && v != 'CANCELLED' && v != 'DELETED';
  }

  String _formatDate(DateTime date) =>
      DateFormat('yyyy-MM-dd hh:mm a').format(date);

  String _paymentLabel(String code) => PaymentMethods.labelForCode(code);

  String _accountLabel(String code) {
    final normalized = code.trim().toUpperCase();
    final option = _accountOptions.firstWhere(
      (o) => o.value == normalized,
      orElse: () => const PosSelectOption(value: 'NONE', label: 'لا أحد'),
    );
    return option.label;
  }

  String _extractAccountCode(String? reference) {
    final raw = (reference ?? '').trim();
    if (raw.isEmpty) return 'NONE';
    final direct = _accountOptions.firstWhere(
      (o) => o.value == raw.toUpperCase(),
      orElse: () => const PosSelectOption(value: 'NONE', label: 'لا أحد'),
    );
    if (direct.value != 'NONE') return direct.value;

    final lower = raw.toLowerCase();
    if (lower.contains('main_cashbox')) return 'MAIN_CASHBOX';
    return 'NONE';
  }

  void _resetForm() {
    _amountController.text = '0';
    _customerController.clear();
    _noteController.clear();
    _fileController.text = 'لم يتم اختيار أي ملف';
    setState(() {
      _editingId = null;
      _selectedCustomerId = null;
      _selectedPaymentMethod = 'CASH';
      _selectedAccount = 'NONE';
      _selectedStatus = CashVoucherService.statusActive;
      _createdAt = DateTime.now();
    });
  }

  String _resolvedCustomerName(
    ReceiptVoucherDb row,
    Map<int, CustomerDb> customerById,
  ) {
    final snapshotName = row.customerName?.trim() ?? '';
    if (snapshotName.isNotEmpty) return snapshotName;

    final linkedName = row.customerId == null
        ? ''
        : (customerById[row.customerId!]?.name.trim() ?? '');
    if (linkedName.isNotEmpty) return linkedName;

    return 'ط¹ظ…ظٹظ„ ط¹ط§ظ…';
  }

  ({int? customerId, String? customerName}) _resolveCustomerInput(
    List<CustomerDb> customers,
  ) {
    final typedName = _customerController.text.trim();
    if (typedName.isEmpty && _selectedCustomerId != null) {
      for (final customer in customers) {
        if (customer.id == _selectedCustomerId) {
          final name = customer.name.trim();
          return (
            customerId: customer.id,
            customerName: name.isEmpty ? null : name,
          );
        }
      }

      return (customerId: _selectedCustomerId, customerName: null);
    }

    if (typedName.isEmpty || typedName == 'ط¹ظ…ظٹظ„ ط¹ط§ظ…') {
      return (customerId: null, customerName: null);
    }

    for (final customer in customers) {
      if (customer.name.trim().toLowerCase() == typedName.toLowerCase()) {
        return (customerId: customer.id, customerName: customer.name.trim());
      }
    }

    return (customerId: null, customerName: typedName);
  }

  void _startEdit(ReceiptVoucherDb row, Map<int, CustomerDb> customerById) {
    _amountController.text = row.amount.toStringAsFixed(2);
    _customerController.text = _resolvedCustomerName(row, customerById);
    _noteController.text = row.note ?? '';
    setState(() {
      _editingId = row.localId;
      _selectedCustomerId = row.customerId;
      _selectedPaymentMethod = row.paymentMethodCode.trim().isEmpty
          ? 'CASH'
          : row.paymentMethodCode.trim().toUpperCase();
      _selectedAccount = _extractAccountCode(row.reference);
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

  Future<void> _save(List<CustomerDb> customers) async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppFeedback.warning(context, 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    final customerInput = _resolveCustomerInput(customers);
    setState(() => _saving = true);
    try {
      final service = ref.read(cashVoucherServiceProvider);
      final db = ref.read(appDbProvider);
      final reference = _selectedAccount == 'NONE' ? null : _selectedAccount;
      var customerId = customerInput.customerId;
      var customerName = customerInput.customerName;

      if (customerId == null && customerName != null) {
        customerId = await db.insertCustomer(
          CustomersCompanion.insert(name: customerName, mobile: ''),
        );
      }

      if (_editingId == null) {
        await service.createReceiptVoucher(
          amount: amount,
          paymentMethodCode: _selectedPaymentMethod,
          customerId: customerId,
          customerName: customerName,
          reference: reference,
          note: _noteController.text,
          status: CashVoucherService.statusActive,
          createdAt: _createdAt,
        );
      } else {
        await service.updateReceiptVoucher(
          localId: _editingId!,
          amount: amount,
          paymentMethodCode: _selectedPaymentMethod,
          customerId: customerId,
          customerName: customerName,
          reference: reference,
          note: _noteController.text,
          status: _selectedStatus,
          createdAt: _createdAt,
        );
      }

      if (!mounted) return;
      AppFeedback.success(
        context,
        _editingId == null ? 'تم حفظ سند القبض' : 'تم تحديث سند القبض',
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ السند: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleHidden(ReceiptVoucherDb row) async {
    final hiddenTarget = !row.isDeleted;
    await ref
        .read(cashVoucherServiceProvider)
        .setReceiptVoucherHidden(row.localId, hiddenTarget);
    if (!mounted) return;
    AppFeedback.success(
      context,
      hiddenTarget ? 'تم الإخفاء' : 'تمت إعادة الإظهار',
    );
  }

  Future<void> _toggleVoid(ReceiptVoucherDb row) async {
    final isVoid =
        row.status.trim().toUpperCase() == CashVoucherService.statusVoid;
    final next = isVoid
        ? CashVoucherService.statusActive
        : CashVoucherService.statusVoid;
    await ref
        .read(cashVoucherServiceProvider)
        .setReceiptVoucherStatus(row.localId, next);
    if (!mounted) return;
    AppFeedback.success(
      context,
      next == CashVoucherService.statusVoid
          ? 'تم إبطال السند'
          : 'تم تفعيل السند',
    );
  }

  Future<void> _delete(ReceiptVoucherDb row) async {
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
        .deleteReceiptVoucher(row.localId);
    if (!mounted) return;
    if (_editingId == row.localId) _resetForm();
    AppFeedback.success(context, 'تم حذف السند');
  }

  Future<void> _printVoucher(
    ReceiptVoucherDb row,
    Map<int, CustomerDb> customerById,
  ) async {
    final customerName = row.customerId == null
        ? 'عميل عام'
        : (customerById[row.customerId!]?.name.trim().isNotEmpty == true
              ? customerById[row.customerId!]!.name.trim()
              : 'عميل #${row.customerId}');
    try {
      await CashVoucherPrinting.printReceiptVoucher(
        voucher: row,
        customerName: customerName,
        paymentMethod: _paymentLabel(row.paymentMethodCode),
        accountName: _accountLabel(_extractAccountCode(row.reference)),
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

  Future<void> _previewVoucher(
    ReceiptVoucherDb row,
    Map<int, CustomerDb> customerById,
  ) {
    final customerName = row.customerId == null
        ? 'عميل عام'
        : (customerById[row.customerId!]?.name.trim().isNotEmpty == true
              ? customerById[row.customerId!]!.name.trim()
              : 'عميل #${row.customerId}');
    final note = (row.note ?? '').trim();
    return showDialog<void>(
      context: context,
      builder: (_) => CashVoucherPreviewDialog(
        data: CashVoucherPreviewData(
          title: 'سند قبض',
          voucherNo: row.voucherNo?.trim().isNotEmpty == true
              ? row.voucherNo!.trim()
              : '#${row.localId}',
          date: _formatDate(row.createdAt),
          status: _voucherStatusLabel(row.status, hidden: row.isDeleted),
          partyLabel: 'العميل',
          partyValue: customerName,
          paymentMethod: _paymentLabel(row.paymentMethodCode),
          accountName: _accountLabel(_extractAccountCode(row.reference)),
          amountLabel: '${NumberFormat('#,##0.00').format(row.amount)} ريال',
          description: note.isEmpty ? 'سند قبض للعميل $customerName' : note,
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
              Icons.receipt_long,
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
                  'سند قبض',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'نفس نموذج الكاشير مع إدارة كاملة للسندات وحركة مالية دقيقة.',
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

  Widget _buildFormCard(List<CustomerDb> customers) {
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
                  'بيانات سند القبض',
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
            label: 'عميل',
            required: true,
            child: PosSelect<int?>(
              options: customerOptions,
              value: _selectedCustomerId,
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
              onChanged: (value) => setState(() => _selectedCustomerId = value),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _fieldBlock(
            label: 'اسم العميل اليدوي',
            child: TextField(
              controller: _customerController,
              textAlign: TextAlign.right,
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
                  onPressed: _canSave ? () => _save(customers) : null,
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

  Widget _buildListCard(
    List<ReceiptVoucherDb> rows,
    Map<int, CustomerDb> customerById,
  ) {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = rows.where((r) {
      if (q.isEmpty) return true;
      final customerName = r.customerId == null
          ? 'عميل عام'
          : (customerById[r.customerId!]?.name ?? '');
      final accountName = _accountLabel(_extractAccountCode(r.reference));
      return (r.voucherNo ?? '').toLowerCase().contains(q) ||
          r.localId.toString().contains(q) ||
          customerName.toLowerCase().contains(q) ||
          accountName.toLowerCase().contains(q) ||
          (r.note ?? '').toLowerCase().contains(q) ||
          r.amount.toStringAsFixed(2).contains(q);
    }).toList();

    final activeTotal = filtered
        .where((r) => !r.isDeleted && _isActiveStatus(r.status))
        .fold<double>(0, (s, r) => s + r.amount);

    final tableRows = filtered.map((r) {
      final customerName = r.customerId == null
          ? 'عميل عام'
          : (customerById[r.customerId!]?.name ?? 'عميل #${r.customerId}');
      final account = _accountLabel(_extractAccountCode(r.reference));
      return DataRow(
        cells: [
          DataCell(
            Text(
              r.voucherNo?.trim().isNotEmpty == true
                  ? r.voucherNo!.trim()
                  : '#${r.localId}',
              style: AppTextStyles.fieldText,
            ),
          ),
          DataCell(Text(customerName, style: AppTextStyles.fieldText)),
          DataCell(
            Text(
              NumberFormat('#,##0.00').format(r.amount),
              style: AppTextStyles.fieldText,
            ),
          ),
          DataCell(
            Text(
              _paymentLabel(r.paymentMethodCode),
              style: AppTextStyles.fieldText,
            ),
          ),
          DataCell(Text(account, style: AppTextStyles.fieldText)),
          DataCell(_StatusChip(status: r.status, hidden: r.isDeleted)),
          DataCell(
            Text(_formatDate(r.createdAt), style: AppTextStyles.fieldHint),
          ),
          DataCell(
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _IconAction(
                  icon: Icons.edit_outlined,
                  color: AppColors.topbarIconDeepBlue,
                  onTap: () => _startEdit(r, customerById),
                  tooltip: 'تعديل السند',
                ),
                _IconAction(
                  icon: Icons.preview_outlined,
                  color: AppColors.primaryBlue,
                  onTap: () => _previewVoucher(r, customerById),
                  tooltip: 'معاينة السند',
                ),
                _IconAction(
                  icon: r.isDeleted
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.topbarIconIndigo,
                  onTap: () => _toggleHidden(r),
                  tooltip: r.isDeleted ? 'إظهار السند' : 'إخفاء السند',
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
                  onTap: () => _printVoucher(r, customerById),
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
    }).toList();

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
          const Text('سندات القبض', style: AppTextStyles.topbarTitle),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
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
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.selectHover,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'إجمالي السندات الفعالة: ${NumberFormat('#,##0.00').format(activeTotal)} ريال',
              style: AppTextStyles.fieldText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (tableRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'لا توجد سندات قبض',
                textAlign: TextAlign.center,
                style: AppTextStyles.fieldHint,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTextStyles.topbarTitle,
                dataTextStyle: AppTextStyles.fieldText,
                columns: const [
                  DataColumn(label: Text('رقم السند')),
                  DataColumn(label: Text('العميل')),
                  DataColumn(label: Text('المبلغ')),
                  DataColumn(label: Text('طريقة الدفع')),
                  DataColumn(label: Text('الحساب')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الإجراءات')),
                ],
                rows: tableRows,
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
        .watchReceiptVouchers(includeHidden: _includeHidden);

    return ControlPanelShell(
      section: ControlPanelSection.cashReceipts,
      child: StreamBuilder<List<CustomerDb>>(
        stream: db.watchCustomers(),
        builder: (context, customerSnap) {
          final customers = customerSnap.data ?? const <CustomerDb>[];
          final customerById = {for (final c in customers) c.id: c};
          return StreamBuilder<List<ReceiptVoucherDb>>(
            stream: stream,
            builder: (context, voucherSnap) {
              final rows = voucherSnap.data ?? const <ReceiptVoucherDb>[];
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _buildHero(),
                  const SizedBox(height: AppSpacing.md),
                  const CashManagementNavStrip(
                    current: ControlPanelSection.cashReceipts,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildFormCard(customers),
                  const SizedBox(height: AppSpacing.lg),
                  _buildListCard(rows, customerById),
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
