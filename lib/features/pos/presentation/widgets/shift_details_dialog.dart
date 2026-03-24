import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/printing/pdf_arabic_fonts.dart';

enum ShiftDetailsDialogMode { details, closeShift }

class ShiftDetailsDialog extends ConsumerWidget {
  const ShiftDetailsDialog({
    super.key,
    this.mode = ShiftDetailsDialogMode.details,
  });

  final ShiftDetailsDialogMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDbProvider);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(
        top: 30,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      backgroundColor: AppColors.surface,
      child: SizedBox(
        width: 880,
        height: maxHeight,
        child: FutureBuilder<_ShiftDetailsData>(
          future: _loadData(db),
          builder: (context, snapshot) {
            final data = snapshot.data;
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderBar(
                    title: data?.title ?? 'تفاصيل الوردية',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : _ShiftDetailsBody(
                            data: data ?? _ShiftDetailsData.empty(),
                            mode: mode,
                          ),
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

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
            ),
            splashRadius: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.topbarTitle.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _ShiftDetailsBody extends StatelessWidget {
  const _ShiftDetailsBody({required this.data, required this.mode});

  final _ShiftDetailsData data;
  final ShiftDetailsDialogMode mode;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTable(
            rows: [
              _SummaryRow('النقدية في الدرج:', data.cashDrawer),
              _SummaryRow('الدفع نقداً:', data.cashPayments),
              _SummaryRow('الدفع عن طريق البطاقة:', data.cardPayments),
              _SummaryRow('المجموع المسدد:', data.totalCollected),
              _SummaryRow('المبلغ الإجمالي:', data.totalSales, highlight: true),
              _SummaryRow('مبيعات الأجل:', data.creditSales, highlight: true),
              _SummaryRow('إجمالي المبيعات:', data.totalSales, highlight: true),
              _SummaryRow(
                'مرتجع المبيعات:',
                data.salesReturns,
                highlight: true,
              ),
              _SummaryRow(
                'مرتجع المشتريات:',
                data.purchaseReturns,
                highlight: true,
              ),
            ],
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'تفاصيل المنتجات المباعة'),
          _DataTableBlock(
            headers: const ['#', 'المنتج', 'الكمية', 'الإجمالي'],
            rows: data.itemRows
                .map(
                  (row) => [
                    row.index.toString(),
                    row.name,
                    row.qty.toStringAsFixed(2),
                    '${currency.format(row.total)} ريال',
                  ],
                )
                .toList(),
            footer: data.itemRows.isEmpty
                ? null
                : [
                    '#',
                    '',
                    currency.format(
                      data.itemRows.fold<double>(0, (a, b) => a + b.qty),
                    ),
                    'المبلغ الإجمالي: ${currency.format(data.itemsTotal)} ريال',
                  ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'تفاصيل مبيعات أقسام المنتجات'),
          _DataTableBlock(
            headers: const ['#', 'المنتج', 'الكمية', 'الإجمالي'],
            rows: data.categoryRows
                .map(
                  (row) => [
                    row.index.toString(),
                    row.name,
                    row.qty.toStringAsFixed(2),
                    '${currency.format(row.total)} ريال',
                  ],
                )
                .toList(),
            footer: data.categoryRows.isEmpty
                ? null
                : [
                    '#',
                    '',
                    currency.format(
                      data.categoryRows.fold<double>(0, (a, b) => a + b.qty),
                    ),
                    'المبلغ الإجمالي: ${currency.format(data.categoriesTotal)} ريال',
                  ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'تفاصيل الدفعات'),
          _DataTableBlock(
            headers: const [
              '#',
              'الرقم المرجعي',
              'الإجمالي',
              'رقم الفاتورة',
              'اسم العميل',
            ],
            rows: data.paymentRows
                .map(
                  (row) => [
                    row.index.toString(),
                    row.reference,
                    '${currency.format(row.amount)} ريال',
                    row.invoiceNo,
                    row.customerName,
                  ],
                )
                .toList(),
            footer: data.paymentRows.isEmpty
                ? null
                : [
                    '#',
                    '',
                    'إجمالي المدفوعات',
                    '${currency.format(data.totalCollected)} ريال',
                    '',
                  ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'تفاصيل المصروفات'),
          _DataTableBlock(
            headers: const [
              '#',
              'الرقم المرجعي',
              'الإجمالي',
              'الحالة',
              'مصروف لـ',
            ],
            rows: data.expenseRows
                .map(
                  (row) => [
                    row.index.toString(),
                    row.reference,
                    '${currency.format(row.amount)} ريال',
                    row.status,
                    row.spentFor,
                  ],
                )
                .toList(),
            footer: [
              '#',
              '',
              'إجمالي المدفوعات على المصروفات',
              '${currency.format(data.expensesTotal)} ريال',
              '',
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'تفاصيل مدفوعات المشتريات'),
          _DataTableBlock(
            headers: const [
              '#',
              'الرقم المرجعي',
              'الإجمالي',
              'رقم الفاتورة',
              'اسم المورد',
            ],
            rows: data.purchasePaymentRows
                .map(
                  (row) => [
                    row.index.toString(),
                    row.reference,
                    '${currency.format(row.amount)} ريال',
                    row.invoiceNo,
                    row.supplierName,
                  ],
                )
                .toList(),
            footer: [
              '#',
              '',
              'إجمالي المدفوعات',
              '${currency.format(data.purchasePaymentsTotal)} ريال',
              '',
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  title: 'الداخل',
                  rows: [
                    _SummaryRow('النقدية في الدرج:', data.cashDrawer),
                    _SummaryRow('مدفوعات المبيعات:', data.totalCollected),
                    _SummaryRow(
                      'مدفوعات مرتجع المشتريات:',
                      data.purchaseReturns,
                    ),
                  ],
                  currency: currency,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryBox(
                  title: 'الخارج',
                  rows: [
                    _SummaryRow(
                      'إجمالي مدفوعات المشتريات:',
                      data.purchasePaymentsTotal,
                    ),
                    _SummaryRow('مرتجع المبيعات:', data.salesReturns),
                    _SummaryRow(
                      'إجمالي المدفوعات على المصروفات:',
                      data.expensesTotal,
                    ),
                  ],
                  currency: currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FooterTotals(
            transfer: data.transferPayments,
            remaining: data.netMovement,
            cashDrawer: data.cashDrawer,
            currency: currency,
          ),
          if (mode == ShiftDetailsDialogMode.closeShift) ...[
            const SizedBox(height: AppSpacing.md),
            _CloseShiftFooterPanel(data: data),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            _FooterMeta(
              userName: data.userName,
              email: data.userEmail,
              branchName: data.branchName,
              shiftNo: data.shiftNo,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle(title: 'تفاصيل المتبقي بالمخزون'),
            _DataTableBlock(
              headers: const [
                '#',
                'المنتج',
                'مباع بالوردية',
                'المتبقي بالمخزون',
                'قيمة المتبقي',
              ],
              rows: data.stockRows
                  .map(
                    (row) => [
                      row.index.toString(),
                      row.name,
                      row.soldQty.toStringAsFixed(2),
                      row.remainingQty.toStringAsFixed(2),
                      '${currency.format(row.remainingValue)} ريال',
                    ],
                  )
                  .toList(),
              footer: data.stockRows.isEmpty
                  ? null
                  : [
                      '#',
                      '',
                      'إجمالي مباع: ${currency.format(data.itemRows.fold<double>(0, (a, b) => a + b.qty))}',
                      'إجمالي متبقي: ${currency.format(data.remainingStockQty)}',
                      'القيمة: ${currency.format(data.remainingStockValue)} ريال',
                    ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ShiftStatementPanel(data: data, currency: currency),
            const SizedBox(height: AppSpacing.md),
            _FooterActions(
              data: data,
              mode: mode,
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftStatementPanel extends StatelessWidget {
  const _ShiftStatementPanel({required this.data, required this.currency});

  final _ShiftDetailsData data;
  final NumberFormat currency;

  String _amount(double value) => '${currency.format(value)} ريال';

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['رقم الوردية', data.shiftNo.trim().isEmpty ? '-' : data.shiftNo.trim()],
      ['إجمالي المبيعات', _amount(data.totalSales)],
      ['إجمالي المحصل', _amount(data.totalCollected)],
      ['مبيعات الآجل', _amount(data.creditSales)],
      ['درج النقدية', _amount(data.cashDrawer)],
      ['قيمة المخزون المتبقي', _amount(data.remainingStockValue)],
      ['صافي الحركة', _amount(data.netMovement)],
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.neutralGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بيان الوردية',
            style: AppTextStyles.topbarTitle.copyWith(fontSize: 13),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row[0],
                      style: AppTextStyles.summaryLabel,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    row[1],
                    style: AppTextStyles.summaryValue,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
          if (data.shiftStatement.trim().isNotEmpty) ...[
            const Divider(height: AppSpacing.md),
            Text(
              data.shiftStatement,
              style: AppTextStyles.summaryLabel,
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.rows, required this.currency});

  final List<_SummaryRow> rows;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutralGrey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Container(
                color: row.highlight
                    ? AppColors.successGreen.withOpacity(0.16)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: AppTextStyles.summaryLabel.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${currency.format(row.value)} ريال',
                      style: AppTextStyles.summaryValue,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.close, size: 14, color: AppColors.dangerRed),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.topbarTitle.copyWith(fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _DataTableBlock extends StatelessWidget {
  const _DataTableBlock({
    required this.headers,
    required this.rows,
    this.footer,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final List<String>? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutralGrey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.neutralGrey)),
            ),
            child: Row(
              children: headers
                  .map(
                    (header) => Expanded(
                      child: Text(
                        header,
                        style: AppTextStyles.cartHeaderStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'لا توجد بيانات',
                style: AppTextStyles.fieldHint,
                textAlign: TextAlign.center,
              ),
            )
          else
            ...rows.map(
              (row) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.neutralGrey),
                  ),
                ),
                child: Row(
                  children: row
                      .map(
                        (cell) => Expanded(
                          child: Text(
                            cell,
                            style: AppTextStyles.fieldText.copyWith(
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (footer != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8,
              ),
              color: AppColors.successGreen.withOpacity(0.16),
              child: Row(
                children: footer!
                    .map(
                      (cell) => Expanded(
                        child: Text(
                          cell,
                          style: AppTextStyles.fieldText,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.title,
    required this.rows,
    required this.currency,
  });

  final String title;
  final List<_SummaryRow> rows;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Text(
            title,
            style: AppTextStyles.buttonTextStyle,
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutralGrey),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(6),
            ),
          ),
          child: Column(
            children: rows
                .map(
                  (row) => Container(
                    color: AppColors.successGreen.withOpacity(0.16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            style: AppTextStyles.summaryLabel,
                          ),
                        ),
                        Text(
                          '${currency.format(row.value)} ريال',
                          style: AppTextStyles.summaryValue,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FooterTotals extends StatelessWidget {
  const _FooterTotals({
    required this.transfer,
    required this.remaining,
    required this.cashDrawer,
    required this.currency,
  });

  final double transfer;
  final double remaining;
  final double cashDrawer;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.pillRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'التحويلات: ${currency.format(transfer)} ريال',
            style: AppTextStyles.buttonTextStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'المتبقي: ${currency.format(remaining)} ريال',
            style: AppTextStyles.buttonTextStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'درج النقدية: ${currency.format(cashDrawer)} ريال',
            style: AppTextStyles.buttonTextStyle,
          ),
        ],
      ),
    );
  }
}

class _FooterMeta extends StatelessWidget {
  const _FooterMeta({
    required this.userName,
    required this.email,
    required this.branchName,
    required this.shiftNo,
  });

  final String userName;
  final String email;
  final String branchName;
  final String shiftNo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('المستخدم المنسوب إليه:', style: AppTextStyles.summaryLabel),
        Text(userName, style: AppTextStyles.summaryValue),
        const SizedBox(height: 4),
        Text('البريد الإلكتروني: $email', style: AppTextStyles.summaryLabel),
        const SizedBox(height: 4),
        Text('موقع النشاط: $branchName', style: AppTextStyles.summaryLabel),
        const SizedBox(height: 4),
        Text('رقم الوردية: $shiftNo', style: AppTextStyles.summaryLabel),
      ],
    );
  }
}

class _CloseShiftFooterPanel extends ConsumerStatefulWidget {
  const _CloseShiftFooterPanel({required this.data});

  final _ShiftDetailsData data;

  @override
  ConsumerState<_CloseShiftFooterPanel> createState() =>
      _CloseShiftFooterPanelState();
}

class _CloseShiftFooterPanelState
    extends ConsumerState<_CloseShiftFooterPanel> {
  late final TextEditingController _cashTotalController;
  late final TextEditingController _cardsCountController;
  late final TextEditingController _checksTotalController;
  late final TextEditingController _closingNoteController;

  @override
  void initState() {
    super.initState();
    _cashTotalController = TextEditingController(
      text: widget.data.cashDrawer.toStringAsFixed(2),
    );
    _cardsCountController = TextEditingController(text: '0');
    _checksTotalController = TextEditingController(text: '0');
    _closingNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _cashTotalController.dispose();
    _cardsCountController.dispose();
    _checksTotalController.dispose();
    _closingNoteController.dispose();
    super.dispose();
  }

  double _parseAmount(String raw, {required double fallback}) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return fallback;
    return double.tryParse(cleaned) ?? fallback;
  }

  int _parseCount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }

  String _buildClosingNote({
    required String userNote,
    required double actualCash,
    required int cardsCount,
    required double checksTotal,
  }) {
    final parts = <String>[];
    if (userNote.trim().isNotEmpty) {
      parts.add(userNote.trim());
    }
    parts.add('مجموع النقد: ${actualCash.toStringAsFixed(2)} ريال');
    parts.add('العدد الإجمالي للبطاقات: $cardsCount');
    parts.add('مجموع الشيكات: ${checksTotal.toStringAsFixed(2)} ريال');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final currency = NumberFormat('#,##0.00');
    final canClose = data.canClose && data.shiftLocalId != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutralGrey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.pillRed,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'التحويلات: ${currency.format(data.transferPayments)} ريال',
              style: AppTextStyles.buttonTextStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'المتبقي: ${currency.format(data.netMovement)} ريال',
            style: AppTextStyles.topbarTitle,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            'درج النقدية: ${currency.format(data.cashDrawer)} ريال',
            style: AppTextStyles.topbarTitle,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.neutralGrey),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _CloseShiftInputField(
                  label: 'مجموع النقد:*',
                  controller: _cashTotalController,
                  hint: '0.00',
                  enabled: canClose,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CloseShiftInputField(
                  label: 'العدد الإجمالي للبطاقات:*',
                  controller: _cardsCountController,
                  hint: '0',
                  enabled: canClose,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CloseShiftInputField(
                  label: 'مجموع الشيكات:*',
                  controller: _checksTotalController,
                  hint: '0',
                  enabled: canClose,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('ملاحظة ختامية:', style: AppTextStyles.summaryLabel),
          const SizedBox(height: 4),
          TextField(
            controller: _closingNoteController,
            enabled: canClose,
            minLines: 3,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ملاحظة ختامية',
              hintStyle: AppTextStyles.fieldHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FooterMeta(
            userName: data.userName,
            email: data.userEmail,
            branchName: data.branchName,
            shiftNo: data.shiftNo,
          ),
          if (!canClose) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'لا يمكن إنهاء هذه الوردية لأنها غير مفتوحة حالياً.',
              style: AppTextStyles.summaryLabel.copyWith(
                color: AppColors.dangerRed,
              ),
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: !canClose
                      ? null
                      : () {
                          final actualCash = _parseAmount(
                            _cashTotalController.text,
                            fallback: data.cashDrawer,
                          );
                          final cardsCount = _parseCount(
                            _cardsCountController.text,
                          );
                          final checksTotal = _parseAmount(
                            _checksTotalController.text,
                            fallback: 0,
                          );
                          final closingNote = _buildClosingNote(
                            userNote: _closingNoteController.text,
                            actualCash: actualCash,
                            cardsCount: cardsCount,
                            checksTotal: checksTotal,
                          );
                          _confirmAndCloseShift(
                            context,
                            ref,
                            data,
                            actualCashOverride: actualCash,
                            closingNote: closingNote,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text(
                    'إنهاء الوردية',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseShiftInputField extends StatelessWidget {
  const _CloseShiftInputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTextStyles.summaryLabel,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.fieldHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.data,
    required this.mode,
    required this.onClose,
  });

  final _ShiftDetailsData data;
  final ShiftDetailsDialogMode mode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(onPressed: onClose, child: const Text('إلغاء')),
        if (mode == ShiftDetailsDialogMode.details) ...[
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => _printShiftDetails(context, data, thermal: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            icon: const Icon(Icons.print, size: 16, color: AppColors.white),
            label: const Text('طباعة 80', style: AppTextStyles.buttonTextStyle),
          ),
        ],
      ],
    );
  }
}

const String _shiftDetailsPrintTitle = 'تقرير تفاصيل الصندوق';

Future<void> _printShiftDetails(
  BuildContext context,
  _ShiftDetailsData data, {
  required bool thermal,
}) async {
  try {
    final targetFormat = thermal ? PdfPageFormat.roll80 : PdfPageFormat.a4;
    await Printing.layoutPdf(
      name: _shiftDetailsPrintTitle,
      format: targetFormat,
      onLayout: (format) => _buildShiftDetailsPdf(
        data: data,
        pageFormat: thermal ? targetFormat : format,
        thermal: thermal,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فشل الطباعة: $error'),
        backgroundColor: AppColors.dangerRed,
      ),
    );
  }
}

Future<void> _confirmAndCloseShift(
  BuildContext context,
  WidgetRef ref,
  _ShiftDetailsData data, {
  double? actualCashOverride,
  String? closingNote,
}) async {
  if (!data.canClose || data.shiftLocalId == null) return;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إنهاء الوردية'),
        content: Text(
          'هل تريد إنهاء الوردية ${data.shiftNo} الآن؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تأكيد الإنهاء'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final db = ref.read(appDbProvider);
  try {
    final now = DateTime.now();
    await (db.update(
      db.shifts,
    )..where((t) => t.localId.equals(data.shiftLocalId!))).write(
      ShiftsCompanion(
        closedAt: drift.Value(now),
        closedBy: drift.Value(
          data.userName.trim().isEmpty ? null : data.userName.trim(),
        ),
        closingNote: drift.Value(
          closingNote?.trim().isNotEmpty == true ? closingNote!.trim() : null,
        ),
        actualCash: drift.Value(actualCashOverride ?? data.cashDrawer),
        status: const drift.Value('closed'),
        updatedAtLocal: drift.Value(now),
      ),
    );
    await db.setSetting('current_shift_local_id', null);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنهاء الوردية بنجاح'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر إنهاء الوردية: $error'),
        backgroundColor: AppColors.dangerRed,
      ),
    );
  }
}

Future<Uint8List> _buildShiftDetailsPdf({
  required _ShiftDetailsData data,
  required PdfPageFormat pageFormat,
  required bool thermal,
}) async {
  final fonts = await PdfArabicFonts.load();
  final fontRegular = fonts.regular;
  final fontBold = fonts.bold;

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  );
  final currency = NumberFormat('#,##0.00');
  final printedAt = DateTime.now();

  final content = _buildShiftDetailsPdfContent(
    data: data,
    thermal: thermal,
    fontRegular: fontRegular,
    fontBold: fontBold,
    currency: currency,
    printedAt: printedAt,
  );

  if (thermal) {
    final thermalPageFormat = PdfPageFormat(pageFormat.width, 900);
    doc.addPage(
      pw.MultiPage(
        pageFormat: thermalPageFormat,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => [
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
  } else {
    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) => [
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
  }

  return doc.save();
}

List<pw.Widget> _buildShiftDetailsPdfContent({
  required _ShiftDetailsData data,
  required bool thermal,
  required pw.Font fontRegular,
  required pw.Font fontBold,
  required NumberFormat currency,
  required DateTime printedAt,
}) {
  final reportFontSize = thermal ? 6.8 : 8.2;
  String amount(double value) => '${currency.format(value)} ريال';
  final shiftPeriodRows = <List<String>>[
    ['من', _formatReportDateTime(data.reportFrom)],
    ['إلى', _formatReportDateTime(data.reportTo)],
  ];
  final summaryRows = <List<String>>[
    ['النقدية فى الدرج:', amount(data.cashDrawer)],
    ['الدفع نقدا', amount(data.cashPayments)],
    ['الدفع عن طريق البطاقة', amount(data.cardPayments)],
    ['تحويل بنكي', amount(data.transferPayments)],
    ['المجموع المسدد', amount(data.totalCollected)],
    ['المبلغ الإجمالي', amount(data.totalSales)],
    ['مبيعات الآجل', amount(data.creditSales)],
    ['اجمالي المبيعات', amount(data.totalSales)],
    ['مرتجع المبيعات', amount(data.salesReturns)],
    ['مرتجع المشتريات', amount(data.purchaseReturns)],
  ];
  final financialRows = _buildFinancialMovementRows(data, currency);
  final printInfoRows = <List<String>>[
    ['رقم الوردية', data.shiftNo],
    ['المستخدم', data.userName.trim().isEmpty ? '-' : data.userName.trim()],
    ['الموقع', data.branchName.trim().isEmpty ? '-' : data.branchName.trim()],
    ['تاريخ الطباعة', _formatReportDateTime(printedAt)],
  ];

  final productsRows = <List<String>>[
    ...data.itemRows.map(
      (row) => [
        row.index.toString(),
        row.name,
        row.qty.toStringAsFixed(2),
        amount(row.total),
      ],
    ),
    if (data.itemRows.isNotEmpty)
      [
        '#',
        '',
        currency.format(data.itemRows.fold<double>(0, (a, b) => a + b.qty)),
        'المبلغ الإجمالي ${amount(data.itemsTotal)}',
      ],
  ];
  final categoryRows = <List<String>>[
    ...data.categoryRows.map(
      (row) => [
        row.index.toString(),
        row.name,
        row.qty.toStringAsFixed(2),
        amount(row.total),
      ],
    ),
    if (data.categoryRows.isNotEmpty)
      [
        '#',
        '',
        currency.format(data.categoryRows.fold<double>(0, (a, b) => a + b.qty)),
        'المبلغ الإجمالي ${amount(data.categoriesTotal)}',
      ],
  ];
  final paymentRows = <List<String>>[
    ...data.paymentRows.map(
      (row) => [
        row.index.toString(),
        row.reference,
        amount(row.amount),
        row.invoiceNo,
        row.customerName,
      ],
    ),
    ['#', '', 'إجمالي المدفوعات', amount(data.totalCollected), ''],
  ];
  final expenseRows = <List<String>>[
    ...data.expenseRows.map(
      (row) => [
        row.index.toString(),
        row.reference,
        amount(row.amount),
        row.status,
        row.spentFor,
      ],
    ),
    ['#', '', 'إجمالي المدفوعات على المصروفات', amount(data.expensesTotal), ''],
  ];
  final purchaseRows = <List<String>>[
    ...data.purchasePaymentRows.map(
      (row) => [
        row.index.toString(),
        row.reference,
        amount(row.amount),
        row.invoiceNo,
        row.supplierName,
      ],
    ),
    ['#', '', 'إجمالي المدفوعات', amount(data.purchasePaymentsTotal), ''],
  ];
  final summaryFinanceRows = financialRows;

  return [
    pw.Center(
      child: pw.Text(
        _shiftDetailsPrintTitle,
        style: pw.TextStyle(font: fontBold, fontSize: thermal ? 11 : 17),
      ),
    ),
    pw.SizedBox(height: 8),
    _pdfTable(
      headers: const ['الفترة', 'الوقت'],
      rows: shiftPeriodRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2.2),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfTable(
      headers: const ['البيان', 'القيمة'],
      rows: summaryRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(2.3),
        1: pw.FlexColumnWidth(1.4),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('تفاصيل المنتجات المباعة', fontBold, reportFontSize),
    _pdfTable(
      headers: const ['#', 'المنتج', 'الكمية', 'الاجمالي'],
      rows: productsRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.7),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.4),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('تفاصيل مبيعات أقسام المنتجات', fontBold, reportFontSize),
    _pdfTable(
      headers: const ['#', 'المنتج', 'الكمية', 'الاجمالي'],
      rows: categoryRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.7),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.4),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('تفاصيل الدفعات', fontBold, reportFontSize),
    ..._buildChunkedTables(
      headers: const [
        '#',
        'الرقم المرجعي',
        'الاجمالي',
        'رقم الفاتورة',
        'اسم العميل',
      ],
      rows: paymentRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      rowsPerChunk: thermal ? 14 : 24,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.55),
        1: pw.FlexColumnWidth(2.25),
        2: pw.FlexColumnWidth(1.45),
        3: pw.FlexColumnWidth(1.05),
        4: pw.FlexColumnWidth(1.7),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('تفاصيل المصروفات', fontBold, reportFontSize),
    _pdfTable(
      headers: const ['#', 'الرقم المرجعي', 'الاجمالي', 'الحالة', 'مصروف لـ'],
      rows: expenseRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.55),
        1: pw.FlexColumnWidth(2.25),
        2: pw.FlexColumnWidth(1.45),
        3: pw.FlexColumnWidth(1.05),
        4: pw.FlexColumnWidth(1.7),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('تفاصيل مدفوعات المشتريات', fontBold, reportFontSize),
    _pdfTable(
      headers: const [
        '#',
        'الرقم المرجعي',
        'الاجمالي',
        'رقم الفاتورة',
        'اسم المورد',
      ],
      rows: purchaseRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(0.55),
        1: pw.FlexColumnWidth(2.25),
        2: pw.FlexColumnWidth(1.45),
        3: pw.FlexColumnWidth(1.05),
        4: pw.FlexColumnWidth(1.7),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfSectionTitle('ملخص الحركة المالية', fontBold, reportFontSize),
    _pdfTable(
      headers: const ['البيان', 'القيمة'],
      rows: summaryFinanceRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8),
        1: pw.FlexColumnWidth(2.2),
      },
    ),
    pw.SizedBox(height: 8),
    _pdfTable(
      headers: const ['بيانات الطباعة', 'القيمة'],
      rows: printInfoRows,
      fontRegular: fontRegular,
      fontBold: fontBold,
      thermal: thermal,
      fontSize: reportFontSize,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8),
        1: pw.FlexColumnWidth(2.2),
      },
    ),
    pw.SizedBox(height: 6),
    pw.Center(
      child: pw.Text(
        '--- نهاية التقرير ---',
        style: pw.TextStyle(font: fontRegular, fontSize: reportFontSize),
      ),
    ),
  ];
}

List<List<String>> _buildFinancialMovementRows(
  _ShiftDetailsData data,
  NumberFormat currency,
) {
  String amount(double value) => '${currency.format(value)} ريال';

  return <List<String>>[
    ['إجمالي الداخل', amount(data.totalIn)],
    ['إجمالي الخارج', amount(data.totalOut)],
    ['المتبقي', amount(data.netMovement)],
    ['درج النقدية', amount(data.cashDrawer)],
  ];
}

String _formatReportDateTime(DateTime value) {
  return DateFormat('a hh:mm dd-MM-yyyy').format(value);
}

pw.Widget _pdfSectionTitle(String title, pw.Font fontBold, double fontSize) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      title,
      style: pw.TextStyle(font: fontBold, fontSize: fontSize),
      textAlign: pw.TextAlign.right,
    ),
  );
}

pw.Widget _pdfTable({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font fontRegular,
  required pw.Font fontBold,
  required bool thermal,
  double? fontSize,
  Map<int, pw.TableColumnWidth>? columnWidths,
}) {
  final textSize = fontSize ?? (thermal ? 7.5 : 9.5);
  final headerSize = textSize;
  final effectiveRows = rows.isEmpty
      ? <List<String>>[List.filled(headers.length, '-')]
      : rows;
  final columnCount = headers.length;
  final normalizedRows = effectiveRows.map((row) {
    if (row.length == columnCount) return row;
    if (row.length < columnCount) {
      return [...row, ...List.filled(columnCount - row.length, '')];
    }
    return row.sublist(0, columnCount);
  }).toList();
  final rtlHeaders = headers.reversed.toList(growable: false);
  final rtlRows = normalizedRows
      .map((row) => row.reversed.toList(growable: false))
      .toList(growable: false);
  final rtlColumnWidths = columnWidths == null
      ? null
      : <int, pw.TableColumnWidth>{
          for (final entry in columnWidths.entries)
            (columnCount - 1 - entry.key): entry.value,
        };

  return pw.Table(
    border: pw.TableBorder.all(width: 0.6, color: PdfColors.grey500),
    columnWidths: rtlColumnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: rtlHeaders
            .map(
              (header) => pw.Padding(
                padding: pw.EdgeInsets.all(thermal ? 2 : 3),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(font: fontBold, fontSize: headerSize),
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            )
            .toList(),
      ),
      ...rtlRows.map(
        (row) => pw.TableRow(
          children: row
              .map(
                (cell) => pw.Padding(
                  padding: pw.EdgeInsets.all(thermal ? 2 : 3),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(font: fontRegular, fontSize: textSize),
                    textAlign: pw.TextAlign.right,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

List<pw.Widget> _buildChunkedTables({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font fontRegular,
  required pw.Font fontBold,
  required bool thermal,
  double? fontSize,
  required int rowsPerChunk,
  Map<int, pw.TableColumnWidth>? columnWidths,
}) {
  if (rows.isEmpty) {
    return [
      _pdfTable(
        headers: headers,
        rows: rows,
        fontRegular: fontRegular,
        fontBold: fontBold,
        thermal: thermal,
        fontSize: fontSize,
        columnWidths: columnWidths,
      ),
    ];
  }

  final chunks = <List<List<String>>>[];
  for (var i = 0; i < rows.length; i += rowsPerChunk) {
    final end = (i + rowsPerChunk > rows.length)
        ? rows.length
        : i + rowsPerChunk;
    chunks.add(rows.sublist(i, end));
  }

  final widgets = <pw.Widget>[];
  for (var i = 0; i < chunks.length; i++) {
    widgets.add(
      _pdfTable(
        headers: headers,
        rows: chunks[i],
        fontRegular: fontRegular,
        fontBold: fontBold,
        thermal: thermal,
        fontSize: fontSize,
        columnWidths: columnWidths,
      ),
    );
    if (i != chunks.length - 1) {
      widgets.add(pw.SizedBox(height: 4));
    }
  }

  return widgets;
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value, {this.highlight = false});

  final String label;
  final double value;
  final bool highlight;
}

class _ShiftDetailsData {
  const _ShiftDetailsData({
    required this.shiftLocalId,
    required this.shiftNo,
    required this.canClose,
    required this.title,
    required this.reportFrom,
    required this.reportTo,
    required this.openingCash,
    required this.cashDrawer,
    required this.cashPayments,
    required this.cardPayments,
    required this.transferPayments,
    required this.totalCollected,
    required this.totalSales,
    required this.creditSales,
    required this.remaining,
    required this.salesReturns,
    required this.purchaseReturns,
    required this.itemRows,
    required this.itemsTotal,
    required this.categoryRows,
    required this.categoriesTotal,
    required this.paymentRows,
    required this.expenseRows,
    required this.expensesTotal,
    required this.purchasePaymentRows,
    required this.purchasePaymentsTotal,
    required this.stockRows,
    required this.remainingStockQty,
    required this.remainingStockValue,
    required this.shiftStatement,
    required this.userName,
    required this.userEmail,
    required this.branchName,
    required this.totalIn,
    required this.totalOut,
    required this.netMovement,
  });

  final int? shiftLocalId;
  final String shiftNo;
  final bool canClose;
  final String title;
  final DateTime reportFrom;
  final DateTime reportTo;
  final double openingCash;
  final double cashDrawer;
  final double cashPayments;
  final double cardPayments;
  final double transferPayments;
  final double totalCollected;
  final double totalSales;
  final double creditSales;
  final double remaining;
  final double salesReturns;
  final double purchaseReturns;
  final List<_RowSummary> itemRows;
  final double itemsTotal;
  final List<_RowSummary> categoryRows;
  final double categoriesTotal;
  final List<_PaymentRow> paymentRows;
  final List<_ExpenseRow> expenseRows;
  final double expensesTotal;
  final List<_PurchasePaymentRow> purchasePaymentRows;
  final double purchasePaymentsTotal;
  final List<_StockRow> stockRows;
  final double remainingStockQty;
  final double remainingStockValue;
  final String shiftStatement;
  final String userName;
  final String userEmail;
  final String branchName;
  final double totalIn;
  final double totalOut;
  final double netMovement;

  factory _ShiftDetailsData.empty() {
    return _ShiftDetailsData(
      shiftLocalId: null,
      shiftNo: '-',
      canClose: false,
      title: 'تفاصيل الوردية',
      reportFrom: DateTime(1970, 1, 1),
      reportTo: DateTime(1970, 1, 1),
      openingCash: 0,
      cashDrawer: 0,
      cashPayments: 0,
      cardPayments: 0,
      transferPayments: 0,
      totalCollected: 0,
      totalSales: 0,
      creditSales: 0,
      remaining: 0,
      salesReturns: 0,
      purchaseReturns: 0,
      itemRows: [],
      itemsTotal: 0,
      categoryRows: [],
      categoriesTotal: 0,
      paymentRows: [],
      expenseRows: [],
      expensesTotal: 0,
      purchasePaymentRows: [],
      purchasePaymentsTotal: 0,
      stockRows: [],
      remainingStockQty: 0,
      remainingStockValue: 0,
      shiftStatement: '',
      userName: '-',
      userEmail: '-',
      branchName: '-',
      totalIn: 0,
      totalOut: 0,
      netMovement: 0,
    );
  }
}

class _RowSummary {
  const _RowSummary({
    required this.index,
    required this.name,
    required this.qty,
    required this.total,
  });

  final int index;
  final String name;
  final double qty;
  final double total;
}

class _PaymentRow {
  const _PaymentRow({
    required this.index,
    required this.reference,
    required this.amount,
    required this.invoiceNo,
    required this.customerName,
  });

  final int index;
  final String reference;
  final double amount;
  final String invoiceNo;
  final String customerName;
}

class _ExpenseRow {
  const _ExpenseRow({
    required this.index,
    required this.reference,
    required this.amount,
    required this.status,
    required this.spentFor,
  });

  final int index;
  final String reference;
  final double amount;
  final String status;
  final String spentFor;
}

class _PurchasePaymentRow {
  const _PurchasePaymentRow({
    required this.index,
    required this.reference,
    required this.amount,
    required this.invoiceNo,
    required this.supplierName,
  });

  final int index;
  final String reference;
  final double amount;
  final String invoiceNo;
  final String supplierName;
}

class _StockRow {
  const _StockRow({
    required this.index,
    required this.name,
    required this.soldQty,
    required this.remainingQty,
    required this.remainingValue,
  });

  final int index;
  final String name;
  final double soldQty;
  final double remainingQty;
  final double remainingValue;
}

Future<_ShiftDetailsData> _loadData(AppDb db) async {
  final now = DateTime.now();
  final storeName = (await db.getSetting('store_name'))?.trim() ?? '';
  final branchNameSetting = (await db.getSetting('branch_name'))?.trim() ?? '';
  final userEmailSetting = (await db.getSetting('user_email'))?.trim() ?? '';
  final workstation = await db.getCurrentWorkstation();

  final targetShift = await _resolveTargetShift(
    db,
    workstationId: workstation?.id,
  );

  if (targetShift == null) {
    final branchName = branchNameSetting.isNotEmpty
        ? branchNameSetting
        : (storeName.isNotEmpty ? storeName : '-');
    final userName = (workstation?.name ?? '').trim().isNotEmpty
        ? workstation!.name
        : (storeName.isNotEmpty ? storeName : '-');
    final userEmail = userEmailSetting.isNotEmpty ? userEmailSetting : '-';
    return _ShiftDetailsData(
      shiftLocalId: null,
      shiftNo: '-',
      canClose: false,
      title: 'لا توجد وردية',
      reportFrom: now,
      reportTo: now,
      openingCash: 0,
      cashDrawer: 0,
      cashPayments: 0,
      cardPayments: 0,
      transferPayments: 0,
      totalCollected: 0,
      totalSales: 0,
      creditSales: 0,
      remaining: 0,
      salesReturns: 0,
      purchaseReturns: 0,
      itemRows: const [],
      itemsTotal: 0,
      categoryRows: const [],
      categoriesTotal: 0,
      paymentRows: const [],
      expenseRows: const [],
      expensesTotal: 0,
      purchasePaymentRows: const [],
      purchasePaymentsTotal: 0,
      stockRows: const [],
      remainingStockQty: 0,
      remainingStockValue: 0,
      shiftStatement: 'لا توجد وردية تم إنشاؤها بعد على هذا الجهاز.',
      userName: userName,
      userEmail: userEmail,
      branchName: branchName,
      totalIn: 0,
      totalOut: 0,
      netMovement: 0,
    );
  }

  final shiftId = targetShift.localId;
  final shiftNo = (targetShift.shiftNo?.trim().isNotEmpty ?? false)
      ? targetShift.shiftNo!.trim()
      : '#$shiftId';
  final isOpen =
      targetShift.status.trim().toLowerCase() == 'open' &&
      targetShift.closedAt == null;

  final shiftStart = targetShift.openedAt;
  final shiftEnd = targetShift.closedAt ?? now;
  final openingCash = targetShift.openingBalance;

  final linkedSales = await (db.select(
    db.sales,
  )..where((t) => t.shiftLocalId.equals(shiftId))).get();
  var sales = linkedSales
      .where((sale) => sale.status.trim().toUpperCase() != 'QUOTATION')
      .toList();

  if (sales.isEmpty) {
    final allSales = await db.select(db.sales).get();
    sales = allSales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(shiftStart) &&
              !sale.createdAt.isAfter(shiftEnd) &&
              sale.status.trim().toUpperCase() != 'QUOTATION',
        )
        .toList();
  }

  final saleIds = sales.map((s) => s.localId).toSet().toList();

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

  final customerIds = sales
      .map((sale) => sale.customerId)
      .whereType<int>()
      .toSet()
      .toList();
  final customers = customerIds.isEmpty
      ? <CustomerDb>[]
      : await (db.select(
          db.customers,
        )..where((t) => t.id.isIn(customerIds))).get();

  final products = await (db.select(
    db.products,
  )..where((t) => t.isDeleted.equals(false))).get();
  final categories = await (db.select(
    db.productCategories,
  )..where((t) => t.isDeleted.equals(false))).get();

  final salesReturnRows = await (db.select(
    db.salesReturns,
  )..where((t) => t.shiftLocalId.equals(shiftId))).get();
  final activeSalesReturns = salesReturnRows.where(
    (row) => _isFinancialRowActive(row.status),
  );
  final salesReturns = activeSalesReturns.fold<double>(
    0,
    (sum, row) => sum + row.total,
  );

  final paymentVoucherRows =
      await (db.select(db.paymentVouchers)..where(
            (t) => t.shiftLocalId.equals(shiftId) & t.isDeleted.equals(false),
          ))
          .get();
  final activePaymentVouchers = paymentVoucherRows.where(
    (row) => _isFinancialRowActive(row.status),
  );

  final receiptVoucherRows =
      await (db.select(db.receiptVouchers)..where(
            (t) => t.shiftLocalId.equals(shiftId) & t.isDeleted.equals(false),
          ))
          .get();
  final activeReceiptVouchers = receiptVoucherRows.where(
    (row) => _isFinancialRowActive(row.status),
  );

  final purchaseReturns = activeReceiptVouchers.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );

  final salesById = {for (final s in sales) s.localId: s};
  final productById = {for (final p in products) p.id: p};
  final categoryById = {for (final c in categories) c.id: c};
  final customerById = {for (final c in customers) c.id: c};

  final reportFrom = shiftStart;
  final reportTo = shiftEnd;
  final title = 'تقرير تفاصيل الصندوق';

  final totalSales = sales.fold<double>(0, (sum, s) => sum + s.total);
  final remaining = sales.fold<double>(0, (sum, s) => sum + s.remaining);

  double creditSales = 0;
  for (final sale in sales) {
    final status = sale.status.trim().toLowerCase();
    if (status == 'credit') {
      creditSales += sale.total;
    } else if (status == 'partial' && sale.remaining > 0) {
      creditSales += sale.remaining;
    }
  }

  double cashPayments = 0;
  double cardPayments = 0;
  double transferPayments = 0;
  for (final payment in salePayments) {
    final code = payment.methodCode.trim().toUpperCase();
    if (code == 'CASH') {
      cashPayments += payment.amount;
    } else if (code == 'CARD') {
      cardPayments += payment.amount;
    } else if (code == 'TRANSFER') {
      transferPayments += payment.amount;
    } else if (code.contains('CARD')) {
      cardPayments += payment.amount;
    }
  }

  final totalCollected = cashPayments + cardPayments + transferPayments;

  final soldQtyByProductId = <int, double>{};
  final itemMap = <String, _RowSummary>{};
  for (final item in saleItems) {
    soldQtyByProductId[item.productId] =
        (soldQtyByProductId[item.productId] ?? 0) + item.qty.toDouble();

    final product = productById[item.productId];
    final name = item.nameSnapshot.trim().isNotEmpty
        ? item.nameSnapshot.trim()
        : (product?.name ?? 'منتج #${item.productId}');
    final existing = itemMap[name];
    if (existing == null) {
      itemMap[name] = _RowSummary(
        index: 0,
        name: name,
        qty: item.qty.toDouble(),
        total: item.total,
      );
    } else {
      itemMap[name] = _RowSummary(
        index: 0,
        name: name,
        qty: existing.qty + item.qty.toDouble(),
        total: existing.total + item.total,
      );
    }
  }

  final itemRows = itemMap.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  final itemsTotal = itemRows.fold<double>(0, (sum, r) => sum + r.total);
  final indexedItems = <_RowSummary>[
    for (var i = 0; i < itemRows.length; i++)
      _RowSummary(
        index: i + 1,
        name: itemRows[i].name,
        qty: itemRows[i].qty,
        total: itemRows[i].total,
      ),
  ];

  final categoryMap = <String, _RowSummary>{};
  for (final item in saleItems) {
    final product = productById[item.productId];
    final category = product?.categoryId == null
        ? null
        : categoryById[product!.categoryId!];
    final name = (category?.name ?? 'بدون قسم').trim();
    final existing = categoryMap[name];
    if (existing == null) {
      categoryMap[name] = _RowSummary(
        index: 0,
        name: name,
        qty: item.qty.toDouble(),
        total: item.total,
      );
    } else {
      categoryMap[name] = _RowSummary(
        index: 0,
        name: name,
        qty: existing.qty + item.qty.toDouble(),
        total: existing.total + item.total,
      );
    }
  }

  final categoryRows = categoryMap.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  final categoriesTotal = categoryRows.fold<double>(
    0,
    (sum, r) => sum + r.total,
  );
  final indexedCategories = <_RowSummary>[
    for (var i = 0; i < categoryRows.length; i++)
      _RowSummary(
        index: i + 1,
        name: categoryRows[i].name,
        qty: categoryRows[i].qty,
        total: categoryRows[i].total,
      ),
  ];

  final paymentRows = <_PaymentRow>[
    for (var i = 0; i < salePayments.length; i++)
      _PaymentRow(
        index: i + 1,
        reference:
            '${_paymentMethodLabel(salePayments[i].methodCode)}${salePayments[i].reference?.trim().isNotEmpty == true ? ' - ${salePayments[i].reference!.trim()}' : ''}',
        amount: salePayments[i].amount,
        invoiceNo: (() {
          final sale = salesById[salePayments[i].saleLocalId];
          final invoice = sale?.invoiceNo?.trim() ?? '';
          if (invoice.isNotEmpty) return invoice;
          return '${sale?.localId ?? '-'}';
        })(),
        customerName: (() {
          final sale = salesById[salePayments[i].saleLocalId];
          final customer = sale?.customerId == null
              ? null
              : customerById[sale!.customerId!];
          final name = customer?.name.trim() ?? '';
          return name.isNotEmpty ? name : 'عميل عام';
        })(),
      ),
  ];

  final sortedPaymentVouchers = activePaymentVouchers.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final purchaseVoucherRows = sortedPaymentVouchers
      .where(_isPurchaseVoucher)
      .toList();
  final expenseVoucherRows = sortedPaymentVouchers
      .where((row) => !_isPurchaseVoucher(row))
      .toList();

  final expenseRows = <_ExpenseRow>[
    for (var i = 0; i < expenseVoucherRows.length; i++)
      _ExpenseRow(
        index: i + 1,
        reference: _voucherReferenceLabel(
          voucherNo: expenseVoucherRows[i].voucherNo,
          reference: expenseVoucherRows[i].reference,
        ),
        amount: expenseVoucherRows[i].amount,
        status: expenseVoucherRows[i].status.trim().isEmpty
            ? '-'
            : expenseVoucherRows[i].status.trim(),
        spentFor: expenseVoucherRows[i].expenseType.trim().isEmpty
            ? 'مصروف عام'
            : expenseVoucherRows[i].expenseType.trim(),
      ),
  ];
  final expensesTotal = expenseRows.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );

  final purchasePaymentRows = <_PurchasePaymentRow>[
    for (var i = 0; i < purchaseVoucherRows.length; i++)
      _PurchasePaymentRow(
        index: i + 1,
        reference: _voucherReferenceLabel(
          voucherNo: purchaseVoucherRows[i].voucherNo,
          reference: purchaseVoucherRows[i].reference,
        ),
        amount: purchaseVoucherRows[i].amount,
        invoiceNo: purchaseVoucherRows[i].voucherNo?.trim().isNotEmpty == true
            ? purchaseVoucherRows[i].voucherNo!.trim()
            : '${purchaseVoucherRows[i].localId}',
        supplierName: purchaseVoucherRows[i].expenseType.trim().isEmpty
            ? 'مورد عام'
            : purchaseVoucherRows[i].expenseType.trim(),
      ),
  ];
  final purchasePaymentsTotal = purchasePaymentRows.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );

  final stockCandidates =
      products
          .where((p) => p.isActive && !p.isDeleted)
          .map(
            (product) => _StockRow(
              index: 0,
              name: product.name.trim().isEmpty
                  ? 'منتج #${product.id}'
                  : product.name.trim(),
              soldQty: soldQtyByProductId[product.id] ?? 0,
              remainingQty: product.stock.toDouble(),
              remainingValue: product.stock * product.price,
            ),
          )
          .where((row) => row.soldQty > 0 || row.remainingQty > 0)
          .toList()
        ..sort((a, b) {
          final soldCompare = b.soldQty.compareTo(a.soldQty);
          if (soldCompare != 0) return soldCompare;
          return a.name.compareTo(b.name);
        });

  final indexedStockRows = <_StockRow>[
    for (var i = 0; i < stockCandidates.length; i++)
      _StockRow(
        index: i + 1,
        name: stockCandidates[i].name,
        soldQty: stockCandidates[i].soldQty,
        remainingQty: stockCandidates[i].remainingQty,
        remainingValue: stockCandidates[i].remainingValue,
      ),
  ];
  final remainingStockQty = indexedStockRows.fold<double>(
    0,
    (sum, row) => sum + row.remainingQty,
  );
  final remainingStockValue = indexedStockRows.fold<double>(
    0,
    (sum, row) => sum + row.remainingValue,
  );

  final branchName = branchNameSetting.isNotEmpty
      ? branchNameSetting
      : storeName;
  final openedBy = targetShift.openedBy?.trim() ?? '';
  final userName = openedBy.isNotEmpty
      ? openedBy
      : ((workstation?.name ?? '').trim().isNotEmpty
            ? workstation!.name
            : (storeName.isNotEmpty ? storeName : '-'));
  final userEmail = userEmailSetting.isNotEmpty ? userEmailSetting : '-';

  final totalIn = openingCash + totalCollected + purchaseReturns;
  final totalOut = salesReturns + expensesTotal + purchasePaymentsTotal;
  final netMovement = totalIn - totalOut;
  final cashDrawer = netMovement;

  final shiftStatement =
      'بيان الوردية رقم $shiftNo: إجمالي المبيعات ${totalSales.toStringAsFixed(2)} ريال، '
      'المحصل ${totalCollected.toStringAsFixed(2)} ريال، '
      'مبيعات الآجل ${creditSales.toStringAsFixed(2)} ريال، '
      'درج النقدية ${cashDrawer.toStringAsFixed(2)} ريال، '
      'قيمة المخزون المتبقي ${remainingStockValue.toStringAsFixed(2)} ريال.';

  return _ShiftDetailsData(
    shiftLocalId: shiftId,
    shiftNo: shiftNo,
    canClose: isOpen,
    title: title,
    reportFrom: reportFrom,
    reportTo: reportTo,
    openingCash: openingCash,
    cashDrawer: cashDrawer,
    cashPayments: cashPayments,
    cardPayments: cardPayments,
    transferPayments: transferPayments,
    totalCollected: totalCollected,
    totalSales: totalSales,
    creditSales: creditSales,
    remaining: remaining,
    salesReturns: salesReturns,
    purchaseReturns: purchaseReturns,
    itemRows: indexedItems,
    itemsTotal: itemsTotal,
    categoryRows: indexedCategories,
    categoriesTotal: categoriesTotal,
    paymentRows: paymentRows,
    expenseRows: expenseRows,
    expensesTotal: expensesTotal,
    purchasePaymentRows: purchasePaymentRows,
    purchasePaymentsTotal: purchasePaymentsTotal,
    stockRows: indexedStockRows,
    remainingStockQty: remainingStockQty,
    remainingStockValue: remainingStockValue,
    shiftStatement: shiftStatement,
    userName: userName,
    userEmail: userEmail,
    branchName: branchName.isNotEmpty ? branchName : '-',
    totalIn: totalIn,
    totalOut: totalOut,
    netMovement: netMovement,
  );
}

Future<ShiftDb?> _resolveTargetShift(AppDb db, {int? workstationId}) async {
  final currentShiftRaw = (await db.getSetting(
    'current_shift_local_id',
  ))?.trim();
  final currentShiftId = int.tryParse(currentShiftRaw ?? '');
  if (currentShiftId != null && currentShiftId > 0) {
    final byId = await (db.select(
      db.shifts,
    )..where((t) => t.localId.equals(currentShiftId))).getSingleOrNull();
    if (byId != null) return byId;
  }

  if (workstationId != null) {
    final openForWorkstation =
        await (db.select(db.shifts)
              ..where(
                (t) =>
                    t.workstationId.equals(workstationId) &
                    t.status.equals('open') &
                    t.closedAt.isNull(),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.openedAt,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (openForWorkstation != null) return openForWorkstation;
  }

  final openAny =
      await (db.select(db.shifts)
            ..where((t) => t.status.equals('open') & t.closedAt.isNull())
            ..orderBy([
              (t) => drift.OrderingTerm(
                expression: t.openedAt,
                mode: drift.OrderingMode.desc,
              ),
            ])
            ..limit(1))
          .getSingleOrNull();
  if (openAny != null) return openAny;

  return (db.select(db.shifts)
        ..orderBy([
          (t) => drift.OrderingTerm(
            expression: t.openedAt,
            mode: drift.OrderingMode.desc,
          ),
        ])
        ..limit(1))
      .getSingleOrNull();
}

bool _isFinancialRowActive(String status) {
  final value = status.trim().toUpperCase();
  if (value.isEmpty) return true;
  return value != 'CANCELLED' &&
      value != 'CANCELED' &&
      value != 'VOID' &&
      value != 'DELETED';
}

bool _isPurchaseVoucher(PaymentVoucherDb row) {
  final content = '${row.expenseType} ${row.note ?? ''}'.toLowerCase();
  return content.contains('purchase') ||
      content.contains('supplier') ||
      content.contains('مشت') ||
      content.contains('مورد');
}

String _voucherReferenceLabel({String? voucherNo, String? reference}) {
  final normalizedVoucherNo = voucherNo?.trim() ?? '';
  final normalizedReference = reference?.trim() ?? '';
  if (normalizedVoucherNo.isNotEmpty && normalizedReference.isNotEmpty) {
    return '$normalizedVoucherNo - $normalizedReference';
  }
  if (normalizedVoucherNo.isNotEmpty) return normalizedVoucherNo;
  if (normalizedReference.isNotEmpty) return normalizedReference;
  return '-';
}

String _paymentMethodLabel(String methodCode) =>
    PaymentMethods.labelForCode(methodCode);
