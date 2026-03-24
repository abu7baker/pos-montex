import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class ReceiptPreviewModal extends StatelessWidget {
  const ReceiptPreviewModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ReceiptPreviewModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.jpg', width: 120, fit: BoxFit.contain),
            const SizedBox(height: AppSpacing.sm),
            Text('فاتورة بيع', style: AppTextStyles.topbarTitle),
            const SizedBox(height: AppSpacing.sm),
            _ReceiptTable(),
            const SizedBox(height: AppSpacing.sm),
            _ReceiptTotal(),
          ],
        ),
      ),
    );
  }
}

class _ReceiptTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutralGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: const [
          _ReceiptHeaderRow(),
          _ReceiptItemRow(name: 'منتج 1', qty: '1', total: '24.00'),
          _ReceiptItemRow(name: 'منتج 2', qty: '2', total: '48.00'),
        ],
      ),
    );
  }
}

class _ReceiptHeaderRow extends StatelessWidget {
  const _ReceiptHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.neutralGrey),
        ),
      ),
      child: Row(
        children: const [
          Expanded(child: Text('الصنف', style: AppTextStyles.cartHeaderStyle)),
          SizedBox(width: 40, child: Center(child: Text('الكمية', style: AppTextStyles.cartHeaderStyle))),
          SizedBox(width: 60, child: Center(child: Text('الإجمالي', style: AppTextStyles.cartHeaderStyle))),
        ],
      ),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  const _ReceiptItemRow({required this.name, required this.qty, required this.total});

  final String name;
  final String qty;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(name, style: AppTextStyles.fieldText)),
          SizedBox(width: 40, child: Center(child: Text(qty, style: AppTextStyles.fieldText))),
          SizedBox(width: 60, child: Center(child: Text(total, style: AppTextStyles.fieldText))),
        ],
      ),
    );
  }
}

class _ReceiptTotal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Text('الإجمالي: 72.00', style: AppTextStyles.totalStyle),
      ],
    );
  }
}
