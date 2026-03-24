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
import '../../../pos/data/credit_settlement_service.dart';
import '../../../pos/data/sales_return_service.dart';
import '../../../pos/printing/print_job_runner.dart';
import '../../../pos/presentation/widgets/pos_select.dart';
import '../../../pos/presentation/widgets/sales_return_dialog.dart';
import '../../presentation/control_panel_shell.dart';
import '../data/control_panel_sales_service.dart';
import 'widgets/sales_management_nav_strip.dart';

const _settlementPaymentOptions = [
  PosSelectOption(value: 'CASH', label: 'كاش'),
  PosSelectOption(value: 'CARD', label: 'بطاقة'),
  PosSelectOption(value: 'TRANSFER', label: 'تحويل'),
];

class ControlPanelSalesScreen extends ConsumerStatefulWidget {
  const ControlPanelSalesScreen({
    super.key,
    required this.section,
    required this.kind,
  });

  const ControlPanelSalesScreen.all({super.key})
    : section = ControlPanelSection.salesAll,
      kind = SalesListingKind.allSales;

  const ControlPanelSalesScreen.returns({super.key})
    : section = ControlPanelSection.salesReturns,
      kind = SalesListingKind.salesReturns;

  const ControlPanelSalesScreen.credit({super.key})
    : section = ControlPanelSection.salesCredit,
      kind = SalesListingKind.creditSales;

  const ControlPanelSalesScreen.quotations({super.key})
    : section = ControlPanelSection.salesQuotations,
      kind = SalesListingKind.quotations;

  final ControlPanelSection section;
  final SalesListingKind kind;

  @override
  ConsumerState<ControlPanelSalesScreen> createState() =>
      _ControlPanelSalesScreenState();
}

