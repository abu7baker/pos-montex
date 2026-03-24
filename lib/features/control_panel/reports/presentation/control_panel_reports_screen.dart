import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/printing/pdf_arabic_fonts.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../cash_management/presentation/widgets/cash_voucher_preview_dialog.dart';
import '../../cash_management/presentation/widgets/cash_management_nav_strip.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelReportsScreen extends ConsumerStatefulWidget {
  const ControlPanelReportsScreen({
    super.key,
    this.section = ControlPanelSection.reportsOverview,
  });

  const ControlPanelReportsScreen.overview({super.key})
    : section = ControlPanelSection.reportsOverview;

  const ControlPanelReportsScreen.sales({super.key})
    : section = ControlPanelSection.reportsSales;

  const ControlPanelReportsScreen.inventory({super.key})
    : section = ControlPanelSection.reportsInventory;

  const ControlPanelReportsScreen.shifts({super.key})
    : section = ControlPanelSection.reportsShifts;

  const ControlPanelReportsScreen.cash({super.key})
    : section = ControlPanelSection.reportsCash;

  final ControlPanelSection section;

  @override
  ConsumerState<ControlPanelReportsScreen> createState() =>
      _ControlPanelReportsScreenState();
}

class _ControlPanelReportsScreenState
    extends ConsumerState<ControlPanelReportsScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _loading = true;
  bool _printing = false;
  bool _exportingExcel = false;
  int? _printingShiftId;
  _ReportsData? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    Future.microtask(_reload);
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
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(appDbProvider);
      final loadedData = await _loadReportsData(
        db,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _data = loadedData);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تحميل التقارير: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _print() async {
    final data = _data;
    if (data == null || _printing) return;
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: 'تقارير النظام',
        onLayout: (format) => _buildReportsPdf(
          data: data,
          pageFormat: format,
          section: widget.section,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر الطباعة: $error');
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  Future<void> _printShiftReport(_ShiftRow shift) async {
    if (_printingShiftId != null) return;
    setState(() => _printingShiftId = shift.shiftLocalId);
    try {
      await Printing.layoutPdf(
        name: 'تقرير الوردية ${shift.shiftNo}',
        onLayout: (format) =>
            _buildSingleShiftPdf(shift: shift, pageFormat: format),
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر طباعة تقرير الوردية: $error');
    } finally {
      if (mounted) {
        setState(() => _printingShiftId = null);
      }
    }
  }

  Future<void> _exportExcel() async {
    final data = _data;
    if (data == null || _exportingExcel) return;
    setState(() => _exportingExcel = true);
    try {
      final bytes = _buildReportsExcel(data: data, section: widget.section);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'reports_${_sectionFileName(widget.section)}_$stamp.xls';
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ التقرير بصيغة Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['xls'],
      );
      if (targetPath == null || targetPath.trim().isEmpty) return;

      await File(targetPath).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      AppFeedback.success(context, 'طھظ… تصدير التقرير بنجاح');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تصدير Excel: $error');
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }

  bool get _isCashReport => widget.section == ControlPanelSection.reportsCash;

  void _openRoute(String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _previewVoucher(_CashMovementReportRow row) {
    return showDialog<void>(
      context: context,
      builder: (_) => CashVoucherPreviewDialog(
        data: CashVoucherPreviewData(
          title: row.title,
          voucherNo: row.voucherNo,
          date: row.date,
          status: row.status,
          partyLabel: row.partyLabel,
          partyValue: row.partyValue,
          paymentMethod: row.paymentMethod,
          accountName: row.accountName,
          amountLabel: _money(row.amount),
          description: row.description,
          note: row.note,
        ),
      ),
    );
  }

  String _sectionSubtitle() {
    switch (widget.section) {
      case ControlPanelSection.reportsCash:
        return 'متابعة سندات القبض والصرف وصافي التدفق النقدي ضمن فترة محددة.';
      case ControlPanelSection.reportsSales:
        return 'عرض سريع للمبيعات والتحصيل وطرق الدفع والعملاء الأكثر نشاطًا.';
      case ControlPanelSection.reportsInventory:
        return 'قراءة حالة المخزون والكميات المباعة والقيمة المتبقية للمنتجات.';
      case ControlPanelSection.reportsShifts:
        return 'تقارير الورديات مع الطباعة المباشرة لكل وردية من نفس الصفحة.';
      case ControlPanelSection.reportsOverview:
        return 'لوحة تقارير موحدة تجمع المبيعات والمخزون والورديات والحركة المالية.';
      default:
        return 'تقارير تشغيلية تفصيلية.';
    }
  }

  Widget _buildSummaryCards(_ReportsData data) {
    if (_isCashReport) {
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _MetricCard(
            'إجمالي سندات القبض',
            _money(data.receiptVoucherTotal),
            icon: Icons.south_west_rounded,
            accentColor: AppColors.successGreen,
          ),
          _MetricCard(
            'إجمالي سندات الصرف',
            _money(data.paymentVoucherTotal),
            icon: Icons.north_east_rounded,
            accentColor: AppColors.dangerRed,
          ),
          _MetricCard(
            'صافي الحركة النقدية',
            _money(data.cashNetTotal),
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AppColors.primaryBlue,
          ),
          _MetricCard(
            'عدد سندات القبض',
            '${data.receiptVoucherCount}',
            icon: Icons.receipt_long,
            accentColor: AppColors.topbarIconDeepBlue,
          ),
          _MetricCard(
            'عدد سندات الصرف',
            '${data.paymentVoucherCount}',
            icon: Icons.outbox_outlined,
            accentColor: AppColors.warningPurple,
          ),
          _MetricCard(
            'إجمالي الحركة',
            '${data.cashMovementRows.length}',
            icon: Icons.swap_horiz_outlined,
            accentColor: AppColors.topbarIconIndigo,
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetricCard('عدد الفواتير', '${data.invoiceCount}'),
        _MetricCard('إجمالي المبيعات', _money(data.salesTotal)),
        _MetricCard('إجمالي المحصل', _money(data.collectedTotal)),
        _MetricCard('المتبقي', _money(data.remainingTotal)),
        _MetricCard('مدفوعات المصروفات', _money(data.expensesTotal)),
        _MetricCard('مرتجعات المبيعات', _money(data.salesReturnsTotal)),
        _MetricCard('صافي الحركة', _money(data.netMovement)),
      ],
    );
  }

  Widget _buildCashMovementSection(_ReportsData data) {
    return _CashMovementSectionCard(
      rows: data.cashMovementRows,
      onOpenCashManagement: () =>
          _openRoute(AppRoutes.controlPanelCashMovements),
      onOpenVoucher: _previewVoucher,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final data = _data;

    return ControlPanelShell(
      section: widget.section,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1720),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.topbarIconDeepBlue,
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _isCashReport
                                ? Icons.account_balance_wallet_outlined
                                : Icons.assessment_outlined,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _sectionTitle(widget.section),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sectionSubtitle(),
                                style: TextStyle(
                                  color: AppColors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.end,
                      children: [
                        _DateChip(
                          label: 'من: ${dateFormat.format(_fromDate)}',
                          onTap: _pickFromDate,
                        ),
                        _DateChip(
                          label: 'إلى: ${dateFormat.format(_toDate)}',
                          onTap: _pickToDate,
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _reload,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.white),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('تحديث'),
                        ),
                        ElevatedButton.icon(
                          onPressed: (_loading || data == null || _printing)
                              ? null
                              : _print,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: AppColors.white,
                          ),
                          icon: const Icon(Icons.print, size: 16),
                          label: Text(
                            _printing ? 'جارٍ الطباعة...' : 'طباعة PDF',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              (_loading || data == null || _exportingExcel)
                              ? null
                              : _exportExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warningPurple,
                            foregroundColor: AppColors.white,
                          ),
                          icon: const Icon(Icons.table_view_rounded, size: 16),
                          label: Text(
                            _exportingExcel ? 'جارٍ التصدير...' : 'تصدير Excel',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isCashReport) ...[
                const SizedBox(height: AppSpacing.md),
                const CashManagementNavStrip(
                  current: ControlPanelSection.reportsCash,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (data == null)
                _emptyCard('لا توجد بيانات للفترة المحددة')
              else
                _buildReportBody(data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportBody(_ReportsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCards(data),
        const SizedBox(height: AppSpacing.lg),
        if (_showSalesSection(widget.section)) ...[
          _ReportTableCard(
            title: 'طرق الدفع',
            headers: const ['الطريقة', 'عدد العمليات', 'الإجمالي'],
            rows: data.paymentRows
                .map((e) => [e.method, '${e.count}', _money(e.amount)])
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportTableCard(
            title: 'أفضل المنتجات',
            headers: const ['المنتج', 'الكمية', 'الإجمالي'],
            rows: data.topProducts
                .map(
                  (e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)],
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportTableCard(
            title: 'أفضل الأقسام',
            headers: const ['القسم', 'الكمية', 'الإجمالي'],
            rows: data.topCategories
                .map(
                  (e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)],
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportTableCard(
            title: 'أفضل العملاء',
            headers: const ['العميل', 'عدد الفواتير', 'الإجمالي'],
            rows: data.topCustomers
                .map((e) => [e.name, '${e.count}', _money(e.amount)])
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_showInventorySection(widget.section)) ...[
          _ReportTableCard(
            title: 'تقرير المخزون',
            headers: const ['المنتج', 'مباع', 'المتبقي', 'قيمة المتبقي'],
            rows: data.stockRows
                .map(
                  (e) => [
                    e.name,
                    e.soldQty.toStringAsFixed(2),
                    e.remainingQty.toStringAsFixed(2),
                    _money(e.remainingValue),
                  ],
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_showShiftsSection(widget.section))
          _ShiftReportTableCard(
            rows: data.shiftRows,
            printingShiftId: _printingShiftId,
            onPrintShift: _printShiftReport,
          ),
        if (_showCashSection(widget.section)) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildCashMovementSection(data),
        ],
      ],
    );
  }

  bool _showSalesSection(ControlPanelSection section) {
    return section == ControlPanelSection.reportsOverview ||
        section == ControlPanelSection.reportsSales;
  }

  bool _showInventorySection(ControlPanelSection section) {
    return section == ControlPanelSection.reportsOverview ||
        section == ControlPanelSection.reportsInventory;
  }

  bool _showShiftsSection(ControlPanelSection section) {
    return section == ControlPanelSection.reportsOverview ||
        section == ControlPanelSection.reportsShifts;
  }

  bool _showCashSection(ControlPanelSection section) {
    return section == ControlPanelSection.reportsOverview ||
        section == ControlPanelSection.reportsCash;
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.title, this.value, {this.icon, this.accentColor});

  final String title;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.topbarIconDeepBlue;
    return Container(
      width: 255,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: AppTextStyles.summaryLabel.copyWith(color: color),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.topbarTitle,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _ReportTableCard extends StatelessWidget {
  const _ReportTableCard({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutralGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.topbarTitle,
                    textAlign: TextAlign.right,
                  ),
                ),
                _CountBadge(value: rows.length),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('لا توجد بيانات', textAlign: TextAlign.center),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTextStyles.cartHeaderStyle,
                dataTextStyle: AppTextStyles.fieldText,
                headingRowColor: WidgetStatePropertyAll(
                  AppColors.neutralGrey.withValues(alpha: 0.25),
                ),
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columnSpacing: 22,
                columns: headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      color: i.isEven
                          ? null
                          : WidgetStatePropertyAll(
                              AppColors.fieldBackground.withValues(alpha: 0.4),
                            ),
                      cells: rows[i]
                          .map((cell) => DataCell(Text(cell)))
                          .toList(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftReportTableCard extends StatelessWidget {
  const _ShiftReportTableCard({
    required this.rows,
    required this.printingShiftId,
    required this.onPrintShift,
  });

  final List<_ShiftRow> rows;
  final int? printingShiftId;
  final ValueChanged<_ShiftRow> onPrintShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutralGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                  child: Text(
                    'تقرير الورديات',
                    style: AppTextStyles.topbarTitle,
                    textAlign: TextAlign.right,
                  ),
                ),
                _CountBadge(value: rows.length),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('لا توجد ورديات ظپظٹ الفترة المحددة'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTextStyles.cartHeaderStyle,
                dataTextStyle: AppTextStyles.fieldText,
                headingRowColor: WidgetStatePropertyAll(
                  AppColors.neutralGrey.withValues(alpha: 0.25),
                ),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('رقم الوردية')),
                  DataColumn(label: Text('الافتتاح')),
                  DataColumn(label: Text('الإغلاق')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('عدد الفواتير')),
                  DataColumn(label: Text('المبيعات')),
                  DataColumn(label: Text('درج النقدية')),
                  DataColumn(label: Text('طباعة')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      color: i.isEven
                          ? null
                          : WidgetStatePropertyAll(
                              AppColors.fieldBackground.withValues(alpha: 0.4),
                            ),
                      cells: [
                        DataCell(Text(rows[i].shiftNo)),
                        DataCell(Text(rows[i].openedAt)),
                        DataCell(Text(rows[i].closedAt)),
                        DataCell(Text(rows[i].status)),
                        DataCell(Text('${rows[i].invoicesCount}')),
                        DataCell(Text(_money(rows[i].salesTotal))),
                        DataCell(Text(_money(rows[i].actualCash))),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: printingShiftId == null
                                ? () => onPrintShift(rows[i])
                                : null,
                            icon: const Icon(Icons.print, size: 14),
                            label: Text(
                              printingShiftId == rows[i].shiftLocalId
                                  ? 'جارٍ الطباعة...'
                                  : 'طباعة',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CashMovementSectionCard extends StatelessWidget {
  const _CashMovementSectionCard({
    required this.rows,
    required this.onOpenCashManagement,
    required this.onOpenVoucher,
  });

  final List<_CashMovementReportRow> rows;
  final VoidCallback onOpenCashManagement;
  final ValueChanged<_CashMovementReportRow> onOpenVoucher;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.topbarIconDeepBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_outlined,
                        size: 20,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'الحركة النقدية',
                      style: AppTextStyles.topbarTitle,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _CountBadge(value: rows.length),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Tooltip(
                      message: 'العودة إلى إدارة النقدية',
                      child: OutlinedButton.icon(
                        onPressed: onOpenCashManagement,
                        icon: const Icon(Icons.reply_outlined, size: 16),
                        label: const Text('العودة لإدارة النقدية'),
                      ),
                    ),
                    Tooltip(
                      message: 'فتح صفحة حركة الصندوق',
                      child: OutlinedButton.icon(
                        onPressed: onOpenCashManagement,
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                        ),
                        label: const Text('حركة الصندوق'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'لا توجد حركة نقدية ضمن الفترة المحددة',
                textAlign: TextAlign.center,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTextStyles.cartHeaderStyle,
                dataTextStyle: AppTextStyles.fieldText,
                headingRowColor: WidgetStatePropertyAll(
                  AppColors.neutralGrey.withValues(alpha: 0.25),
                ),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('رقم السند')),
                  DataColumn(label: Text('البيان')),
                  DataColumn(label: Text('داخل')),
                  DataColumn(label: Text('خارج')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      color: i.isEven
                          ? null
                          : WidgetStatePropertyAll(
                              AppColors.fieldBackground.withValues(alpha: 0.4),
                            ),
                      cells: [
                        DataCell(Text(rows[i].date)),
                        DataCell(Text(rows[i].source)),
                        DataCell(Text(rows[i].voucherNo)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              rows[i].description,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            rows[i].incoming > 0
                                ? _money(rows[i].incoming)
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            rows[i].outgoing > 0
                                ? _money(rows[i].outgoing)
                                : '-',
                          ),
                        ),
                        DataCell(_CashStatusBadge(status: rows[i].status)),
                        DataCell(
                          Tooltip(
                            message: 'معاينة السند',
                            child: OutlinedButton.icon(
                              onPressed: () => onOpenVoucher(rows[i]),
                              icon: const Icon(
                                Icons.preview_outlined,
                                size: 16,
                              ),
                              label: const Text('عرض السند'),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CashStatusBadge extends StatelessWidget {
  const _CashStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim();
    final isVoid = normalized == 'مبطل';
    final color = isVoid ? AppColors.dangerRed : AppColors.successGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '$value',
        style: AppTextStyles.summaryLabel.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Widget _emptyCard(String text) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.neutralGrey),
    ),
    child: Text(
      text,
      style: AppTextStyles.summaryLabel,
      textAlign: TextAlign.center,
    ),
  );
}

String _money(double value) => '${NumberFormat('#,##0.00').format(value)} ريال';

String _sectionTitle(ControlPanelSection section) {
  switch (section) {
    case ControlPanelSection.reportsSales:
      return 'تقارير المبيعات';
    case ControlPanelSection.reportsInventory:
      return 'تقارير المخزون';
    case ControlPanelSection.reportsShifts:
      return 'تقارير الورديات';
    case ControlPanelSection.reportsCash:
      return 'تقارير النقدية';
    case ControlPanelSection.reportsOverview:
      return 'التقارير الشاملة';
    default:
      return 'تقارير النظام';
  }
}

Future<_ReportsData> _loadReportsData(
  AppDb db, {
  required DateTime fromDate,
  required DateTime toDate,
}) async {
  final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
  final toExclusive = DateTime(
    toDate.year,
    toDate.month,
    toDate.day,
  ).add(const Duration(days: 1));

  final allSales = await db.select(db.sales).get();
  final sales = allSales
      .where(
        (sale) =>
            !sale.createdAt.isBefore(from) &&
            sale.createdAt.isBefore(toExclusive) &&
            sale.status.trim().toUpperCase() != 'QUOTATION',
      )
      .toList();
  final saleIds = sales.map((e) => e.localId).toSet().toList();

  final saleItems = saleIds.isEmpty
      ? <SaleItemDb>[]
      : await (db.select(
          db.saleItems,
        )..where((t) => t.saleLocalId.isIn(saleIds))).get();

  final salePayments = saleIds.isEmpty
      ? <SalePaymentDb>[]
      : await (db.select(
          db.salePayments,
        )..where((t) => t.saleLocalId.isIn(saleIds))).get();

  final allSalesReturns = await db.select(db.salesReturns).get();
  final salesReturns = allSalesReturns
      .where(
        (row) =>
            !row.createdAt.isBefore(from) &&
            row.createdAt.isBefore(toExclusive),
      )
      .toList();

  final allPaymentVouchers = await (db.select(
    db.paymentVouchers,
  )..where((t) => t.isDeleted.equals(false))).get();
  final paymentVouchers = allPaymentVouchers
      .where(
        (row) =>
            !row.createdAt.isBefore(from) &&
            row.createdAt.isBefore(toExclusive),
      )
      .toList();

  final allReceiptVouchers = await (db.select(
    db.receiptVouchers,
  )..where((t) => t.isDeleted.equals(false))).get();
  final receiptVouchers = allReceiptVouchers
      .where(
        (row) =>
            !row.createdAt.isBefore(from) &&
            row.createdAt.isBefore(toExclusive),
      )
      .toList();

  final products = await (db.select(
    db.products,
  )..where((t) => t.isDeleted.equals(false))).get();
  final categories = await (db.select(
    db.productCategories,
  )..where((t) => t.isDeleted.equals(false))).get();
  final allShifts = await db.select(db.shifts).get();

  final customers = await db.select(db.customers).get();

  final customerById = {for (final c in customers) c.id: c};
  final categoryById = {for (final c in categories) c.id: c};
  final productById = {for (final p in products) p.id: p};

  final salesTotal = sales.fold<double>(0, (sum, row) => sum + row.total);
  final collectedTotal = sales.fold<double>(
    0,
    (sum, row) => sum + row.paidTotal,
  );
  final remainingTotal = sales.fold<double>(
    0,
    (sum, row) => sum + row.remaining,
  );

  final salesReturnsTotal = salesReturns
      .where((row) => _isActiveStatus(row.status))
      .fold<double>(0, (sum, row) => sum + row.total);

  final expensesTotal = paymentVouchers
      .where((row) => _isActiveStatus(row.status))
      .fold<double>(0, (sum, row) => sum + row.amount);

  final receiptTotal = receiptVouchers
      .where((row) => _isActiveStatus(row.status))
      .fold<double>(0, (sum, row) => sum + row.amount);

  final paymentAgg = <String, _PaymentAgg>{};
  for (final payment in salePayments) {
    final method = _paymentMethodLabel(payment.methodCode.trim().toUpperCase());
    final old = paymentAgg[method] ?? const _PaymentAgg();
    paymentAgg[method] = _PaymentAgg(
      count: old.count + 1,
      amount: old.amount + payment.amount,
    );
  }
  final paymentRows =
      paymentAgg.entries
          .map(
            (e) => _PaymentMethodRow(
              method: e.key,
              count: e.value.count,
              amount: e.value.amount,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final productAgg = <String, _AmountQtyAgg>{};
  final categoryAgg = <String, _AmountQtyAgg>{};
  final soldQtyByProduct = <int, double>{};

  for (final item in saleItems) {
    soldQtyByProduct[item.productId] =
        (soldQtyByProduct[item.productId] ?? 0) + item.qty.toDouble();

    final mappedProduct = productById[item.productId];
    final productName = item.nameSnapshot.trim().isNotEmpty
        ? item.nameSnapshot.trim()
        : (mappedProduct?.name.trim().isNotEmpty == true
              ? mappedProduct!.name.trim()
              : 'منتج #${item.productId}');

    final oldProduct = productAgg[productName] ?? const _AmountQtyAgg();
    productAgg[productName] = _AmountQtyAgg(
      amount: oldProduct.amount + item.total,
      qty: oldProduct.qty + item.qty.toDouble(),
    );

    final categoryId = item.categoryId ?? mappedProduct?.categoryId;
    final snapshotCategory = item.categoryNameSnapshot?.trim() ?? '';
    final categoryName = snapshotCategory.isNotEmpty
        ? snapshotCategory
        : (categoryId == null
              ? 'بدون قسم'
              : (categoryById[categoryId]?.name.trim().isNotEmpty == true
                    ? categoryById[categoryId]!.name.trim()
                    : 'بدون قسم'));

    final oldCategory = categoryAgg[categoryName] ?? const _AmountQtyAgg();
    categoryAgg[categoryName] = _AmountQtyAgg(
      amount: oldCategory.amount + item.total,
      qty: oldCategory.qty + item.qty.toDouble(),
    );
  }

  final topProducts =
      productAgg.entries
          .map(
            (e) => _TopAmountQtyRow(
              name: e.key,
              qty: e.value.qty,
              amount: e.value.amount,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final topCategories =
      categoryAgg.entries
          .map(
            (e) => _TopAmountQtyRow(
              name: e.key,
              qty: e.value.qty,
              amount: e.value.amount,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final customerAgg = <String, _CustomerAgg>{};
  for (final sale in sales) {
    final customerName = sale.customerId == null
        ? 'عميل عام'
        : (customerById[sale.customerId!]?.name.trim().isNotEmpty == true
              ? customerById[sale.customerId!]!.name.trim()
              : 'عميل عام');
    final old = customerAgg[customerName] ?? const _CustomerAgg();
    customerAgg[customerName] = _CustomerAgg(
      count: old.count + 1,
      amount: old.amount + sale.total,
    );
  }

  final topCustomers =
      customerAgg.entries
          .map(
            (e) => _TopCustomerRow(
              name: e.key,
              count: e.value.count,
              amount: e.value.amount,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final stockRows =
      products
          .where((p) => p.isActive && !p.isDeleted)
          .map(
            (p) => _StockRow(
              name: p.name.trim().isNotEmpty ? p.name.trim() : 'منتج #${p.id}',
              soldQty: soldQtyByProduct[p.id] ?? 0,
              remainingQty: p.stock.toDouble(),
              remainingValue: p.stock * p.price,
            ),
          )
          .toList()
        ..sort((a, b) => b.soldQty.compareTo(a.soldQty));

  final shiftSales = <int, _ShiftSalesAgg>{};
  for (final sale in sales) {
    final shiftId = sale.shiftLocalId;
    if (shiftId == null) continue;
    final old = shiftSales[shiftId] ?? const _ShiftSalesAgg();
    shiftSales[shiftId] = _ShiftSalesAgg(
      invoicesCount: old.invoicesCount + 1,
      salesTotal: old.salesTotal + sale.total,
    );
  }

  final shifts = allShifts.where((shift) {
    final closedAt = shift.closedAt ?? DateTime.now();
    return !shift.openedAt.isAfter(toExclusive) && !closedAt.isBefore(from);
  }).toList()..sort((a, b) => b.openedAt.compareTo(a.openedAt));

  final shiftRows = shifts.map((shift) {
    final agg = shiftSales[shift.localId] ?? const _ShiftSalesAgg();
    final status = shift.status.trim().toUpperCase();
    final isOpen = status == 'OPEN' && shift.closedAt == null;
    return _ShiftRow(
      shiftLocalId: shift.localId,
      shiftNo: shift.shiftNo?.trim().isNotEmpty == true
          ? shift.shiftNo!.trim()
          : '#${shift.localId}',
      openedAt: _formatDateTime(shift.openedAt),
      closedAt: shift.closedAt == null ? '-' : _formatDateTime(shift.closedAt!),
      status: isOpen ? 'مفتوحة' : 'مغلقة',
      invoicesCount: agg.invoicesCount,
      salesTotal: agg.salesTotal,
      actualCash: shift.actualCash,
    );
  }).toList();

  final cashMovementRows = <({DateTime date, _CashMovementReportRow row})>[
    ...receiptVouchers.map((row) {
      final customerName = row.customerId == null
          ? 'عميل عام'
          : (customerById[row.customerId!]?.name.trim().isNotEmpty == true
                ? customerById[row.customerId!]!.name.trim()
                : 'عميل #${row.customerId}');
      final description = row.note?.trim().isNotEmpty == true
          ? row.note!.trim()
          : (row.reference?.trim().isNotEmpty == true
                ? row.reference!.trim()
                : 'سند قبض');
      return (
        date: row.createdAt,
        row: _CashMovementReportRow(
          date: _formatDateTime(row.createdAt),
          source: 'سند قبض',
          voucherNo: row.voucherNo?.trim().isNotEmpty == true
              ? row.voucherNo!.trim()
              : '#${row.localId}',
          description: description,
          incoming: row.amount,
          outgoing: 0,
          status: _voucherStatusLabel(row.status),
          title: 'سند قبض',
          partyLabel: 'العميل',
          partyValue: customerName,
          paymentMethod: _paymentMethodLabel(
            row.paymentMethodCode.trim().toUpperCase(),
          ),
          accountName: _receiptAccountLabel(row.reference),
          note: row.note?.trim(),
          amount: row.amount,
          targetRoute: AppRoutes.controlPanelCashReceipts,
        ),
      );
    }),
    ...paymentVouchers.map((row) {
      final description = row.note?.trim().isNotEmpty == true
          ? row.note!.trim()
          : row.expenseType.trim();
      return (
        date: row.createdAt,
        row: _CashMovementReportRow(
          date: _formatDateTime(row.createdAt),
          source: 'سند صرف',
          voucherNo: row.voucherNo?.trim().isNotEmpty == true
              ? row.voucherNo!.trim()
              : '#${row.localId}',
          description: description.isEmpty ? 'سند صرف' : description,
          incoming: 0,
          outgoing: row.amount,
          status: _voucherStatusLabel(row.status),
          title: 'سند صرف',
          partyLabel: 'المورد/الجهة',
          partyValue: row.expenseType.trim().isEmpty
              ? 'جهة عامة'
              : row.expenseType.trim(),
          paymentMethod: _paymentMethodLabel(
            _paymentReferencePart(
              row.reference,
              key: 'PAYMENT',
              fallback: 'CASH',
            ).toUpperCase(),
          ),
          accountName: _paymentAccountLabel(row.reference),
          note: row.note?.trim(),
          amount: row.amount,
          targetRoute: AppRoutes.controlPanelCashPayments,
        ),
      );
    }),
  ]..sort((a, b) => b.date.compareTo(a.date));

  final receiptVoucherCount = receiptVouchers.length;
  final paymentVoucherCount = paymentVouchers.length;
  final totalIn = collectedTotal + receiptTotal;
  final totalOut = expensesTotal + salesReturnsTotal;

  return _ReportsData(
    fromDate: from,
    toDate: toExclusive.subtract(const Duration(milliseconds: 1)),
    invoiceCount: sales.length,
    salesTotal: salesTotal,
    collectedTotal: collectedTotal,
    remainingTotal: remainingTotal,
    expensesTotal: expensesTotal,
    salesReturnsTotal: salesReturnsTotal,
    netMovement: totalIn - totalOut,
    receiptVoucherCount: receiptVoucherCount,
    paymentVoucherCount: paymentVoucherCount,
    receiptVoucherTotal: receiptTotal,
    paymentVoucherTotal: expensesTotal,
    cashNetTotal: receiptTotal - expensesTotal,
    paymentRows: paymentRows,
    topProducts: topProducts.take(20).toList(),
    topCategories: topCategories.take(20).toList(),
    topCustomers: topCustomers.take(20).toList(),
    stockRows: stockRows.take(80).toList(),
    shiftRows: shiftRows,
    cashMovementRows: cashMovementRows.map((e) => e.row).toList(),
  );
}

bool _isActiveStatus(String status) {
  final value = status.trim().toUpperCase();
  if (value.isEmpty) return true;
  return value != 'CANCELLED' &&
      value != 'CANCELED' &&
      value != 'VOID' &&
      value != 'DELETED';
}

String _paymentMethodLabel(String code) =>
    PaymentMethods.labelForCode(code);

String _receiptAccountLabel(String? reference) {
  final raw = (reference ?? '').trim().toUpperCase();
  if (raw.isEmpty || raw == 'NONE') return 'لا يوجد';
  if (raw == 'MAIN_CASHBOX') return 'الصندوق الرئيسي';
  return raw;
}

String _paymentReferencePart(
  String? reference, {
  required String key,
  String fallback = '',
}) {
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

String _paymentAccountLabel(String? reference) {
  final account = _paymentReferencePart(
    reference,
    key: 'ACCOUNT',
    fallback: 'NONE',
  ).toUpperCase();
  if (account.isEmpty || account == 'NONE') return 'لا يوجد';
  if (account == 'MAIN_CASHBOX') return 'الصندوق الرئيسي';
  return account;
}

String _voucherStatusLabel(String status) {
  final value = status.trim().toUpperCase();
  if (value == 'ACTIVE') return 'نشط';
  if (value == 'VOID') return 'مبطل';
  if (value == 'CANCELLED' || value == 'CANCELED') return 'ملغي';
  if (value == 'DELETED') return 'محذوف';
  if (value.isEmpty) return 'نشط';
  return value;
}

String _formatDateTime(DateTime value) =>
    DateFormat('yyyy-MM-dd HH:mm').format(value);

Future<Uint8List> _buildReportsPdf({
  required _ReportsData data,
  required PdfPageFormat pageFormat,
  required ControlPanelSection section,
}) async {
  final fonts = await PdfArabicFonts.load();
  final regular = fonts.regular;
  final bold = fonts.bold;

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final content = <pw.Widget>[
    pw.Center(
      child: pw.Text(
        _sectionTitle(section),
        style: pw.TextStyle(font: bold, fontSize: 17),
      ),
    ),
    pw.SizedBox(height: 8),
    _pdfTable(
      headers: const ['المؤشر', 'القيمة'],
      rows: [
        [
          'الفترة',
          '${DateFormat('yyyy-MM-dd').format(data.fromDate)} - ${DateFormat('yyyy-MM-dd').format(data.toDate)}',
        ],
        ['عدد الفواتير', '${data.invoiceCount}'],
        ['إجمالي المبيعات', _money(data.salesTotal)],
        ['إجمالي المحصل', _money(data.collectedTotal)],
        ['المتبقي', _money(data.remainingTotal)],
        ['مدفوعات المصروفات', _money(data.expensesTotal)],
        ['مرتجعات المبيعات', _money(data.salesReturnsTotal)],
        ['صافي الحركة', _money(data.netMovement)],
      ],
      regular: regular,
      bold: bold,
    ),
  ];

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsSales) {
    content.addAll([
      pw.SizedBox(height: 8),
      _pdfTitle('طرق الدفع', bold),
      _pdfTable(
        headers: const ['الطريقة', 'عدد العمليات', 'الإجمالي'],
        rows: data.paymentRows
            .map((e) => [e.method, '${e.count}', _money(e.amount)])
            .toList(),
        regular: regular,
        bold: bold,
      ),
      pw.SizedBox(height: 8),
      _pdfTitle('أفضل المنتجات', bold),
      _pdfTable(
        headers: const ['المنتج', 'الكمية', 'الإجمالي'],
        rows: data.topProducts
            .map((e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)])
            .toList(),
        regular: regular,
        bold: bold,
      ),
      pw.SizedBox(height: 8),
      _pdfTitle('أفضل الأقسام', bold),
      _pdfTable(
        headers: const ['القسم', 'الكمية', 'الإجمالي'],
        rows: data.topCategories
            .map((e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)])
            .toList(),
        regular: regular,
        bold: bold,
      ),
      pw.SizedBox(height: 8),
      _pdfTitle('أفضل العملاء', bold),
      _pdfTable(
        headers: const ['العميل', 'عدد الفواتير', 'الإجمالي'],
        rows: data.topCustomers
            .map((e) => [e.name, '${e.count}', _money(e.amount)])
            .toList(),
        regular: regular,
        bold: bold,
      ),
    ]);
  }

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsInventory) {
    content.addAll([
      pw.SizedBox(height: 8),
      _pdfTitle('تقرير المخزون', bold),
      _pdfTable(
        headers: const ['المنتج', 'مباع', 'المتبقي', 'قيمة المتبقي'],
        rows: data.stockRows
            .map(
              (e) => [
                e.name,
                e.soldQty.toStringAsFixed(2),
                e.remainingQty.toStringAsFixed(2),
                _money(e.remainingValue),
              ],
            )
            .toList(),
        regular: regular,
        bold: bold,
      ),
    ]);
  }

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsShifts) {
    content.addAll([
      pw.SizedBox(height: 8),
      _pdfTitle('تقرير الورديات', bold),
      _pdfTable(
        headers: const [
          'رقم الوردية',
          'الافتتاح',
          'الإغلاق',
          'الحالة',
          'عدد الفواتير',
          'المبيعات',
          'درج النقدية',
        ],
        rows: data.shiftRows
            .map(
              (e) => [
                e.shiftNo,
                e.openedAt,
                e.closedAt,
                e.status,
                '${e.invoicesCount}',
                _money(e.salesTotal),
                _money(e.actualCash),
              ],
            )
            .toList(),
        regular: regular,
        bold: bold,
      ),
    ]);
  }
  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsCash) {
    content.addAll([
      pw.SizedBox(height: 8),
      _pdfTitle('تقرير الحركة النقدية', bold),
      _pdfTable(
        headers: const [
          'التاريخ',
          'النوع',
          'رقم السند',
          'البيان',
          'داخل',
          'خارج',
          'الحالة',
        ],
        rows: data.cashMovementRows
            .map(
              (e) => [
                e.date,
                e.source,
                e.voucherNo,
                e.description,
                _money(e.incoming),
                _money(e.outgoing),
                e.status,
              ],
            )
            .toList(),
        regular: regular,
        bold: bold,
      ),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: content,
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildSingleShiftPdf({
  required _ShiftRow shift,
  required PdfPageFormat pageFormat,
}) async {
  final fonts = await PdfArabicFonts.load();
  final regular = fonts.regular;
  final bold = fonts.bold;

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'تقرير الوردية ${shift.shiftNo}',
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 8),
              _pdfTable(
                headers: const ['البيان', 'القيمة'],
                rows: [
                  ['رقم الوردية', shift.shiftNo],
                  ['الافتتاح', shift.openedAt],
                  ['الإغلاق', shift.closedAt],
                  ['الحالة', shift.status],
                  ['عدد الفواتير', '${shift.invoicesCount}'],
                  ['إجمالي المبيعات', _money(shift.salesTotal)],
                  ['درج النقدية', _money(shift.actualCash)],
                ],
                regular: regular,
                bold: bold,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List _buildReportsExcel({
  required _ReportsData data,
  required ControlPanelSection section,
}) {
  final summaryRows = <List<String>>[
    ['المؤشر', 'القيمة'],
    [
      'الفترة',
      '${DateFormat('yyyy-MM-dd').format(data.fromDate)} - ${DateFormat('yyyy-MM-dd').format(data.toDate)}',
    ],
    ['عدد الفواتير', '${data.invoiceCount}'],
    ['إجمالي المبيعات', _money(data.salesTotal)],
    ['إجمالي المحصل', _money(data.collectedTotal)],
    ['المتبقي', _money(data.remainingTotal)],
    ['مدفوعات المصروفات', _money(data.expensesTotal)],
    ['مرتجعات المبيعات', _money(data.salesReturnsTotal)],
    ['صافي الحركة', _money(data.netMovement)],
  ];

  final sheets = <String, List<List<String>>>{'الملخص': summaryRows};

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsSales) {
    sheets['طرق الدفع'] = <List<String>>[
      ['الطريقة', 'عدد العمليات', 'الإجمالي'],
      ...data.paymentRows.map(
        (e) => [e.method, '${e.count}', _money(e.amount)],
      ),
    ];
    sheets['أفضل المنتجات'] = <List<String>>[
      ['المنتج', 'الكمية', 'الإجمالي'],
      ...data.topProducts.map(
        (e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)],
      ),
    ];
    sheets['أفضل الأقسام'] = <List<String>>[
      ['القسم', 'الكمية', 'الإجمالي'],
      ...data.topCategories.map(
        (e) => [e.name, e.qty.toStringAsFixed(2), _money(e.amount)],
      ),
    ];
    sheets['أفضل العملاء'] = <List<String>>[
      ['العميل', 'عدد الفواتير', 'الإجمالي'],
      ...data.topCustomers.map((e) => [e.name, '${e.count}', _money(e.amount)]),
    ];
  }

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsInventory) {
    sheets['المخزون'] = <List<String>>[
      ['المنتج', 'مباع', 'المتبقي', 'قيمة المتبقي'],
      ...data.stockRows.map(
        (e) => [
          e.name,
          e.soldQty.toStringAsFixed(2),
          e.remainingQty.toStringAsFixed(2),
          _money(e.remainingValue),
        ],
      ),
    ];
  }

  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsShifts) {
    sheets['الورديات'] = <List<String>>[
      [
        'رقم الوردية',
        'الافتتاح',
        'الإغلاق',
        'الحالة',
        'عدد الفواتير',
        'المبيعات',
        'درج النقدية',
      ],
      ...data.shiftRows.map(
        (e) => [
          e.shiftNo,
          e.openedAt,
          e.closedAt,
          e.status,
          '${e.invoicesCount}',
          _money(e.salesTotal),
          _money(e.actualCash),
        ],
      ),
    ];
  }
  if (section == ControlPanelSection.reportsOverview ||
      section == ControlPanelSection.reportsCash) {
    sheets['الحركة النقدية'] = <List<String>>[
      ['التاريخ', 'النوع', 'رقم السند', 'البيان', 'داخل', 'خارج', 'الحالة'],
      ...data.cashMovementRows.map(
        (e) => [
          e.date,
          e.source,
          e.voucherNo,
          e.description,
          _money(e.incoming),
          _money(e.outgoing),
          e.status,
        ],
      ),
    ];
  }

  final xml = StringBuffer()
    ..writeln('<?xml version="1.0"?>')
    ..writeln('<?mso-application progid="Excel.Sheet"?>')
    ..writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:x="urn:schemas-microsoft-com:office:excel" '
      'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
    );

  for (final entry in sheets.entries) {
    xml.writeln(_buildExcelWorksheet(entry.key, entry.value));
  }
  xml.writeln('</Workbook>');
  return Uint8List.fromList(utf8.encode(xml.toString()));
}

String _buildExcelWorksheet(String name, List<List<String>> rows) {
  final safeName = _excelSafeSheetName(name);
  final xml = StringBuffer()
    ..writeln('<Worksheet ss:Name="${_xmlEscape(safeName)}">')
    ..writeln('<Table>');

  for (final row in rows) {
    xml.writeln('<Row>');
    for (final cell in row) {
      xml.writeln(
        '<Cell><Data ss:Type="String">${_xmlEscape(cell)}</Data></Cell>',
      );
    }
    xml.writeln('</Row>');
  }

  xml
    ..writeln('</Table>')
    ..writeln('</Worksheet>');
  return xml.toString();
}

String _excelSafeSheetName(String name) {
  final sanitized = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
  if (sanitized.isEmpty) return 'Sheet';
  if (sanitized.length <= 31) return sanitized;
  return sanitized.substring(0, 31);
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _sectionFileName(ControlPanelSection section) {
  switch (section) {
    case ControlPanelSection.reportsSales:
      return 'sales';
    case ControlPanelSection.reportsInventory:
      return 'inventory';
    case ControlPanelSection.reportsShifts:
      return 'shifts';
    case ControlPanelSection.reportsCash:
      return 'cash';
    case ControlPanelSection.reportsOverview:
      return 'overview';
    default:
      return 'reports';
  }
}

pw.Widget _pdfTitle(String title, pw.Font bold) {
  return pw.Text(
    title,
    textAlign: pw.TextAlign.right,
    style: pw.TextStyle(font: bold, fontSize: 11),
  );
}

pw.Widget _pdfTable({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font regular,
  required pw.Font bold,
}) {
  final safeRows = rows.isEmpty ? [List.filled(headers.length, '-')] : rows;
  return pw.Table(
    border: pw.TableBorder.all(width: 0.6, color: PdfColors.grey500),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: headers.reversed
            .map(
              (header) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  header,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
              ),
            )
            .toList(),
      ),
      ...safeRows.map(
        (row) => pw.TableRow(
          children: row.reversed
              .map(
                (cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    cell,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: regular, fontSize: 8.5),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _ReportsData {
  const _ReportsData({
    required this.fromDate,
    required this.toDate,
    required this.invoiceCount,
    required this.salesTotal,
    required this.collectedTotal,
    required this.remainingTotal,
    required this.expensesTotal,
    required this.salesReturnsTotal,
    required this.netMovement,
    required this.receiptVoucherCount,
    required this.paymentVoucherCount,
    required this.receiptVoucherTotal,
    required this.paymentVoucherTotal,
    required this.cashNetTotal,
    required this.paymentRows,
    required this.topProducts,
    required this.topCategories,
    required this.topCustomers,
    required this.stockRows,
    required this.shiftRows,
    required this.cashMovementRows,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final int invoiceCount;
  final double salesTotal;
  final double collectedTotal;
  final double remainingTotal;
  final double expensesTotal;
  final double salesReturnsTotal;
  final double netMovement;
  final int receiptVoucherCount;
  final int paymentVoucherCount;
  final double receiptVoucherTotal;
  final double paymentVoucherTotal;
  final double cashNetTotal;
  final List<_PaymentMethodRow> paymentRows;
  final List<_TopAmountQtyRow> topProducts;
  final List<_TopAmountQtyRow> topCategories;
  final List<_TopCustomerRow> topCustomers;
  final List<_StockRow> stockRows;
  final List<_ShiftRow> shiftRows;
  final List<_CashMovementReportRow> cashMovementRows;
}

class _PaymentMethodRow {
  const _PaymentMethodRow({
    required this.method,
    required this.count,
    required this.amount,
  });

  final String method;
  final int count;
  final double amount;
}

class _TopAmountQtyRow {
  const _TopAmountQtyRow({
    required this.name,
    required this.qty,
    required this.amount,
  });

  final String name;
  final double qty;
  final double amount;
}

class _TopCustomerRow {
  const _TopCustomerRow({
    required this.name,
    required this.count,
    required this.amount,
  });

  final String name;
  final int count;
  final double amount;
}

class _StockRow {
  const _StockRow({
    required this.name,
    required this.soldQty,
    required this.remainingQty,
    required this.remainingValue,
  });

  final String name;
  final double soldQty;
  final double remainingQty;
  final double remainingValue;
}

class _ShiftRow {
  const _ShiftRow({
    required this.shiftLocalId,
    required this.shiftNo,
    required this.openedAt,
    required this.closedAt,
    required this.status,
    required this.invoicesCount,
    required this.salesTotal,
    required this.actualCash,
  });

  final int shiftLocalId;
  final String shiftNo;
  final String openedAt;
  final String closedAt;
  final String status;
  final int invoicesCount;
  final double salesTotal;
  final double actualCash;
}

class _PaymentAgg {
  const _PaymentAgg({this.count = 0, this.amount = 0});

  final int count;
  final double amount;
}

class _AmountQtyAgg {
  const _AmountQtyAgg({this.amount = 0, this.qty = 0});

  final double amount;
  final double qty;
}

class _CustomerAgg {
  const _CustomerAgg({this.count = 0, this.amount = 0});

  final int count;
  final double amount;
}

class _ShiftSalesAgg {
  const _ShiftSalesAgg({this.invoicesCount = 0, this.salesTotal = 0});

  final int invoicesCount;
  final double salesTotal;
}

class _CashMovementReportRow {
  const _CashMovementReportRow({
    required this.date,
    required this.source,
    required this.voucherNo,
    required this.description,
    required this.incoming,
    required this.outgoing,
    required this.status,
    required this.title,
    required this.partyLabel,
    required this.partyValue,
    required this.paymentMethod,
    required this.accountName,
    required this.note,
    required this.amount,
    required this.targetRoute,
  });

  final String date;
  final String source;
  final String voucherNo;
  final String description;
  final double incoming;
  final double outgoing;
  final String status;
  final String title;
  final String partyLabel;
  final String partyValue;
  final String paymentMethod;
  final String accountName;
  final String? note;
  final double amount;
  final String targetRoute;
}
