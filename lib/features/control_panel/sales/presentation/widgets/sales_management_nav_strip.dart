import 'package:flutter/material.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../control_panel/presentation/control_panel_shell.dart';

class SalesManagementNavStrip extends StatelessWidget {
  const SalesManagementNavStrip({super.key, required this.current});

  final ControlPanelSection current;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SalesNavItem(
        section: ControlPanelSection.salesAll,
        route: AppRoutes.controlPanelSalesAll,
        label: 'كل المبيعات',
        icon: Icons.receipt_long_outlined,
      ),
      _SalesNavItem(
        section: ControlPanelSection.salesReturns,
        route: AppRoutes.controlPanelSalesReturns,
        label: 'مرتجعات المبيعات',
        icon: Icons.assignment_return_outlined,
      ),
      _SalesNavItem(
        section: ControlPanelSection.salesCredit,
        route: AppRoutes.controlPanelSalesCredit,
        label: 'المبيعات الآجلة',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _SalesNavItem(
        section: ControlPanelSection.salesQuotations,
        route: AppRoutes.controlPanelSalesQuotations,
        label: 'العروض السعرية',
        icon: Icons.description_outlined,
      ),
    ];

    final tiles = <Widget>[
      for (final item in items)
        _QuickRouteTile(
          label: item.label,
          icon: item.icon,
          active: current == item.section,
          onTap: current == item.section
              ? null
              : () => Navigator.pushReplacementNamed(context, item.route),
        ),
      _QuickRouteTile(
        label: 'تقارير المبيعات',
        icon: Icons.assessment_outlined,
        active: current == ControlPanelSection.reportsSales,
        onTap: () => Navigator.pushReplacementNamed(
          context,
          AppRoutes.controlPanelReportsSales,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.neutralGrey.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1100;
          if (!isCompact) {
            return Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          }

          final tileWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
            ],
          );
        },
      ),
    );
  }
}

class _QuickRouteTile extends StatelessWidget {
  const _QuickRouteTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryBlue : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.selectHover : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.primaryBlue.withValues(alpha: 0.35)
                : AppColors.fieldBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.fieldText.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesNavItem {
  const _SalesNavItem({
    required this.section,
    required this.route,
    required this.label,
    required this.icon,
  });

  final ControlPanelSection section;
  final String route;
  final String label;
  final IconData icon;
}
