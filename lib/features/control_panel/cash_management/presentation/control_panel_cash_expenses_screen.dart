import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../pos/presentation/widgets/expense_dialog.dart';
import '../../presentation/control_panel_shell.dart';
import '../data/cash_voucher_service.dart';
import 'cash_voucher_printing.dart';
import 'widgets/cash_management_nav_strip.dart';
import 'widgets/cash_voucher_preview_dialog.dart';

class ControlPanelCashExpensesScreen extends ConsumerStatefulWidget {
  const ControlPanelCashExpensesScreen({super.key});

  @override
  ConsumerState<ControlPanelCashExpensesScreen> createState() =>
      _ControlPanelCashExpensesScreenState();
}

class _ControlPanelCashExpensesScreenState
    extends ConsumerState<ControlPanelCashExpensesScreen> {
  final _searchController = TextEditingController();
  bool _includeHidden = false;

  @override
  void dispose() {
    _searchController.dispose();
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

  String _accountLabel(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized == 'MAIN_CASHBOX') return 'الصندوق الرئيسي';
    return 'لا أحد';
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
      next == CashVoucherService.statusVoid ? 'تم الإبطال' : 'تم التفعيل',
    );
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
      AppFeedback.error(context, 'تعذر طباعة المصروف: $e');
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
          title: 'مصروف',
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
          description:
              note.isEmpty ? 'مصروف للجهة $supplierName' : note,
          note: note.isEmpty ? null : note,
        ),
      ),
    );
  }

  Future<void> _openExpenseDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ExpenseDialog(),
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
          colors: [AppColors.primaryBlue, AppColors.warningPurple],
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
              Icons.receipt_long_outlined,
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
                  'المصاريف',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يعرض المصاريف المسجلة من شاشة الكاشير مع إدارة كاملة للسندات.',
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

  Widget _buildList(List<PaymentVoucherDb> rows) {
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
          Row(
            children: [
              const Expanded(
                child: Text('قائمة المصاريف', style: AppTextStyles.topbarTitle),
              ),
              OutlinedButton.icon(
                onPressed: _openExpenseDialog,
                icon: const Icon(AppIcons.expense, size: 16),
                label: const Text('إضافة مصروف'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'بحث',
                    hintStyle: AppTextStyles.fieldHint,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 10,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.fieldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.fieldBorder),
                    ),
                  ),
                  style: AppTextStyles.fieldText,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Row(
                children: [
                  const Text('إظهار المخفي', style: AppTextStyles.fieldText),
                  const SizedBox(width: AppSpacing.xs),
                  Switch.adaptive(
                    value: _includeHidden,
                    activeColor: AppColors.successGreen,
                    onChanged: (v) => setState(() => _includeHidden = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'إجمالي المصاريف الفعالة: ${NumberFormat('#,##0.00').format(total)} ريال',
            style: AppTextStyles.fieldText,
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'لا توجد مصاريف',
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
                  DataColumn(label: Text('الجهة/النوع')),
                  DataColumn(label: Text('المبلغ')),
                  DataColumn(label: Text('طريقة الدفع')),
                  DataColumn(label: Text('الحساب')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الإجراءات')),
                ],
                rows: filtered.map((r) {
                  final supplierName = r.expenseType.trim().isEmpty
                      ? 'جهة عامة'
                      : r.expenseType.trim();
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        r.voucherNo?.trim().isNotEmpty == true
                            ? r.voucherNo!.trim()
                            : '#${r.localId}',
                        style: AppTextStyles.fieldText,
                      )),
                      DataCell(Text(supplierName, style: AppTextStyles.fieldText)),
                      DataCell(Text(
                        NumberFormat('#,##0.00').format(r.amount),
                        style: AppTextStyles.fieldText,
                      )),
                      DataCell(Text(
                        _methodLabel(_methodCodeFromReference(r.reference)),
                        style: AppTextStyles.fieldText,
                      )),
                      DataCell(Text(
                        _accountLabel(_accountCodeFromReference(r.reference)),
                        style: AppTextStyles.fieldText,
                      )),
                      DataCell(_StatusChip(status: r.status, hidden: r.isDeleted)),
                      DataCell(Text(
                        _formatDate(r.createdAt),
                        style: AppTextStyles.fieldHint,
                      )),
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _IconAction(
                              icon: Icons.preview_outlined,
                              color: AppColors.primaryBlue,
                              onTap: () => _previewVoucher(r),
                              tooltip: 'معاينة المصروف',
                            ),
                            _IconAction(
                              icon: Icons.print_outlined,
                              color: AppColors.topbarIconDeepBlue,
                              onTap: () => _printVoucher(r),
                              tooltip: 'طباعة المصروف',
                            ),
                            _IconAction(
                              icon: r.isDeleted
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.topbarIconIndigo,
                              onTap: () => _toggleHidden(r),
                              tooltip: r.isDeleted
                                  ? 'إظهار المصروف'
                                  : 'إخفاء المصروف',
                            ),
                            _IconAction(
                              icon: r.status.trim().toUpperCase() ==
                                      CashVoucherService.statusVoid
                                  ? Icons.check_circle_outline
                                  : Icons.block_outlined,
                              color: AppColors.warningPurple,
                              onTap: () => _toggleVoid(r),
                              tooltip: r.status.trim().toUpperCase() ==
                                      CashVoucherService.statusVoid
                                  ? 'تفعيل المصروف'
                                  : 'إبطال المصروف',
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
    final includeHidden = _includeHidden;
    return ControlPanelShell(
      section: ControlPanelSection.cashExpenses,
      child: StreamBuilder<List<PaymentVoucherDb>>(
        stream: ref
            .watch(cashVoucherServiceProvider)
            .watchPaymentVouchers(includeHidden: includeHidden),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <PaymentVoucherDb>[];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _hero(),
              const SizedBox(height: AppSpacing.md),
              const CashManagementNavStrip(
                current: ControlPanelSection.cashExpenses,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildList(rows),
            ],
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
    final normalized = status.trim().toUpperCase();
    final isVoid = normalized == CashVoucherService.statusVoid;
    final label = hidden ? 'مخفي' : (isVoid ? 'مبطل' : 'نشط');
    final color = hidden
        ? AppColors.textMuted
        : (isVoid ? AppColors.warningPurple : AppColors.successGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTextStyles.fieldHint.copyWith(color: color)),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
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
      ),
    );
  }
}
