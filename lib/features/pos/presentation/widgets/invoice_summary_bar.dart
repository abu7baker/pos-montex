import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';

class InvoiceSummaryBar extends StatelessWidget {
  const InvoiceSummaryBar({
    super.key,
    required this.cart,
    required this.discount,
    required this.onDiscountTap,
    required this.delivery,
    required this.onDeliveryTap,
    this.service = 0,
    this.showServiceCost = true,
    this.compact = false,
  });

  final dynamic cart;
  final double discount;
  final VoidCallback onDiscountTap;
  final double delivery;
  final VoidCallback onDeliveryTap;
  final double service;
  final bool showServiceCost;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final itemCount = cart.items.fold(0.0, (sum, item) => sum + item.qty);
    final total = cart.total;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 4 : 6,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.neutralGrey)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SummaryInline(
                      label: 'العناصر',
                      value: currency.format(itemCount),
                      compact: compact,
                    ),
                    _SummaryInline(
                      label: 'المجموع',
                      value: currency.format(total),
                      compact: compact,
                    ),
                    _SummaryActionInline(
                      label: 'الخصم (-)',
                      value: currency.format(discount),
                      onTap: onDiscountTap,
                      tooltip: 'تعديل الخصم',
                      compact: compact,
                    ),
                    _SummaryActionInline(
                      label: 'التوصيل (+)',
                      value: currency.format(delivery),
                      onTap: onDeliveryTap,
                      tooltip: 'تعديل رسوم التوصيل',
                      compact: compact,
                    ),
                    if (showServiceCost)
                      _SummaryActionInline(
                        label: 'تكلفة الخدمة (+)',
                        value: currency.format(service),
                        tooltip: 'تكلفة الخدمة',
                        compact: compact,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryInline extends StatelessWidget {
  const _SummaryInline({
    required this.label,
    required this.value,
    this.compact = false,
  });
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF556B8D);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SummaryActionInline extends StatelessWidget {
  const _SummaryActionInline({
    required this.label,
    required this.value,
    this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF556B8D);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.info,
          size: compact ? 14 : 16,
          color: const Color(0xFF00BCD4),
        ),
        const SizedBox(width: 4),
        Icon(Icons.edit_note, size: compact ? 16 : 18, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );

    final wrapped = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 2),
        child: content,
      ),
    );
    final message = tooltip ?? label;
    if (message.trim().isEmpty) return wrapped;
    return Tooltip(message: message, child: wrapped);
  }
}
