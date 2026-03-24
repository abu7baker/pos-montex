import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class PosBottomActions extends StatelessWidget {
  const PosBottomActions({
    super.key,
    required this.total,
    this.compact = false,
    this.onCash,
    this.onCard,
    this.onDeferred,
    this.onMulti,
    this.onComment,
    this.onCancel,
    this.onReceipt,
    this.onQuotation,
    this.onRecentSales,
    this.onLogout,
  });

  final double total;
  final bool compact;
  final VoidCallback? onCash;
  final VoidCallback? onCard;
  final VoidCallback? onDeferred;
  final VoidCallback? onMulti;
  final VoidCallback? onComment;
  final VoidCallback? onCancel;
  final VoidCallback? onReceipt;
  final VoidCallback? onQuotation;
  final VoidCallback? onRecentSales;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final effectiveCard = onCard ?? onCash;
    final effectiveDeferred = onDeferred ?? onCash;
    final effectiveMulti = onMulti ?? onCash;
    final gap = SizedBox(width: compact ? 6 : AppSpacing.sm.toDouble());

    List<Widget> buildActions({required bool wideLayout}) {
      return [
        _SecondaryActionButton(
          label: 'بيان السعر',
          icon: AppIcons.priceTag,
          onPressed: onQuotation,
          tooltip: 'بيان السعر',
          compact: compact,
        ),
        gap,
        _SecondaryActionButton(
          label: 'تعليق',
          icon: AppIcons.pause,
          onPressed: onComment,
          tooltip: 'تعليق',
          compact: compact,
        ),
        gap,
        _PrimaryActionButton(
          label: 'طرق تحصيل متعددة',
          color: AppColors.actionDarkBlue,
          icon: AppIcons.multi,
          onPressed: effectiveMulti,
          tooltip: 'طرق تحصيل متعددة',
          compact: compact,
        ),
        gap,
        _PrimaryActionButton(
          label: 'أجل',
          color: AppColors.warningPurple,
          icon: AppIcons.deferred,
          onPressed: effectiveDeferred,
          tooltip: 'بيع آجل',
          compact: compact,
        ),
        gap,
        _PrimaryActionButton(
          label: 'بطاقة',
          color: AppColors.dangerRed,
          icon: AppIcons.card,
          onPressed: effectiveCard,
          tooltip: 'بطاقة',
          compact: compact,
        ),
        gap,
        _PrimaryActionButton(
          label: 'كاش',
          color: AppColors.successGreen,
          icon: AppIcons.cash,
          onPressed: onCash,
          tooltip: 'كاش',
          compact: compact,
        ),
        SizedBox(width: compact ? 6 : AppSpacing.sm.toDouble()),
        _TotalValue(
          label: 'الإجمالي',
          value: currency.format(total),
          compact: compact,
        ),
        SizedBox(width: compact ? 6 : AppSpacing.sm.toDouble()),
        _PrimaryActionButton(
          label: 'إلغاء',
          color: AppColors.dangerRed,
          icon: AppIcons.close,
          onPressed: onCancel,
          tooltip: 'إلغاء',
          compact: compact,
        ),
        if (wideLayout)
          const Spacer()
        else
          SizedBox(width: compact ? 6 : AppSpacing.sm.toDouble()),
        _PrimaryActionButton(
          label: 'آخر المبيعات',
          color: AppColors.actionDarkBlue,
          icon: AppIcons.history,
          onPressed: onRecentSales,
          tooltip: 'آخر المبيعات',
          compact: compact,
        ),
        gap,
        _PrimaryActionButton(
          label: 'خروج',
          color: AppColors.dangerRed,
          icon: Icons.logout,
          onPressed: onLogout,
          tooltip: 'تسجيل الخروج',
          compact: compact,
        ),
      ];
    }

    return Container(
      height: compact ? 50 : 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : AppSpacing.sm.toDouble()),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutralGrey),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWideLayout = 1200.0;
          final wideLayout = constraints.maxWidth >= minWideLayout;
          final row = Row(
            mainAxisSize: wideLayout ? MainAxisSize.max : MainAxisSize.min,
            children: buildActions(wideLayout: wideLayout),
          );
          if (wideLayout) {
            return row;
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: row,
          );
        },
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Opacity(
      opacity: enabled ? 1 : 0.9,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: color,
            disabledForegroundColor: AppColors.white,
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          child: _ButtonContent(
            label: label,
            icon: icon,
            iconColor: AppColors.white,
            textStyle: AppTextStyles.buttonTextStyle.copyWith(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
            compact: compact,
          ),
        ),
      ),
    );
    final message = tooltip ?? label;
    if (message.trim().isEmpty) return button;
    return Tooltip(message: message, child: button);
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Opacity(
      opacity: enabled ? 1 : 0.9,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.actionGrey,
            foregroundColor: AppColors.textPrimary,
            disabledBackgroundColor: AppColors.actionGrey,
            disabledForegroundColor: AppColors.textPrimary,
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: AppColors.fieldBorder),
            ),
            elevation: 0,
          ),
          child: _ButtonContent(
            label: label,
            icon: icon,
            iconColor: AppColors.topbarIconDeepBlue,
            textStyle: AppTextStyles.buttonTextDark.copyWith(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
            compact: compact,
          ),
        ),
      ),
    );
    final message = tooltip ?? label;
    if (message.trim().isEmpty) return button;
    return Tooltip(message: message, child: button);
  }
}

class _TotalValue extends StatelessWidget {
  const _TotalValue({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    final valueStyle = TextStyle(
      fontSize: compact ? 14 : 15,
      fontWeight: FontWeight.w700,
      color: AppColors.successGreen,
    );
    return Row(
      children: [
        Text('$label:', style: labelStyle),
        const SizedBox(width: AppSpacing.xs),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.textStyle,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final TextStyle textStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: ui.TextDirection.ltr,
      children: [
        Icon(icon, size: compact ? 13 : 15, color: iconColor),
        SizedBox(width: compact ? 3 : AppSpacing.xs.toDouble()),
        Text(label, style: textStyle),
      ],
    );
  }
}

