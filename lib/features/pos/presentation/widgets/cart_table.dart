import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../cart_provider.dart';
import '../pos_models.dart';
import 'cart_empty_logo.dart';

class CartTable extends StatelessWidget {
  const CartTable({
    super.key,
    required this.cart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onUpdatePrice,
    required this.onEditAddons,
    required this.hasAddonsForProduct,
  });

  final CartState cart;
  final void Function(int lineId) onIncrement;
  final void Function(int lineId) onDecrement;
  final void Function(int lineId) onRemove;
  final void Function(int lineId, double unitPrice) onUpdatePrice;
  final Future<void> Function(CartItem item) onEditAddons;
  final bool Function(int productId) hasAddonsForProduct;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _CartTableMetrics.fromWidth(constraints.maxWidth);
        final tableContent = SizedBox(
          width: metrics.tableWidth,
          child: Stack(
            children: [
              if (cart.items.isEmpty) const Center(child: CartEmptyLogo()),
              Column(
                children: [
                  _CartHeaderRow(metrics: metrics),
                  Expanded(
                    child: _CartItemsList(
                      cart: cart,
                      metrics: metrics,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                      onRemove: onRemove,
                      onUpdatePrice: onUpdatePrice,
                      onEditAddons: onEditAddons,
                      hasAddonsForProduct: hasAddonsForProduct,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return tableContent;
      },
    );
  }
}

class _CartTableMetrics {
  const _CartTableMetrics({
    required this.tableWidth,
    required this.productWidth,
    required this.qtyWidth,
    required this.priceWidth,
    required this.totalWidth,
    required this.removeWidth,
    required this.compact,
    required this.ultraCompact,
  });

  final double tableWidth;
  final double productWidth;
  final double qtyWidth;
  final double priceWidth;
  final double totalWidth;
  final double removeWidth;
  final bool compact;
  final bool ultraCompact;

  static const double _dividerWidth = 1.0;
  static const int _dividerCount = 4;

  static const double _qtyPreferred = 150.0;
  static const double _pricePreferred = 110.0;
  static const double _totalPreferred = 100.0;
  static const double _removePreferred = 40.0;

  static const double _qtyMin = 82.0;
  static const double _priceMin = 70.0;
  static const double _totalMin = 72.0;
  static const double _removeMin = 28.0;

  static const double _productMinNoScroll = 86.0;

  static _CartTableMetrics fromWidth(double maxWidth) {
    final width = maxWidth.clamp(342.0, double.infinity);
    final dividerTotal = _dividerWidth * _dividerCount;
    final preferredFixed =
        _qtyPreferred + _pricePreferred + _totalPreferred + _removePreferred;
    final minFixed = _qtyMin + _priceMin + _totalMin + _removeMin;
    final minTableWidthForNoScroll =
        minFixed + _productMinNoScroll + dividerTotal;

    if (width < minTableWidthForNoScroll) {
      final availableForFixed = width - dividerTotal - _productMinNoScroll;
      final fixedTarget = availableForFixed.clamp(minFixed, preferredFixed);
      final scale = fixedTarget / preferredFixed;
      return _CartTableMetrics(
        tableWidth: width,
        productWidth: _productMinNoScroll,
        qtyWidth: _qtyPreferred * scale,
        priceWidth: _pricePreferred * scale,
        totalWidth: _totalPreferred * scale,
        removeWidth: _removePreferred * scale,
        compact: true,
        ultraCompact: width < 390,
      );
    }

    final availableForFixed = width - dividerTotal - _productMinNoScroll;
    final fixedTarget = availableForFixed >= preferredFixed
        ? preferredFixed
        : availableForFixed.clamp(minFixed, preferredFixed);
    final scale = fixedTarget / preferredFixed;

    final qtyWidth = _qtyPreferred * scale;
    final priceWidth = _pricePreferred * scale;
    final totalWidth = _totalPreferred * scale;
    final removeWidth = _removePreferred * scale;
    final fixed = qtyWidth + priceWidth + totalWidth + removeWidth;
    final productWidth = width - dividerTotal - fixed;

    return _CartTableMetrics(
      tableWidth: width,
      productWidth: productWidth,
      qtyWidth: qtyWidth,
      priceWidth: priceWidth,
      totalWidth: totalWidth,
      removeWidth: removeWidth,
      compact: width < 520,
      ultraCompact: width < 420,
    );
  }
}

class _CartHeaderRow extends StatelessWidget {
  const _CartHeaderRow({required this.metrics});

  final _CartTableMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final effectiveProductWidth = (metrics.productWidth - 2).clamp(
      0.0,
      100000.0,
    );
    return Container(
      height: metrics.compact ? 34 : 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.neutralGrey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: effectiveProductWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'المنتج',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: metrics.compact ? 11 : 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.info,
                  size: metrics.compact ? 13 : 16,
                  color: Color(0xFF00BCD4),
                ),
              ],
            ),
          ),
          const _VerticalDivider(),
          _HeaderCell(
            width: metrics.qtyWidth,
            child: Text(
              'الكمية',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: metrics.compact ? 11 : 13,
              ),
            ),
          ),
          const _VerticalDivider(),
          _HeaderCell(
            width: metrics.priceWidth,
            child: Text(
              'السعر شامل\nالضريبة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: metrics.compact ? 10 : 12,
                height: 1.05,
              ),
            ),
          ),
          const _VerticalDivider(),
          _HeaderCell(
            width: metrics.totalWidth,
            child: Text(
              'المجموع',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: metrics.compact ? 11 : 13,
              ),
            ),
          ),
          const _VerticalDivider(),
          _HeaderCell(
            width: metrics.removeWidth,
            child: Icon(
              Icons.close,
              size: metrics.compact ? 15 : 18,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(child: child),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: AppColors.neutralGrey.withValues(alpha: 0.5),
    );
  }
}