class _ControlPanelSalesScreenState
    extends ConsumerState<ControlPanelSalesScreen> {
  late final TextEditingController _searchController;
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _loading = true;
  bool _printing = false;
  SalesDashboardData? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _searchController = TextEditingController();
    Future<void>.microtask(_reload);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = picked;
      if (_toDate.isBefore(_fromDate)) {
        _toDate = _fromDate;
      }
    });
    await _reload();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _toDate = picked;
      if (_toDate.isBefore(_fromDate)) {
        _fromDate = _toDate;
      }
    });
    await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(controlPanelSalesServiceProvider)
          .loadDashboard(
            kind: widget.kind,
            fromDate: _fromDate,
            toDate: _toDate,
            searchQuery: _searchController.text,
          );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تحميل بيانات المبيعات: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openSaleDetails(ControlPanelSaleRow row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SaleDetailsDialog(saleLocalId: row.sale.localId),
    );
  }

  Future<void> _openReturnDetails(ControlPanelSalesReturnRow row) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _SalesReturnDetailsDialog(returnLocalId: row.salesReturn.localId),
    );
  }

  Future<void> _openSettlementDialog(ControlPanelSaleRow row) async {
    final result = await showDialog<CreditSettlementResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreditSettlementDialog(
        sale: row.sale,
        customerName: row.customerName,
      ),
    );
    if (result == null || !mounted) return;
    AppFeedback.success(
      context,
      result.remaining <= 0.01
          ? 'تم تسديد الفاتورة بالكامل'
          : 'تم تسجيل دفعة على الفاتورة بنجاح',
    );
    await _reload();
  }

  Future<void> _openSalesReturnDialog(ControlPanelSaleRow row) async {
    final result = await showDialog<SalesReturnCreateResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SalesReturnDialog(
          sale: row.sale,
          customerName: row.customerName,
        ),
      ),
    );
    if (result == null || !mounted) return;
    AppFeedback.success(
      context,
      'تم إنشاء مرتجع ${result.returnNo} بعدد ${result.itemsCount} صنف',
    );
    await _reload();
  }

  Future<void> _printSale(SaleDb sale) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final db = ref.read(appDbProvider);
      final runner = ref.read(printJobRunnerProvider);
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
      if (!mounted) return;
      AppFeedback.success(context, 'تم إرسال الفاتورة إلى الطباعة');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تنفيذ الطباعة: $error');
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  String _title() {
    switch (widget.kind) {
      case SalesListingKind.allSales:
        return 'المبيعات';
      case SalesListingKind.salesReturns:
        return 'مرتجعات المبيعات';
      case SalesListingKind.creditSales:
        return 'المبيعات الآجلة';
      case SalesListingKind.quotations:
        return 'العروض السعرية';
    }
  }

  String _subtitle() {
    switch (widget.kind) {
      case SalesListingKind.allSales:
        return 'متابعة الفواتير المباعة فعلياً مع تفاصيل العميل والدفعات والمرتجعات المرتبطة.';
      case SalesListingKind.salesReturns:
        return 'عرض كل مرتجعات المبيعات وربطها بالفواتير الأصلية والكمية المرتجعة والسبب.';
      case SalesListingKind.creditSales:
        return 'مراقبة الفواتير التي ما زال عليها رصيد مستحق أو تم سدادها جزئياً.';
      case SalesListingKind.quotations:
        return 'إدارة العروض السعرية المحفوظة ومراجعة تفاصيلها قبل تحويلها أو طباعتها.';
    }
  }

  IconData _heroIcon() {
    switch (widget.kind) {
      case SalesListingKind.allSales:
        return Icons.point_of_sale_rounded;
      case SalesListingKind.salesReturns:
        return Icons.assignment_return_rounded;
      case SalesListingKind.creditSales:
        return Icons.account_balance_wallet_rounded;
      case SalesListingKind.quotations:
        return Icons.description_rounded;
    }
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.neutralGrey.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _money(double value) {
    return '${NumberFormat('#,##0.00').format(value)} ريال';
  }

  String _dateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd hh:mm a').format(value);
  }

  String _invoiceNo(SaleDb sale) {
    final invoiceNo = sale.invoiceNo?.trim() ?? '';
    if (invoiceNo.isNotEmpty) return invoiceNo;
    return 'فاتورة #${sale.localId}';
  }

  String _returnNo(SalesReturnDb salesReturn) {
    final returnNo = salesReturn.returnNo?.trim() ?? '';
    if (returnNo.isNotEmpty) return returnNo;
    return 'مرتجع #${salesReturn.localId}';
  }

  bool _canSettleSale(SaleDb sale) {
    final normalized = sale.status.trim().toLowerCase();
    return normalized != 'quotation' && sale.remaining > 0.01;
  }

  _BadgeMeta _saleStatusMeta(SaleDb sale) {
    final normalized = sale.status.trim().toLowerCase();
    if (normalized == 'quotation') {
      return const _BadgeMeta('عرض سعري', AppColors.warningPurple);
    }
    if (sale.remaining > 0.01 && sale.paidTotal > 0.01) {
      return const _BadgeMeta('آجل جزئي', AppColors.topbarIconOrange);
    }
    if (sale.remaining > 0.01) {
      return const _BadgeMeta('آجل', AppColors.dangerRed);
    }
    return const _BadgeMeta('مكتملة', AppColors.successGreen);
  }

  _BadgeMeta _returnStatusMeta(SalesReturnDb salesReturn) {
    final normalized = salesReturn.status.trim().toLowerCase();
    if (normalized == 'completed' || normalized == 'done') {
      return const _BadgeMeta('مكتمل', AppColors.successGreen);
    }
    if (normalized == 'pending') {
      return const _BadgeMeta('قيد المراجعة', AppColors.warningPurple);
    }
    return const _BadgeMeta('مرتجع', AppColors.dangerRed);
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.topbarIconDeepBlue],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_heroIcon(), size: 28, color: AppColors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(),
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              'يعرض هذا القسم البيانات المحفوظة محلياً من شاشة البيع، مع نفس ترتيب وألوان لوحة التحكم الحالية.',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _searchHint() {
    switch (widget.kind) {
      case SalesListingKind.allSales:
      case SalesListingKind.creditSales:
      case SalesListingKind.quotations:
        return 'ابحث برقم الفاتورة أو العميل أو الملاحظة أو رقم الوردية';
      case SalesListingKind.salesReturns:
        return 'ابحث برقم المرتجع أو الفاتورة الأصلية أو العميل أو السبب';
    }
  }

  Widget _buildFilterCard() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _reload(),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: _searchHint(),
                hintStyle: AppTextStyles.fieldHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                filled: true,
                fillColor: AppColors.fieldBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderBlue),
                ),
              ),
              style: AppTextStyles.fieldText,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _DateButton(
              label: 'من: ${dateFormat.format(_fromDate)}',
              onTap: _pickFromDate,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: _DateButton(
              label: 'إلى: ${dateFormat.format(_toDate)}',
              onTap: _pickToDate,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: _loading ? null : _reload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.topbarIconDeepBlue,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  List<_MetricData> _summaryMetrics(SalesDashboardData data) {
    switch (data.kind) {
      case SalesListingKind.allSales:
        return [
          _MetricData(
            label: 'عدد الفواتير',
            value: '${data.invoiceCount}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.topbarIconDeepBlue,
          ),
          _MetricData(
            label: 'إجمالي المبيعات',
            value: _money(data.totalAmount),
            icon: Icons.payments_outlined,
            color: AppColors.successGreen,
          ),
          _MetricData(
            label: 'إجمالي المحصل',
            value: _money(data.paidAmount),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.primaryBlue,
          ),
          _MetricData(
            label: 'إجمالي المرتجعات',
            value: _money(data.returnsAmount),
            icon: Icons.assignment_return_outlined,
            color: AppColors.warningPurple,
          ),
        ];
      case SalesListingKind.creditSales:
        return [
          _MetricData(
            label: 'فواتير الآجل',
            value: '${data.invoiceCount}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.dangerRed,
          ),
          _MetricData(
            label: 'الإجمالي',
            value: _money(data.totalAmount),
            icon: Icons.payments_outlined,
            color: AppColors.topbarIconDeepBlue,
          ),
          _MetricData(
            label: 'المحصل',
            value: _money(data.paidAmount),
            icon: Icons.savings_outlined,
            color: AppColors.successGreen,
          ),
          _MetricData(
            label: 'المتبقي',
            value: _money(data.remainingAmount),
            icon: Icons.warning_amber_rounded,
            color: AppColors.dangerRed,
          ),
        ];
      case SalesListingKind.quotations:
        return [
          _MetricData(
            label: 'عدد العروض',
            value: '${data.invoiceCount}',
            icon: Icons.description_outlined,
            color: AppColors.warningPurple,
          ),
          _MetricData(
            label: 'إجمالي القيم',
            value: _money(data.totalAmount),
            icon: Icons.price_change_outlined,
            color: AppColors.primaryBlue,
          ),
          _MetricData(
            label: 'عدد الأصناف',
            value: '${data.itemsCount}',
            icon: Icons.inventory_2_outlined,
            color: AppColors.topbarIconOrange,
          ),
        ];
      case SalesListingKind.salesReturns:
        return [
          _MetricData(
            label: 'عدد المرتجعات',
            value: '${data.invoiceCount}',
            icon: Icons.assignment_return_outlined,
            color: AppColors.warningPurple,
          ),
          _MetricData(
            label: 'إجمالي المرتجع',
            value: _money(data.returnsAmount),
            icon: Icons.keyboard_return_rounded,
            color: AppColors.dangerRed,
          ),
          _MetricData(
            label: 'إجمالي الكميات',
            value: '${data.itemsCount}',
            icon: Icons.inventory_2_outlined,
            color: AppColors.topbarIconDeepBlue,
          ),
        ];
    }
  }

  Widget _buildSummary(SalesDashboardData data) {
    final metrics = _summaryMetrics(data);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final metric in metrics)
          SizedBox(width: 240, child: _MetricCard(metric: metric)),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null) {
      return const _EmptyPanel(
        title: 'تعذر تحميل بيانات القسم',
        subtitle: 'أعد المحاولة أو تحقق من البيانات المحلية.',
      );
    }

    final hasRows = data.kind == SalesListingKind.salesReturns
        ? data.returnRows.isNotEmpty
        : data.salesRows.isNotEmpty;

    if (!hasRows) {
      return const _EmptyPanel(
        title: 'لا توجد بيانات للعرض',
        subtitle: 'غيّر فترة البحث أو اكتب عبارة بحث مختلفة.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummary(data),
        const SizedBox(height: AppSpacing.lg),
        if (data.kind == SalesListingKind.salesReturns)
          ...data.returnRows.map(_buildReturnCard)
        else
          ...data.salesRows.map(_buildSaleCard),
      ],
    );
  }

  Widget _buildSaleCard(ControlPanelSaleRow row) {
    final sale = row.sale;
    final status = _saleStatusMeta(sale);
    final note = (sale.note ?? '').trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1300;
        final ultraCompact = constraints.maxWidth < 1120;
        final showNote = !ultraCompact && note.isNotEmpty;
        final spacing = ultraCompact ? AppSpacing.xs : AppSpacing.sm;

        final pills = <Widget>[
          _InfoPill(
            icon: Icons.calendar_today_outlined,
            label: _dateTime(sale.createdAt),
            compact: compact,
          ),
          _InfoPill(
            icon: Icons.shopping_bag_outlined,
            label: '${sale.itemsCount} صنف',
            compact: compact,
          ),
          if (row.serviceName.isNotEmpty)
            _InfoPill(
              icon: Icons.room_service_outlined,
              label: row.serviceName,
              compact: compact,
            ),
          if (row.tableName.isNotEmpty)
            _InfoPill(
              icon: Icons.table_restaurant_outlined,
              label: row.tableName,
              compact: compact,
            ),
          _InfoPill(
            icon: Icons.swap_horiz_outlined,
            label: row.shiftLabel,
            compact: compact,
          ),
          if (row.returnsCount > 0)
            _InfoPill(
              icon: Icons.assignment_return_outlined,
              label: '${row.returnsCount} مرتجع',
              accent: AppColors.warningPurple,
              compact: compact,
            ),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          decoration: _panelDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: ultraCompact ? 22 : 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _invoiceNo(sale),
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: compact ? 14 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: spacing),
                        _StatusBadge(
                          label: status.label,
                          color: status.color,
                          compact: compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.customerName,
                      style: AppTextStyles.fieldText.copyWith(
                        color: AppColors.topbarIconDeepBlue,
                        fontSize: compact ? 12 : 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showNote) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: AppTextStyles.fieldHint.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 28 : 32,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pills.length; i++) ...[
                          if (i > 0) SizedBox(width: spacing),
                          pills[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 28 : 26,
                child: Row(
                  children: [
                    Expanded(
                      child: _SaleMetricTile(
                        label: 'الإجمالي',
                        value: _money(sale.total),
                        color: AppColors.textPrimary,
                        icon: Icons.payments_outlined,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SaleMetricTile(
                        label: 'المدفوع',
                        value: _money(sale.paidTotal),
                        color: AppColors.successGreen,
                        icon: Icons.account_balance_wallet_outlined,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SaleMetricTile(
                        label: 'المتبقي',
                        value: _money(sale.remaining),
                        color: sale.remaining > 0.01
                            ? AppColors.dangerRed
                            : AppColors.successGreen,
                        icon: Icons.warning_amber_rounded,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Flexible(
                flex: ultraCompact ? 16 : 18,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SaleActionButton(
                          label: 'مرتجع',
                          icon: Icons.restart_alt,
                          backgroundColor: AppColors.topbarIconOrange,
                          foregroundColor: AppColors.white,
                          compact: compact,
                          onPressed: () => _openSalesReturnDialog(row),
                        ),
                        SizedBox(width: spacing),
                        if (_canSettleSale(sale)) ...[
                          _SaleActionButton(
                            label: 'تسديد',
                            icon: Icons.account_balance_wallet_outlined,
                            backgroundColor: AppColors.topbarIconOrange,
                            foregroundColor: AppColors.white,
                            compact: compact,
                            onPressed: () => _openSettlementDialog(row),
                          ),
                          SizedBox(width: spacing),
                        ],
                        _SaleActionButton(
                          label: 'تفاصيل',
                          icon: Icons.visibility_outlined,
                          outlined: true,
                          compact: compact,
                          onPressed: () => _openSaleDetails(row),
                        ),
                        SizedBox(width: spacing),
                        _SaleActionButton(
                          label: _printing ? 'جار الطباعة...' : 'طباعة',
                          icon: Icons.print_outlined,
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: AppColors.white,
                          compact: compact,
                          onPressed: _printing ? null : () => _printSale(sale),
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

  Widget _buildReturnCard(ControlPanelSalesReturnRow row) {
    final salesReturn = row.salesReturn;
    final status = _returnStatusMeta(salesReturn);
    final note = (salesReturn.reason ?? '').trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1300;
        final ultraCompact = constraints.maxWidth < 1120;
        final spacing = ultraCompact ? AppSpacing.xs : AppSpacing.sm;

        final pills = <Widget>[
          _InfoPill(
            icon: Icons.calendar_today_outlined,
            label: _dateTime(salesReturn.createdAt),
            compact: compact,
          ),
          _InfoPill(
            icon: Icons.inventory_2_outlined,
            label: '${row.itemsCount} كمية مرتجعة',
            compact: compact,
          ),
          _InfoPill(
            icon: Icons.swap_horiz_outlined,
            label: row.shiftLabel,
            compact: compact,
          ),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          decoration: _panelDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: ultraCompact ? 22 : 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _returnNo(salesReturn),
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: compact ? 14 : 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: spacing),
                        _StatusBadge(
                          label: status.label,
                          color: status.color,
                          compact: compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الفاتورة الأصلية: ${row.originalInvoiceNo}',
                      style: AppTextStyles.fieldText.copyWith(
                        color: AppColors.topbarIconDeepBlue,
                        fontSize: compact ? 12 : 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.originalCustomerName,
                      style: AppTextStyles.fieldHint.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: compact ? 10 : 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.isNotEmpty && !ultraCompact) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: AppTextStyles.fieldHint.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: compact ? 10 : 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 24 : 28,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pills.length; i++) ...[
                          if (i > 0) SizedBox(width: spacing),
                          pills[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 22 : 20,
                child: _SaleMetricTile(
                  label: 'إجمالي المرتجع',
                  value: _money(salesReturn.total),
                  color: AppColors.dangerRed,
                  icon: Icons.assignment_return_outlined,
                  compact: compact,
                ),
              ),
              SizedBox(width: spacing),
              Flexible(
                flex: ultraCompact ? 12 : 14,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _SaleActionButton(
                      label: 'تفاصيل المرتجع',
                      icon: Icons.visibility_outlined,
                      outlined: true,
                      compact: compact,
                      onPressed: () => _openReturnDetails(row),
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

  @override
  Widget build(BuildContext context) {
    return ControlPanelShell(
      section: widget.section,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1680),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            children: [
              _buildHero(),
              const SizedBox(height: AppSpacing.md),
              SalesManagementNavStrip(current: widget.section),
              const SizedBox(height: AppSpacing.md),
              _buildFilterCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutralGrey.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: AppTextStyles.fieldHint),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: AppTextStyles.fieldText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        side: const BorderSide(color: AppColors.fieldBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(label),
    );
  }
}

class _BadgeMeta {
  const _BadgeMeta(this.label, this.color);

  final String label;
  final Color color;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.fieldHint.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleMetricTile extends StatelessWidget {
  const _SaleMetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: compact ? 12 : 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: compact ? 4 : 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.summaryLabel.copyWith(
                    fontSize: compact ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.fieldText.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleActionButton extends StatelessWidget {
  const _SaleActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.outlined = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = outlined
        ? OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: foregroundColor ?? AppColors.pillPurple,
              side: BorderSide(
                color: (foregroundColor ?? AppColors.pillPurple).withValues(
                  alpha: 0.34,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: Icon(icon, size: compact ? 14 : 16),
            label: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? AppColors.primaryBlue,
              foregroundColor: foregroundColor ?? AppColors.white,
              disabledBackgroundColor:
                  (backgroundColor ?? AppColors.primaryBlue).withValues(
                    alpha: 0.55,
                  ),
              disabledForegroundColor: AppColors.white.withValues(alpha: 0.82),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
            ),
            icon: Icon(icon, size: compact ? 14 : 16),
            label: Text(label),
          );

    return DefaultTextStyle.merge(
      style: AppTextStyles.fieldText.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: compact ? 11 : 12,
      ),
      child: child,
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              note,
              style: AppTextStyles.fieldHint.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 34, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.topbarTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.fieldHint,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.topbarTitle),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
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
  late final TextEditingController _dateController;
  final TextEditingController _noteController = TextEditingController();
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
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
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
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
    if (time == null || !mounted) return;

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
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تنفيذ السداد: $error');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 680,
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
                    'تسديد فاتورة آجلة',
                    style: AppTextStyles.topbarTitle.copyWith(fontSize: 15),
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
                children: [
                  Expanded(
                    child: _SaleMetricTile(
                      label: 'الفاتورة',
                      value: widget.sale.invoiceNo ?? '#${widget.sale.localId}',
                      color: AppColors.textPrimary,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleMetricTile(
                      label: 'العميل',
                      value: widget.customerName,
                      color: AppColors.topbarIconDeepBlue,
                      icon: AppIcons.user,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _SaleMetricTile(
                      label: 'الإجمالي',
                      value: '${money.format(widget.sale.total)} ريال',
                      color: AppColors.textPrimary,
                      icon: AppIcons.priceTag,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleMetricTile(
                      label: 'المدفوع',
                      value: '${money.format(widget.sale.paidTotal)} ريال',
                      color: AppColors.successGreen,
                      icon: AppIcons.cash,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SaleMetricTile(
                      label: 'المتبقي',
                      value: '${money.format(widget.sale.remaining)} ريال',
                      color: AppColors.dangerRed,
                      icon: AppIcons.deferred,
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
                        height: 38,
                        borderRadius: 10,
                        fieldPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        enableSearch: false,
                        leadingIcon: AppIcons.cash,
                        leadingIconBoxed: true,
                        leadingIconBoxSize: 22,
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
                        onChanged: (_) => setState(() {}),
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
                      backgroundColor: AppColors.topbarIconOrange,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 11,
                      ),
                    ),
                    child: Text(_saving ? 'جار الحفظ...' : 'تسديد الآن'),
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

class _SaleDetailsDialog extends ConsumerStatefulWidget {
  const _SaleDetailsDialog({required this.saleLocalId});

  final int saleLocalId;

  @override
  ConsumerState<_SaleDetailsDialog> createState() => _SaleDetailsDialogState();
}

class _SaleDetailsDialogState extends ConsumerState<_SaleDetailsDialog> {
  bool _loading = true;
  ControlPanelSaleDetailData? _data;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(controlPanelSalesServiceProvider)
          .loadSaleDetail(widget.saleLocalId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تحميل تفاصيل الفاتورة: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _money(double value) {
    return '${NumberFormat('#,##0.00').format(value)} ريال';
  }

  String _paymentMethodLabel(String code) {
    switch (code.trim().toUpperCase()) {
      case 'CASH':
        return 'كاش';
      case 'CARD':
        return 'بطاقة';
      case 'TRANSFER':
        return 'تحويل';
      case 'CREDIT':
        return 'آجل';
      default:
        return code.trim().isEmpty ? 'غير محدد' : code.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surface,
      child: SizedBox(
        width: 980,
        height: 720,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
            ? const _EmptyPanel(
                title: 'تعذر تحميل التفاصيل',
                subtitle: 'أعد المحاولة لاحقاً.',
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _data!.sale.invoiceNo?.trim().isNotEmpty == true
                                ? _data!.sale.invoiceNo!.trim()
                                : 'فاتورة #${_data!.sale.localId}',
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _InfoPill(
                          icon: Icons.person_outline,
                          label: _data!.customerName,
                        ),
                        if (_data!.serviceName.isNotEmpty)
                          _InfoPill(
                            icon: Icons.room_service_outlined,
                            label: _data!.serviceName,
                          ),
                        if (_data!.tableName.isNotEmpty)
                          _InfoPill(
                            icon: Icons.table_restaurant_outlined,
                            label: _data!.tableName,
                          ),
                        _InfoPill(
                          icon: Icons.schedule_outlined,
                          label: _data!.shiftLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'الإجمالي',
                            value: _money(_data!.sale.total),
                            color: AppColors.textPrimary,
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'المدفوع',
                            value: _money(_data!.sale.paidTotal),
                            color: AppColors.successGreen,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'المتبقي',
                            value: _money(_data!.sale.remaining),
                            color: _data!.sale.remaining > 0.01
                                ? AppColors.dangerRed
                                : AppColors.successGreen,
                            icon: Icons.warning_amber_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _DetailsPanel(
                              title: 'أصناف الفاتورة',
                              child: ListView.separated(
                                itemCount: _data!.items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final item = _data!.items[index];
                                  return Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.fieldBorder,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          item.nameSnapshot.trim().isEmpty
                                              ? 'صنف #${item.productId}'
                                              : item.nameSnapshot.trim(),
                                          style: AppTextStyles.fieldText,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.qty} × ${_money(item.price)} = ${_money(item.total)}',
                                          style: AppTextStyles.fieldHint,
                                        ),
                                        if ((item.note ?? '').trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.xs,
                                            ),
                                            child: Text(
                                              item.note!.trim(),
                                              style: AppTextStyles.fieldHint
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: _DetailsPanel(
                                    title: 'الدفعات',
                                    child: _data!.payments.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'لا توجد دفعات مسجلة',
                                              style: AppTextStyles.fieldHint,
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: _data!.payments.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(
                                                  height: AppSpacing.sm,
                                                ),
                                            itemBuilder: (context, index) {
                                              final payment =
                                                  _data!.payments[index];
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.md,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppColors.backgroundColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        AppColors.fieldBorder,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      _paymentMethodLabel(
                                                        payment.methodCode,
                                                      ),
                                                      style: AppTextStyles
                                                          .fieldText,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _money(payment.amount),
                                                      style: AppTextStyles
                                                          .fieldHint
                                                          .copyWith(
                                                            color: AppColors
                                                                .successGreen,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    if ((payment.reference ??
                                                            '')
                                                        .trim()
                                                        .isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top:
                                                                  AppSpacing.xs,
                                                            ),
                                                        child: Text(
                                                          'مرجع: ${payment.reference!.trim()}',
                                                          style: AppTextStyles
                                                              .fieldHint,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Expanded(
                                  child: _DetailsPanel(
                                    title: 'المرتجعات المرتبطة',
                                    child: _data!.linkedReturns.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'لا توجد مرتجعات مرتبطة',
                                              style: AppTextStyles.fieldHint,
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount:
                                                _data!.linkedReturns.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(
                                                  height: AppSpacing.sm,
                                                ),
                                            itemBuilder: (context, index) {
                                              final salesReturn =
                                                  _data!.linkedReturns[index];
                                              final returnNo =
                                                  salesReturn.returnNo
                                                      ?.trim() ??
                                                  '';
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.md,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppColors.backgroundColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        AppColors.fieldBorder,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      returnNo.isEmpty
                                                          ? 'مرتجع #${salesReturn.localId}'
                                                          : returnNo,
                                                      style: AppTextStyles
                                                          .fieldText,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _money(salesReturn.total),
                                                      style: AppTextStyles
                                                          .fieldHint
                                                          .copyWith(
                                                            color: AppColors
                                                                .dangerRed,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SalesReturnDetailsDialog extends ConsumerStatefulWidget {
  const _SalesReturnDetailsDialog({required this.returnLocalId});

  final int returnLocalId;

  @override
  ConsumerState<_SalesReturnDetailsDialog> createState() =>
      _SalesReturnDetailsDialogState();
}

class _SalesReturnDetailsDialogState
    extends ConsumerState<_SalesReturnDetailsDialog> {
  bool _loading = true;
  ControlPanelSalesReturnDetailData? _data;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(controlPanelSalesServiceProvider)
          .loadReturnDetail(widget.returnLocalId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تحميل تفاصيل المرتجع: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _money(double value) {
    return '${NumberFormat('#,##0.00').format(value)} ريال';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surface,
      child: SizedBox(
        width: 860,
        height: 640,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
            ? const _EmptyPanel(
                title: 'تعذر تحميل تفاصيل المرتجع',
                subtitle: 'أعد المحاولة لاحقاً.',
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _data!.salesReturn.returnNo?.trim().isNotEmpty ==
                                    true
                                ? _data!.salesReturn.returnNo!.trim()
                                : 'مرتجع #${_data!.salesReturn.localId}',
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _InfoPill(
                          icon: Icons.receipt_long_outlined,
                          label: 'الأصل: ${_data!.originalInvoiceNo}',
                        ),
                        _InfoPill(
                          icon: Icons.person_outline,
                          label: _data!.originalCustomerName,
                        ),
                        _InfoPill(
                          icon: Icons.schedule_outlined,
                          label: _data!.shiftLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'إجمالي المرتجع',
                            value: _money(_data!.salesReturn.total),
                            color: AppColors.dangerRed,
                            icon: Icons.assignment_return_outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'الإجمالي قبل الضريبة',
                            value: _money(_data!.salesReturn.subtotal),
                            color: AppColors.textPrimary,
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SaleMetricTile(
                            label: 'الضريبة',
                            value: _money(_data!.salesReturn.tax),
                            color: AppColors.topbarIconDeepBlue,
                            icon: Icons.request_quote_outlined,
                          ),
                        ),
                      ],
                    ),
                    if ((_data!.salesReturn.reason ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _NotePanel(note: _data!.salesReturn.reason!.trim()),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: _DetailsPanel(
                        title: 'الأصناف المرتجعة',
                        child: ListView.separated(
                          itemCount: _data!.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = _data!.items[index];
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.fieldBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    item.nameSnapshot.trim().isEmpty
                                        ? 'صنف #${item.productId}'
                                        : item.nameSnapshot.trim(),
                                    style: AppTextStyles.fieldText,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.qty} × ${_money(item.price)} = ${_money(item.total)}',
                                    style: AppTextStyles.fieldHint,
                                  ),
                                  if ((item.note ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.xs,
                                      ),
                                      child: Text(
                                        item.note!.trim(),
                                        style: AppTextStyles.fieldHint.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
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
