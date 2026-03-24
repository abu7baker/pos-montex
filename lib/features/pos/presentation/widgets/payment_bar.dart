import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class PaymentBar extends StatelessWidget {
  const PaymentBar({
    super.key,
    required this.total,
    this.onCancel,
    this.onCash,
    this.onCard,
    this.onDeferred,
    this.onMulti,
  });

  final double total;
  final VoidCallback? onCancel;
  final VoidCallback? onCash;
  final VoidCallback? onCard;
  final VoidCallback? onDeferred;
  final VoidCallback? onMulti;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final effectiveCard = onCard ?? onCash;
    final effectiveDeferred = onDeferred ?? onCash;
    final effectiveMulti = onMulti ?? onCash;
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, -2),
            color: theme.shadowColor.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('الإجمالي: ${currency.format(total)}', style: AppTextStyles.totalStyle),
          const SizedBox(width: 16),
          _PaymentButton(
            label: 'كاش',
            color: AppColors.successGreen,
            onPressed: onCash,
            icon: Icons.payments_outlined,
          ),
          const SizedBox(width: 12),
          _PaymentButton(
            label: 'بطاقة',
            color: AppColors.dangerRed,
            onPressed: effectiveCard,
            icon: Icons.credit_card,
          ),
          const SizedBox(width: 12),
          _PaymentButton(
            label: 'آجل',
            color: AppColors.warningPurple,
            onPressed: effectiveDeferred,
            icon: Icons.schedule,
          ),
          const SizedBox(width: 12),
          _PaymentButton(
            label: 'متعددة',
            color: AppColors.primaryBlue,
            onPressed: effectiveMulti,
            icon: Icons.account_balance_wallet_outlined,
          ),
          const Spacer(),
          _SecondaryButton(label: 'إلغاء', onPressed: onCancel),
          const SizedBox(width: 12),
          _SecondaryButton(label: 'تعليق', onPressed: null),
          const SizedBox(width: 12),
          _SecondaryButton(label: 'مسودة', onPressed: null),
        ],
      ),
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.color,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18, color: onPrimary),
        label: Text(
          label,
          style: AppTextStyles.buttonTextStyle.copyWith(color: onPrimary),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neutralGrey,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonTextStyle.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}
