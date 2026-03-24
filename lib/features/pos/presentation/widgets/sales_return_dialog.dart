import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../data/sales_return_service.dart';

class SalesReturnDialog extends ConsumerStatefulWidget {
  const SalesReturnDialog({
    super.key,
    required this.sale,
    required this.customerName,
  });

  final SaleDb sale;
  final String customerName;

  @override
  ConsumerState<SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _SalesReturnDialogState extends ConsumerState<SalesReturnDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final Map<int, int> _selectedQtyByProduct = <int, int>{};
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _setQty(ReturnableSaleItem item, int qty) {
    final normalized = qty.clamp(0, item.availableQty);
    setState(() {
      if (normalized == 0) {
        _selectedQtyByProduct.remove(item.productId);
      } else {
        _selectedQtyByProduct[item.productId] = normalized;
      }
    });
  }

  int _qtyFor(ReturnableSaleItem item) =>
      _selectedQtyByProduct[item.productId] ?? 0;

  double _totalForItems(List<ReturnableSaleItem> items) {
    return items.fold<double>(0, (sum, item) {
      final qty = _qtyFor(item);
      return sum + (item.unitPrice * qty);
    });
  }

  int _itemsCount(List<ReturnableSaleItem> items) {
    return items.fold<int>(0, (sum, item) => sum + _qtyFor(item));
  }

