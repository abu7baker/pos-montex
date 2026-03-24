import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide Column;
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
import '../../data/credit_settlement_service.dart';
import '../../data/sales_return_service.dart';
import '../../printing/print_job_runner.dart';
import 'pos_select.dart';
import 'sales_return_dialog.dart';

const _settlementPaymentOptions = [
  PosSelectOption(value: 'CASH', label: 'كاش'),
  PosSelectOption(value: 'CARD', label: 'بطاقة'),
  PosSelectOption(value: 'TRANSFER', label: 'تحويل'),
];

class RecentSalesDialog extends ConsumerStatefulWidget {
  const RecentSalesDialog({super.key});

  @override
  ConsumerState<RecentSalesDialog> createState() => _RecentSalesDialogState();
}

class _RecentSalesDialogState extends ConsumerState<RecentSalesDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final compactDialog = viewport.width < 1100;
    final horizontalInset = compactDialog ? AppSpacing.md : 40.0;
    final verticalInset = compactDialog ? AppSpacing.md : 20.0;
    return Dialog(
      alignment: Alignment.center,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compactDialog
                ? viewport.width - (horizontalInset * 2)
                : 920,
            maxHeight: compactDialog
                ? viewport.height - (verticalInset * 2)
                : 620,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Text(
                      'آخر المبيعات',
                      style: AppTextStyles.topbarTitle.copyWith(
                        fontSize: compactDialog ? 14 : 16,
                      ),
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
              ),
              const Divider(height: 1),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.borderBlue,
                indicatorWeight: 2.5,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('المبيعات'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('بيان السعر'),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الفاتورة أو اسم العميل',
                    hintStyle: AppTextStyles.fieldHint,
                    prefixIcon: const Icon(AppIcons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderBlue),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SalesList(
                      showQuotations: false,
                      searchQuery: _searchQuery,
                    ),
                    _SalesList(showQuotations: true, searchQuery: _searchQuery),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesList extends ConsumerWidget {
  const _SalesList({required this.showQuotations, required this.searchQuery});

  final bool showQuotations;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDbProvider);
    return StreamBuilder<List<SaleDb>>(
      stream: _getSalesStream(db),
      builder: (context, salesSnap) {
        return StreamBuilder<List<CustomerDb>>(
          stream: db.watchCustomers(),
          builder: (context, customerSnap) {
            if (salesSnap.connectionState == ConnectionState.waiting ||
                customerSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final customers = customerSnap.data ?? const <CustomerDb>[];
            final customerNamesById = {
              for (final customer in customers)
                customer.id: customer.name.trim().isEmpty
                    ? 'عميل #${customer.id}'
                    : customer.name.trim(),
            };

            var sales = salesSnap.data ?? const <SaleDb>[];
            final query = searchQuery.trim().toLowerCase();
            if (query.isNotEmpty) {
              sales = sales.where((sale) {
                final invoice = (sale.invoiceNo ?? sale.localId.toString())
                    .toLowerCase();
                final customer =
                    (customerNamesById[sale.customerId] ?? 'عميل عام')
                        .toLowerCase();
                return invoice.contains(query) || customer.contains(query);
              }).toList();
            }

            if (sales.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد بيانات للعرض',
                  style: AppTextStyles.fieldHint,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              itemCount: sales.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final customerName =
                    customerNamesById[sale.customerId] ?? 'عميل عام';
                return _SaleCard(sale: sale, customerName: customerName);
              },
            );
          },
        );
      },
    );
  }

  Stream<List<SaleDb>> _getSalesStream(AppDb db) {
    final query = db.select(db.sales);
    if (showQuotations) {
      query.where(
        (t) => t.status.equals('QUOTATION') | t.status.equals('quotation'),
      );
    } else {
      query.where((t) => t.status.isNotIn(['QUOTATION', 'quotation']));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.localId, mode: OrderingMode.desc),
    ]);
    return query.watch();
  }
}

class _SaleCard extends ConsumerWidget {
  const _SaleCard({required this.sale, required this.customerName});

  final SaleDb sale;
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat('#,##0.00');
    final dateText = DateFormat('yyyy-MM-dd hh:mm a').format(sale.createdAt);
    final statusMeta = _SaleStatusMeta.fromSale(sale);
    final canReturn = sale.status.trim().toLowerCase() != 'quotation';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final ultraCompact = constraints.maxWidth < 720;
        final spacing = ultraCompact ? AppSpacing.xs : AppSpacing.sm;

