import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';

class SalesReturnsDialog extends ConsumerStatefulWidget {
  const SalesReturnsDialog({super.key});

  @override
  ConsumerState<SalesReturnsDialog> createState() => _SalesReturnsDialogState();
}

class _SalesReturnsDialogState extends ConsumerState<SalesReturnsDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    final viewport = MediaQuery.sizeOf(context);
    final compactDialog = viewport.width < 1160;
    final horizontalInset = compactDialog ? AppSpacing.md : 40.0;
    final verticalInset = compactDialog ? AppSpacing.md : 20.0;
    final dialogWidth = compactDialog
        ? (viewport.width * (viewport.width < 900 ? 0.78 : 0.84)).clamp(
            320.0,
            860.0,
          )
        : 1040.0;
    final dialogHeight = compactDialog
        ? (viewport.height * 0.82).clamp(420.0, 620.0)
        : 680.0;
    final returnsStream =
        (db.select(db.salesReturns)..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
              (t) =>
                  OrderingTerm(expression: t.localId, mode: OrderingMode.desc),
            ]))
            .watch();

    return Dialog(
      alignment: Alignment.center,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مرتجع المبيعات',
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم المرتجع أو الفاتورة الأصلية أو العميل',
                    hintStyle: AppTextStyles.fieldHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
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
                child: StreamBuilder<List<SalesReturnDb>>(
                  stream: returnsStream,
                  builder: (context, returnsSnap) {
                    return StreamBuilder<List<SaleDb>>(
                      stream: (db.select(db.sales)).watch(),
                      builder: (context, salesSnap) {
                        return StreamBuilder<List<CustomerDb>>(
                          stream: db.watchCustomers(),
                          builder: (context, customersSnap) {
                            if (returnsSnap.connectionState ==
                                    ConnectionState.waiting ||
                                salesSnap.connectionState ==
                                    ConnectionState.waiting ||
                                customersSnap.connectionState ==
                                    ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final returns =
                                returnsSnap.data ?? const <SalesReturnDb>[];
                            final sales = salesSnap.data ?? const <SaleDb>[];
                            final customers =
                                customersSnap.data ?? const <CustomerDb>[];
                            final saleById = {
                              for (final sale in sales) sale.localId: sale,
                            };
                            final customerById = {
                              for (final customer in customers)
                                customer.id: customer,
                            };

                            final filtered = returns.where((salesReturn) {
                              if (_query.isEmpty) return true;
                              final originalSale =
                                  salesReturn.originalSaleLocalId == null
                                  ? null
                                  : saleById[salesReturn.originalSaleLocalId!];
                              final customerName =
                                  originalSale?.customerId == null
                                  ? 'عميل عام'
                                  : (customerById[originalSale!.customerId!]
                                            ?.name ??
                                        'عميل عام');
                              final originalInvoice =
                                  originalSale?.invoiceNo ?? '';
                              return (salesReturn.returnNo ?? '')
                                      .toLowerCase()
                                      .contains(_query) ||
                                  originalInvoice.toLowerCase().contains(
                                    _query,
                                  ) ||
                                  customerName.toLowerCase().contains(_query) ||
                                  (salesReturn.reason ?? '')
                                      .toLowerCase()
                                      .contains(_query);
                            }).toList();

                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text(
                                  'لا توجد فواتير مرتجعة للعرض',
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
                              itemBuilder: (context, index) {
                                final salesReturn = filtered[index];
                                final originalSale =
                                    salesReturn.originalSaleLocalId == null
                                    ? null
                                    : saleById[salesReturn
                                          .originalSaleLocalId!];
                                final customerName =
                                    originalSale?.customerId == null
                                    ? 'عميل عام'
                                    : (customerById[originalSale!.customerId!]
                                              ?.name ??
                                          'عميل عام');
                                return _SalesReturnListCard(
                                  salesReturn: salesReturn,
                                  originalInvoiceNo:
                                      originalSale?.invoiceNo ??
                                      '#${originalSale?.localId ?? '-'}',
                                  customerName: customerName,
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemCount: filtered.length,
                            );
                          },
                        );
                      },
                    );
                  },
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

class _SalesReturnListCard extends StatelessWidget {
  const _SalesReturnListCard({
    required this.salesReturn,
    required this.originalInvoiceNo,
    required this.customerName,
  });

  final SalesReturnDb salesReturn;
  final String originalInvoiceNo;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    final dateText = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(salesReturn.createdAt);
    final reason = (salesReturn.reason ?? '').trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final ultraCompact = constraints.maxWidth < 760;
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
                flex: ultraCompact ? 22 : 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      textDirection: ui.TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningPurple.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.warningPurple.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          ),
                          child: Text(
                            'مرتجع',
                            style: AppTextStyles.fieldHint.copyWith(
                              color: AppColors.warningPurple,
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 10 : 11,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Text(
                            salesReturn.returnNo?.trim().isNotEmpty == true
                                ? salesReturn.returnNo!.trim()
                                : 'مرتجع #${salesReturn.localId}',
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: compact ? 13 : 14,
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
                    if (reason.isNotEmpty && !ultraCompact) ...[
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: AppTextStyles.fieldHint.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: compact ? 10 : 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: ultraCompact ? 34 : 36,
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Expanded(
                      child: _ReturnInfoTile(
                        label: 'الفاتورة الأصلية',
                        value: originalInvoiceNo,
                        icon: Icons.receipt_long_outlined,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _ReturnInfoTile(
                        label: 'التاريخ',
                        value: dateText,
                        icon: Icons.event_outlined,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _ReturnInfoTile(
                        label: 'الإجمالي',
                        value: '${money.format(salesReturn.total)} ريال',
                        icon: Icons.restart_alt,
                        valueColor: AppColors.dangerRed,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReturnInfoTile extends StatelessWidget {
  const _ReturnInfoTile({
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
              Text(label, style: AppTextStyles.summaryLabel),
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