  Future<void> _submit(SalesReturnDraftData draft) async {
    if (_saving) return;
    final requestItems = draft.items
        .map(
          (item) => SalesReturnRequestItem(
            productId: item.productId,
            serverProductId: item.serverProductId,
            nameSnapshot: item.name,
            qty: _qtyFor(item),
            price: item.unitPrice,
          ),
        )
        .where((item) => item.qty > 0)
        .toList();
    if (requestItems.isEmpty) {
      AppFeedback.warning(context, 'اختر صنفاً واحداً على الأقل');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ref
          .read(salesReturnServiceProvider)
          .createSalesReturn(
            sale: widget.sale,
            items: requestItems,
            reason: _reasonController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر إنشاء مرتجع المبيعات: $error');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    final viewport = MediaQuery.sizeOf(context);
    final compactDialog = viewport.width < 1000;
    final horizontalInset = compactDialog ? AppSpacing.md : AppSpacing.xl;
    final verticalInset = compactDialog ? AppSpacing.md : AppSpacing.lg;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      backgroundColor: AppColors.surface,
      child: SizedBox(
        width: compactDialog ? viewport.width - (horizontalInset * 2) : 860,
        height: compactDialog ? viewport.height - (verticalInset * 2) : 640,
        child: FutureBuilder<SalesReturnDraftData>(
          future: ref
              .read(salesReturnServiceProvider)
              .loadDraft(widget.sale.localId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 420,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return SizedBox(
                height: 360,
                child: Center(
                  child: Text(
                    'تعذر تحميل بيانات المرتجع',
                    style: AppTextStyles.fieldText.copyWith(
                      color: AppColors.dangerRed,
                    ),
                  ),
                ),
              );
            }

            final draft = snapshot.data!;
            final items = draft.items;
            final returnTotal = _totalForItems(items);
            final selectedItemsCount = _itemsCount(items);

            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final spacing = compact ? AppSpacing.xs : AppSpacing.sm;

                return Padding(
                  padding: EdgeInsets.all(
                    compact ? AppSpacing.md : AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          Text(
                            'مرتجع المبيعات',
                            style: AppTextStyles.topbarTitle.copyWith(
                              fontSize: compact ? 14 : 15,
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
                      SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                      Row(
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          Expanded(
                            child: _ReturnHeaderCard(
                              title: 'الفاتورة',
                              value:
                                  widget.sale.invoiceNo ??
                                  '#${widget.sale.localId}',
                              icon: Icons.receipt_long_outlined,
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: _ReturnHeaderCard(
                              title: 'العميل',
                              value: widget.customerName,
                              icon: AppIcons.user,
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: _ReturnHeaderCard(
                              title: 'إجمالي المرتجع',
                              value: '${money.format(returnTotal)} ريال',
                              icon: AppIcons.refund,
                              valueColor: AppColors.dangerRed,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  compact ? AppSpacing.sm : AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.fieldBorder,
                                  ),
                                ),
                                child: items.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(AppSpacing.lg),
                                        child: Text(
                                          'لا توجد أصناف متاحة للمرتجع على هذه الفاتورة',
                                          style: AppTextStyles.fieldHint,
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < items.length;
                                            i++
                                          ) ...[
                                            if (i > 0)
                                              SizedBox(height: spacing),
                                            _ReturnableItemCard(
                                              item: items[i],
                                              selectedQty: _qtyFor(items[i]),
                                              compact: compact,
                                              onChanged: (qty) =>
                                                  _setQty(items[i], qty),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                              SizedBox(
                                height: compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              TextField(
                                controller: _reasonController,
                                textAlign: TextAlign.right,
                                textDirection: ui.TextDirection.rtl,
                                maxLines: compact ? 2 : 3,
                                decoration: InputDecoration(
                                  hintText: 'سبب المرتجع أو ملاحظة إضافية',
                                  hintStyle: AppTextStyles.fieldHint,
                                  filled: true,
                                  fillColor: AppColors.fieldBackground,
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
                                    borderSide: const BorderSide(
                                      color: AppColors.borderBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                      Row(
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Text(
                              'عدد الأصناف المحددة: $selectedItemsCount',
                              style: AppTextStyles.fieldText.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: compact ? 11 : 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: spacing),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              textDirection: ui.TextDirection.rtl,
                              children: [
                                OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('إغلاق'),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                ElevatedButton.icon(
                                  onPressed: items.isEmpty || _saving
                                      ? null
                                      : () => _submit(draft),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.topbarIconOrange,
                                    foregroundColor: AppColors.white,
                                  ),
                                  icon: const Icon(Icons.restart_alt, size: 16),
                                  label: Text(
                                    _saving ? 'جار الحفظ...' : 'تأكيد المرتجع',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReturnHeaderCard extends StatelessWidget {
  const _ReturnHeaderCard({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
    this.compact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title, style: AppTextStyles.summaryLabel),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: compact ? 14 : 16,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _ReturnableItemCard extends StatelessWidget {
  const _ReturnableItemCard({
    required this.item,
    required this.selectedQty,
    required this.onChanged,
    this.compact = false,
  });

  final ReturnableSaleItem item;
  final int selectedQty;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.fieldText.copyWith(
                    fontSize: compact ? 12 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'المباع ${item.soldQty} | المرتجع ${item.returnedQty} | المتاح ${item.availableQty}',
                  style: AppTextStyles.fieldHint.copyWith(
                    fontSize: compact ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
          SizedBox(
            width: compact ? 90 : 110,
            child: Text(
              '${money.format(item.unitPrice)} ريال',
              style: AppTextStyles.fieldText.copyWith(
                color: AppColors.textSecondary,
                fontSize: compact ? 11 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  constraints: BoxConstraints.tightFor(
                    width: compact ? 30 : 36,
                    height: compact ? 30 : 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: selectedQty > 0
                      ? () => onChanged(selectedQty - 1)
                      : null,
                  icon: Icon(Icons.remove, size: compact ? 14 : 16),
                ),
                Text(
                  '$selectedQty',
                  style: AppTextStyles.fieldText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
                IconButton(
                  constraints: BoxConstraints.tightFor(
                    width: compact ? 30 : 36,
                    height: compact ? 30 : 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: selectedQty < item.availableQty
                      ? () => onChanged(selectedQty + 1)
                      : null,
                  icon: Icon(Icons.add, size: compact ? 14 : 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
