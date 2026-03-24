import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';
import '../data/cash_voucher_service.dart';
import 'cash_voucher_printing.dart';
import 'widgets/cash_management_nav_strip.dart';

class ControlPanelCashMovementsScreen extends ConsumerStatefulWidget {
  const ControlPanelCashMovementsScreen({super.key});

  @override
  ConsumerState<ControlPanelCashMovementsScreen> createState() =>
      _ControlPanelCashMovementsScreenState();
}

class _ControlPanelCashMovementsScreenState
    extends ConsumerState<ControlPanelCashMovementsScreen> {
  final _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _includeHidden = true;
  bool _includeVoided = true;
  int _refreshKey = 0;
  bool _printing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd hh:mm a').format(date);

  String _money(double value) => '${NumberFormat('#,##0.00').format(value)} ريال';

  bool _isVoid(String status) => status.trim().toUpperCase() == CashVoucherService.statusVoid;

  Future<void> _pickFromDate() async {
    final initial = _fromDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() => _fromDate = date);
  }

  Future<void> _pickToDate() async {
    final initial = _toDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() => _toDate = DateTime(date.year, date.month, date.day, 23, 59, 59));
  }

  Future<_CashMovementViewData> _loadData() async {
    final service = ref.read(cashVoucherServiceProvider);
    final entries = await service.getCashMovements(
      from: _fromDate,
      to: _toDate,
      includeHidden: _includeHidden,
      includeVoided: _includeVoided,
      query: _searchController.text,
    );
    final summary = await service.getMovementSummary(from: _fromDate, to: _toDate);
    return _CashMovementViewData(entries: entries, summary: summary);
  }

  Future<void> _printCurrentReport() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final data = await _loadData();
      await CashVoucherPrinting.printCashMovementReport(
        fromDate: _fromDate,
        toDate: _toDate,
        entries: data.entries,
        summary: data.summary,
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر طباعة التقرير: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _toggleHidden(CashMovementEntry entry) async {
    final service = ref.read(cashVoucherServiceProvider);
    final hiddenTarget = !entry.isHidden;
    if (entry.direction == CashMovementDirection.incoming) {
      await service.setReceiptVoucherHidden(entry.id, hiddenTarget);
    } else {
      await service.setPaymentVoucherHidden(entry.id, hiddenTarget);
    }
    if (!mounted) return;
    AppFeedback.success(context, hiddenTarget ? 'تم الإخفاء' : 'تمت إعادة الإظهار');
    setState(() => _refreshKey++);
  }

  Future<void> _toggleVoid(CashMovementEntry entry) async {
    final service = ref.read(cashVoucherServiceProvider);
    final target = _isVoid(entry.status)
        ? CashVoucherService.statusActive
        : CashVoucherService.statusVoid;
    if (entry.direction == CashMovementDirection.incoming) {
      await service.setReceiptVoucherStatus(entry.id, target);
    } else {
      await service.setPaymentVoucherStatus(entry.id, target);
    }
    if (!mounted) return;
    AppFeedback.success(context, target == CashVoucherService.statusVoid ? 'تم الإبطال' : 'تم التفعيل');
    setState(() => _refreshKey++);
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.topbarIconIndigo],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.swap_horiz_outlined, color: AppColors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'حركة الصندوق - متابعة التدفقات الداخلة والخارجة من سندات القبض والصرف',
              style: TextStyle(
                color: AppColors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersCard() {
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
                child: Text('فلاتر الحركة', style: AppTextStyles.topbarTitle),
              ),
              OutlinedButton.icon(
                onPressed: _printing ? null : _printCurrentReport,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(_printing ? 'جاري الطباعة...' : 'طباعة التقرير'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() => _refreshKey++),
                  decoration: const InputDecoration(
                    labelText: 'بحث',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.date_range_outlined, size: 16),
                  label: Text(_fromDate == null ? 'من تاريخ' : DateFormat('yyyy-MM-dd').format(_fromDate!)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(_toDate == null ? 'إلى تاريخ' : DateFormat('yyyy-MM-dd').format(_toDate!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  value: _includeHidden,
                  onChanged: (v) => setState(() {
                    _includeHidden = v;
                    _refreshKey++;
                  }),
                  title: const Text('إظهار المخفي', style: AppTextStyles.fieldText),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: _includeVoided,
                  onChanged: (v) => setState(() {
                    _includeVoided = v;
                    _refreshKey++;
                  }),
                  title: const Text('إظهار المبطل', style: AppTextStyles.fieldText),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(CashMovementSummary summary) {
    return Row(
      children: [
        Expanded(child: _SummaryBox(label: 'إجمالي الداخل', value: _money(summary.totalIncoming), color: AppColors.successGreen)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _SummaryBox(label: 'إجمالي الخارج', value: _money(summary.totalOutgoing), color: AppColors.dangerRed)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _SummaryBox(label: 'صافي الحركة', value: _money(summary.net), color: AppColors.topbarIconDeepBlue)),
      ],
    );
  }

  Widget _movementsTable(List<CashMovementEntry> entries) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text('لا توجد حركات مطابقة', textAlign: TextAlign.center, style: AppTextStyles.fieldHint),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: AppTextStyles.topbarTitle,
        columns: const [
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('رقم السند')),
          DataColumn(label: Text('البيان')),
          DataColumn(label: Text('داخل')),
          DataColumn(label: Text('خارج')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('الإجراءات')),
        ],
        rows: entries.map((e) {
          final inAmount = e.direction == CashMovementDirection.incoming ? e.amount : 0.0;
          final outAmount = e.direction == CashMovementDirection.outgoing ? e.amount : 0.0;
          final statusColor = e.isHidden
              ? AppColors.textMuted
              : (_isVoid(e.status) ? AppColors.warningPurple : AppColors.successGreen);
          final statusText = e.isHidden
              ? 'مخفي'
              : (_isVoid(e.status) ? 'مبطل' : (e.status.trim().isEmpty ? 'نشط' : e.status));

          return DataRow(
            cells: [
              DataCell(Text(_formatDate(e.createdAt))),
              DataCell(Text(e.source)),
              DataCell(Text(e.voucherNo)),
              DataCell(Text(e.description)),
              DataCell(Text(inAmount > 0 ? NumberFormat('#,##0.00').format(inAmount) : '-')),
              DataCell(Text(outAmount > 0 ? NumberFormat('#,##0.00').format(outAmount) : '-')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(statusText, style: AppTextStyles.fieldHint.copyWith(color: statusColor)),
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 4,
                  children: [
                    _IconAction(
                      icon: e.isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.topbarIconIndigo,
                      onTap: () => _toggleHidden(e),
                    ),
                    _IconAction(
                      icon: _isVoid(e.status) ? Icons.check_circle_outline : Icons.block_outlined,
                      color: AppColors.warningPurple,
                      onTap: () => _toggleVoid(e),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = _refreshKey;
    return ControlPanelShell(
      section: ControlPanelSection.cashMovements,
      child: FutureBuilder<_CashMovementViewData>(
        future: _loadData(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _hero(),
              const SizedBox(height: AppSpacing.md),
              const CashManagementNavStrip(
                current: ControlPanelSection.cashMovements,
              ),
              const SizedBox(height: AppSpacing.lg),
              _filtersCard(),
              const SizedBox(height: AppSpacing.lg),
              if (data != null) _summaryCards(data.summary),
              if (data != null) const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : (snapshot.hasError
                          ? Text('تعذر تحميل الحركة: ${snapshot.error}')
                          : _movementsTable(data?.entries ?? const <CashMovementEntry>[])),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CashMovementViewData {
  const _CashMovementViewData({
    required this.entries,
    required this.summary,
  });

  final List<CashMovementEntry> entries;
  final CashMovementSummary summary;
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTextStyles.fieldHint.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.fieldText.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
  }
}
