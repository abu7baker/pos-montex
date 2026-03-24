import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../cart_provider.dart';

class PosBottomSummary extends StatelessWidget {
  const PosBottomSummary({super.key, required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final itemCount = cart.items.fold<int>(0, (sum, item) => sum + item.qty);
    const tax = 0.0;
    const delivery = 0.0;
    const service = 0.0;
    const discount = 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutralGrey),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryInline(label: 'عناصر', value: itemCount.toDouble().toStringAsFixed(2)),
              const Spacer(),
              _SummaryInline(label: 'المجموع', value: currency.format(cart.total)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _SummaryActionItem(label: 'الخصم (-)', value: currency.format(discount))),
              Expanded(child: _SummaryActionItem(label: 'ضريبة الطلبية (+)', value: currency.format(tax))),
              Expanded(child: _SummaryActionItem(label: 'التوصيل (+)', value: currency.format(delivery))),
              Expanded(child: _SummaryActionItem(label: 'تكلفة الخدمة (+)', value: currency.format(service))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryInline extends StatelessWidget {
  const _SummaryInline({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: AppTextStyles.summaryLabel);
  }
}

class _SummaryActionItem extends StatelessWidget {
  const _SummaryActionItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(AppIcons.info, size: 14, color: AppColors.borderBlue),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.summaryLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(AppIcons.edit, size: 14, color: AppColors.primaryBlue),
        const SizedBox(width: AppSpacing.xs),
        Text(value, style: AppTextStyles.summaryValue),
      ],
    );
  }
}