class _CartItemsList extends StatelessWidget {
  const _CartItemsList({
    required this.cart,
    required this.metrics,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onUpdatePrice,
    required this.onEditAddons,
    required this.hasAddonsForProduct,
  });

  final CartState cart;
  final _CartTableMetrics metrics;
  final void Function(int lineId) onIncrement;
  final void Function(int lineId) onDecrement;
  final void Function(int lineId) onRemove;
  final void Function(int lineId, double unitPrice) onUpdatePrice;
  final Future<void> Function(CartItem item) onEditAddons;
  final bool Function(int productId) hasAddonsForProduct;

  double _withTax(double value) {
    return ((value * (1 + PosState.fixedTaxRate)) * 100).round() / 100;
  }

  Future<void> _promptPriceEdit(BuildContext context, CartItem item) async {
    final controller = TextEditingController(
      text: _withTax(item.unitPrice).toStringAsFixed(2),
    );

    final editedPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعديل سعر المنتج'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.product.name,
                  style: AppTextStyles.fieldText,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'السعر الجديد',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim());
                  if (parsed == null) return;
                  final basePrice = parsed / (1 + PosState.fixedTaxRate);
                  Navigator.of(
                    dialogContext,
                  ).pop(((basePrice * 100).round()) / 100);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    if (editedPrice == null) return;
    onUpdatePrice(item.lineId, editedPrice);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    return ListView.builder(
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        final canConfigureAddons = hasAddonsForProduct(item.product.id);
        final hasAddonSummary = item.selectedAddons.isNotEmpty;

        return Container(
          constraints: BoxConstraints(minHeight: metrics.compact ? 58 : 70),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.neutralGrey.withValues(alpha: 0.3),
              ),
            ),
            color: Colors.white,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: metrics.productWidth,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.compact ? 6 : 10,
                      vertical: metrics.compact ? 6 : 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF00B5E2),
                            fontWeight: FontWeight.bold,
                            fontSize: metrics.compact ? 11 : 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item.product.id.toString(),
                              style: TextStyle(
                                color: Color(0xFF00B5E2),
                                fontSize: metrics.compact ? 9 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: metrics.compact ? 2 : 4),
                            Icon(
                              Icons.info,
                              size: metrics.compact ? 12 : 14,
                              color: Color(0xFF00BCD4),
                            ),
                          ],
                        ),
                        if (hasAddonSummary) ...[
                          SizedBox(height: metrics.compact ? 4 : 6),
                          for (final addon in item.selectedAddons.take(3))
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: metrics.compact ? 1 : 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                textDirection: ui.TextDirection.rtl,
                                children: [
                                  Icon(
                                    Icons.subdirectory_arrow_left_rounded,
                                    size: 13,
                                    color: item.hasAddons
                                        ? const Color(0xFFFF2D55)
                                        : const Color(0xFF00B5E2),
                                  ),
                                  SizedBox(width: metrics.compact ? 2 : 4),
                                  Expanded(
                                    child: Text(
                                      addon.price > 0
                                          ? '${addon.itemName} (+ ${currency.format(addon.price)} ريال)'
                                          : addon.itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF556B8D),
                                        fontSize: metrics.compact ? 9 : 10,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.right,
                                      textDirection: ui.TextDirection.rtl,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.selectedAddons.length > 3)
                            Text(
                              '+ ${item.selectedAddons.length - 3} إضافات أخرى',
                              style: TextStyle(
                                color: Color(0xFF7A869A),
                                fontSize: metrics.compact ? 9 : 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.right,
                              textDirection: ui.TextDirection.rtl,
                            ),
                        ],
                        if (canConfigureAddons) ...[
                          SizedBox(height: metrics.compact ? 4 : 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Tooltip(
                              message: item.hasAddons
                                  ? 'تعديل الإضافات'
                                  : 'إضافة إضافات',
                              child: InkWell(
                                onTap: () => onEditAddons(item),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: metrics.compact ? 22 : 26,
                                  height: metrics.compact ? 22 : 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item.hasAddons
                                          ? const Color(0xFFFF2D55)
                                          : const Color(0xFF00B5E2),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.open_in_new_rounded,
                                    size: metrics.compact ? 13 : 15,
                                    color: item.hasAddons
                                        ? const Color(0xFFFF2D55)
                                        : const Color(0xFF00B5E2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const _VerticalDivider(),
                SizedBox(
                  width: metrics.qtyWidth,
                  child: Center(
                    child: Container(
                      height: metrics.compact ? 30 : 34,
                      width: (metrics.qtyWidth - (metrics.compact ? 10 : 20))
                          .clamp(72.0, 130.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.fieldBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            color: Colors.red,
                            onTap: () => onDecrement(item.lineId),
                            tooltip: 'تقليل الكمية',
                            compact: metrics.compact,
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.fieldBorder,
                                  ),
                                  right: BorderSide(
                                    color: AppColors.fieldBorder,
                                  ),
                                ),
                              ),
                              child: Text(
                                item.qty.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: metrics.compact ? 11 : 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add,
                            color: Colors.green,
                            onTap: () => onIncrement(item.lineId),
                            tooltip: 'زيادة الكمية',
                            compact: metrics.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const _VerticalDivider(),
                SizedBox(
                  width: metrics.priceWidth,
                  child: Center(
                    child: InkWell(
                      onTap: () => _promptPriceEdit(context, item),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: (metrics.priceWidth - (metrics.compact ? 8 : 14))
                            .clamp(62.0, 96.0),
                        height: metrics.compact ? 30 : 34,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: item.unitPrice != item.product.price
                                ? AppColors.primaryBlue
                                : AppColors.fieldBorder,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: item.unitPrice != item.product.price
                              ? AppColors.selectHover
                              : Colors.transparent,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit,
                              size: metrics.compact ? 10 : 12,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: metrics.compact ? 2 : 3),
                            Flexible(
                              child: Text(
                                currency.format(_withTax(item.unitPrice)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: metrics.compact ? 11 : 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const _VerticalDivider(),
                SizedBox(
                  width: metrics.totalWidth,
                  child: Center(
                    child: Text(
                      '${currency.format(_withTax(item.total))} ريال',
                      style: TextStyle(
                        color: Color(0xFF556B8D),
                        fontWeight: FontWeight.w600,
                        fontSize: metrics.compact ? 10 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const _VerticalDivider(),
                SizedBox(
                  width: metrics.removeWidth,
                  child: Center(
                    child: Tooltip(
                      message: 'حذف المنتج',
                      child: InkWell(
                        onTap: () => onRemove(item.lineId),
                        child: Container(
                          width: metrics.compact ? 26 : 32,
                          height: metrics.compact ? 26 : 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: metrics.compact ? 16 : 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      child: SizedBox(
        width: compact ? 24 : 32,
        child: Icon(icon, color: color, size: compact ? 15 : 18),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