        return Container(
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutralGrey),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            textDirection: ui.TextDirection.rtl,
            children: [
              Expanded(
                flex: ultraCompact ? 20 : 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        _StatusBadge(meta: statusMeta, compact: compact),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Text(
                            sale.invoiceNo ?? 'فاتورة #${sale.localId}',
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: compact ? 13 : 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName,
                      style: AppTextStyles.fieldText.copyWith(
                        color: AppColors.topbarIconBlue,
                        fontSize: compact ? 12 : 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 15 : 16,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        _SaleMetaPill(
                          icon: Icons.event_outlined,
                          label: dateText,
                          compact: compact,
                        ),
                        SizedBox(width: spacing),
                        _SaleMetaPill(
                          icon: Icons.shopping_bag_outlined,
                          label: '${sale.itemsCount} صنف',
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 34 : 32,
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Expanded(
                      child: _SaleInfoTile(
                        label: 'الإجمالي',
                        value: '${currency.format(sale.total)} ريال',
                        icon: Icons.receipt_long_outlined,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SaleInfoTile(
                        label: 'المدفوع',
                        value: '${currency.format(sale.paidTotal)} ريال',
                        icon: Icons.payments_outlined,
                        valueColor: AppColors.successGreen,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SaleInfoTile(
                        label: 'المتبقي',
                        value: '${currency.format(sale.remaining)} ريال',
                        icon: Icons.account_balance_wallet_outlined,
                        valueColor: sale.remaining > 0
                            ? AppColors.dangerRed
                            : AppColors.successGreen,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Flexible(
                flex: ultraCompact ? 18 : 20,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        if (canReturn)
                          _SaleCardActionButton(
                            label: 'مرتجع',
                            icon: Icons.restart_alt,
                            backgroundColor: AppColors.topbarIconOrange,
                            compact: compact,
                            onPressed: () => _openSalesReturnDialog(
                              context,
                              ref,
                              sale,
                              customerName,
                            ),
                          ),
                        if (canReturn) SizedBox(width: spacing),
                        if (statusMeta.canSettle)
                          _SaleCardActionButton(
                            label: 'تسديد',
                            icon: Icons.payments_outlined,
                            backgroundColor: AppColors.successGreen,
                            compact: compact,
                            onPressed: () => _openSettlementDialog(
                              context,
                              ref,
                              sale,
                              customerName,
                            ),
                          ),
                        if (statusMeta.canSettle) SizedBox(width: spacing),
                        _SaleCardActionButton(
                          label: 'طباعة',
                          icon: Icons.print_outlined,
                          outlined: true,
                          compact: compact,
                          onPressed: () => _handlePrint(context, ref, sale),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePrint(
    BuildContext context,
    WidgetRef ref,
    SaleDb sale,
  ) async {
    try {
      final runner = ref.read(printJobRunnerProvider);
      final db = ref.read(appDbProvider);
      final items = await (db.select(
        db.saleItems,
      )..where((t) => t.saleLocalId.equals(sale.localId))).get();
      final payments = await (db.select(
        db.salePayments,
      )..where((t) => t.saleLocalId.equals(sale.localId))).get();

      await runner.printDirectly(
        jobType: 'CUSTOMER_RECEIPT',
        sale: sale,
        items: items,
        payments: payments,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.error(context, 'تعذر تنفيذ الطباعة: $e');
    }
  }

  Future<void> _openSettlementDialog(
    BuildContext context,
    WidgetRef ref,
    SaleDb sale,
    String customerName,
  ) async {
    final result = await showDialog<CreditSettlementResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _CreditSettlementDialog(sale: sale, customerName: customerName),
    );
    if (result == null || !context.mounted) return;
    AppFeedback.success(
      context,
      result.remaining <= 0.01
          ? 'تم سداد الفاتورة بالكامل'
          : 'تم تسجيل دفعة سداد على الفاتورة',
    );
  }

  Future<void> _openSalesReturnDialog(
    BuildContext context,
    WidgetRef ref,
    SaleDb sale,
    String customerName,
  ) async {
    final result = await showDialog<SalesReturnCreateResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SalesReturnDialog(sale: sale, customerName: customerName),
      ),
    );
    if (result == null || !context.mounted) return;
    AppFeedback.success(
      context,
      'تم إنشاء مرتجع ${result.returnNo} بعدد ${result.itemsCount} صنف',
    );
  }
}

class _SaleInfoTile extends StatelessWidget {
  const _SaleInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutralGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            textDirection: ui.TextDirection.rtl,
            children: [
              Text(
                label,
                style: AppTextStyles.summaryLabel,
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: compact ? 12 : 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: AppTextStyles.fieldText.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.meta, this.compact = false});

  final _SaleStatusMeta meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.color.withValues(alpha: 0.28)),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: meta.color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SaleMetaPill extends StatelessWidget {
  const _SaleMetaPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.fieldHint.copyWith(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleCardActionButton extends StatelessWidget {
  const _SaleCardActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.outlined = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: compact ? 9 : 11,
          ),
          side: BorderSide(color: AppColors.pillPurple.withValues(alpha: 0.28)),
          shape: radius,
          foregroundColor: AppColors.pillPurple,
        ),
        icon: Icon(icon, size: compact ? 14 : 16),
        label: Text(
          label,
          style: AppTextStyles.fieldText.copyWith(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 9 : 11,
        ),
        shape: radius,
      ),
      icon: Icon(icon, size: compact ? 14 : 16),
      label: Text(
        label,
        style: AppTextStyles.fieldText.copyWith(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SaleStatusMeta {
  const _SaleStatusMeta({
    required this.label,
    required this.color,
    required this.canSettle,
  });

  final String label;
  final Color color;
  final bool canSettle;

  factory _SaleStatusMeta.fromSale(SaleDb sale) {
    final status = sale.status.trim().toLowerCase();
    if (status == 'quotation') {
      return const _SaleStatusMeta(
        label: 'بيان سعر',
        color: AppColors.warningPurple,
        canSettle: false,
      );
    }
    if (status == 'credit') {
      return const _SaleStatusMeta(
        label: 'أجل',
        color: AppColors.dangerRed,
        canSettle: true,
      );
    }
    if (status == 'partial' && sale.remaining > 0.01) {
      return const _SaleStatusMeta(
        label: 'أجل جزئي',
        color: Color(0xFFD97706),
        canSettle: true,
      );
    }
    if (status == 'completed') {
      return const _SaleStatusMeta(
        label: 'مكتملة',
        color: AppColors.successGreen,
        canSettle: false,
      );
    }
    return const _SaleStatusMeta(
      label: 'فاتورة',
      color: AppColors.primaryBlue,
      canSettle: false,
    );
  }
}

class _CreditSettlementDialog extends ConsumerStatefulWidget {
  const _CreditSettlementDialog({
    required this.sale,
    required this.customerName,
  });

  final SaleDb sale;
  final String customerName;

  @override
  ConsumerState<_CreditSettlementDialog> createState() =>
      _CreditSettlementDialogState();
}

class _CreditSettlementDialogState
    extends ConsumerState<_CreditSettlementDialog> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  late final TextEditingController _dateController;
  String _paymentMethod = 'CASH';
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  bool get _canSave {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return !_saving && amount > 0;
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.sale.remaining.toStringAsFixed(2),
    );
    _dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy hh:mm a').format(_paidAt),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_paidAt),
    );
    if (time == null) return;

    setState(() {
      _paidAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateController.text = DateFormat('dd-MM-yyyy hh:mm a').format(_paidAt);
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppFeedback.warning(context, 'مبلغ السداد يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ref
          .read(creditSettlementServiceProvider)
          .settleSale(
            sale: widget.sale,
            amount: amount,
            paymentMethodCode: _paymentMethod,
            note: _noteController.text,
            paidAt: _paidAt,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تنفيذ السداد: $e');
      setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.fieldHint,
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldBackground,
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

  Widget _fieldBlock({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.fieldText, textAlign: TextAlign.right),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: ui.TextDirection.rtl,
                children: [
                  Text(
                    'تسديد فاتورة أجل',
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
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _SaleInfoTile(
                      label: 'الفاتورة',
                      value: widget.sale.invoiceNo ?? '#${widget.sale.localId}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleInfoTile(
                      label: 'العميل',
                      value: widget.customerName,
                      icon: AppIcons.user,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: _SaleInfoTile(
                      label: 'الإجمالي',
                      value: '${currency.format(widget.sale.total)} ريال',
                      icon: AppIcons.priceTag,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleInfoTile(
                      label: 'المدفوع',
                      value: '${currency.format(widget.sale.paidTotal)} ريال',
                      icon: AppIcons.cash,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleInfoTile(
                      label: 'المتبقي',
                      value: '${currency.format(widget.sale.remaining)} ريال',
                      icon: AppIcons.deferred,
                      valueColor: AppColors.dangerRed,
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
                      child: PosSelect<String>(
                        options: _settlementPaymentOptions,
                        value: _paymentMethod,
                        hintText: 'كاش',
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
                            setState(() => _paymentMethod = value ?? 'CASH'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _fieldBlock(
                      label: 'مبلغ السداد',
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
              _fieldBlock(
                label: 'تاريخ السداد',
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDateTime,
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
              const SizedBox(height: AppSpacing.md),
              _fieldBlock(
                label: 'ملاحظة السداد',
                child: TextField(
                  controller: _noteController,
                  textAlign: TextAlign.right,
                  textDirection: ui.TextDirection.rtl,
                  maxLines: 3,
                  decoration: _fieldDecoration(
                    hint: 'مثال: دفعة أولى، سداد كامل، تحويل بنك',
                  ),
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _canSave ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 10,
                      ),
                    ),
                    child: Text(_saving ? 'جارٍ الحفظ...' : 'تسديد الآن'),
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
