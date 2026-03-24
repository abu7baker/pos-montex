import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/settings/branch_option.dart';
import '../../../../core/settings/pos_feature_settings.dart';
import '../../../../core/ui/app_dialogs.dart';
import 'pos_select.dart';

class PosTopBar extends ConsumerWidget {
  const PosTopBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features =
        ref.watch(posFeatureSettingsProvider).valueOrNull ??
        PosFeatureSettings.defaults();

    return Container(
      height: compact ? 40 : 46,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? AppSpacing.sm.toDouble()
            : AppSpacing.md.toDouble(),
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.neutralGrey)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWideLayout = 1200.0;
          final wideLayout = constraints.maxWidth >= minWideLayout;
          final effectiveCompact = compact;

          if (wideLayout) {
            return Row(
              children: [
                _RightInfoGroup(compact: effectiveCompact),
                SizedBox(
                  width: effectiveCompact ? 8 : AppSpacing.md.toDouble(),
                ),
                const Spacer(),
                _ActionsGroup(
                  compact: effectiveCompact,
                  showSalesReturn: features.showSalesReturn,
                  showPaymentVoucher: features.showPaymentVoucher,
                  showReceiptVoucher: features.showReceiptVoucher,
                  showExpense: features.showExpense,
                  onOpenProducts: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.controlPanelSettings,
                    );
                  },
                  onOpenSuspended: () => AppDialogs.showSuspendedSales(context),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RightInfoGroup(compact: effectiveCompact),
                SizedBox(
                  width: effectiveCompact ? 8 : AppSpacing.md.toDouble(),
                ),
                _ActionsGroup(
                  compact: effectiveCompact,
                  showSalesReturn: features.showSalesReturn,
                  showPaymentVoucher: features.showPaymentVoucher,
                  showReceiptVoucher: features.showReceiptVoucher,
                  showExpense: features.showExpense,
                  onOpenProducts: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.controlPanelSettings,
                    );
                  },
                  onOpenSuspended: () => AppDialogs.showSuspendedSales(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionsGroup extends StatelessWidget {
  const _ActionsGroup({
    required this.compact,
    required this.showSalesReturn,
    required this.showPaymentVoucher,
    required this.showReceiptVoucher,
    required this.showExpense,
    required this.onOpenProducts,
    required this.onOpenSuspended,
  });

  final bool compact;
  final bool showSalesReturn;
  final bool showPaymentVoucher;
  final bool showReceiptVoucher;
  final bool showExpense;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenSuspended;

  List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return const [];
    final output = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) {
        output.add(SizedBox(width: spacing));
      }
      output.add(widgets[i]);
    }
    return output;
  }

  @override
  Widget build(BuildContext context) {
    final trailingPills = <Widget>[
      if (showExpense)
        _TopPillButton(
          label: 'إضافة المصاريف',
          compact: compact,
          color: AppColors.surface,
          textColor: AppColors.textPrimary,
          borderColor: AppColors.fieldBorder,
          icon: Icons.remove,
          iconBackgroundColor: AppColors.textPrimary,
          iconColor: AppColors.white,
          tooltip: 'إضافة المصاريف',
          onTap: () => AppDialogs.showExpenseDialog(context),
        ),
      if (showSalesReturn)
        _TopPillButton(
          compact: compact,
          label: 'مرتجع المبيعات',
          color: AppColors.pillBlue,
          icon: AppIcons.add,
          iconBackgroundColor: AppColors.white,
          iconColor: AppColors.pillBlue,
          onTap: () => AppDialogs.showSalesReturnsDialog(context),
          tooltip: 'مرتجع المبيعات',
        ),
      if (showPaymentVoucher)
        _TopPillButton(
          compact: compact,
          label: 'سند صرف',
          color: AppColors.pillPurple,
          icon: AppIcons.add,
          iconBackgroundColor: AppColors.white,
          iconColor: AppColors.pillPurple,
          tooltip: 'سند صرف',
          onTap: () => AppDialogs.showDisbursementVoucherDialog(context),
        ),
      if (showReceiptVoucher)
        _TopPillButton(
          compact: compact,
          label: 'سند قبض',
          color: AppColors.pillPink,
          icon: AppIcons.add,
          iconBackgroundColor: AppColors.white,
          iconColor: AppColors.pillPink,
          tooltip: 'سند قبض',
          onTap: () => AppDialogs.showReceiptVoucherDialog(context),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: ui.TextDirection.ltr,
      children: [
        _TopIconButton(
          compact: compact,
          icon: AppIcons.back,
          color: AppColors.topbarIconBlue,
          onTap: onOpenProducts,
          tooltip: 'لوحة التحكم',
        ),
        const SizedBox(width: AppSpacing.xs),
        _TopIconButton(
          compact: compact,
          icon: AppIcons.close,
          color: AppColors.topbarIconRed,
          tooltip: 'إغلاق الوردية',
          onTap: () => AppDialogs.showShiftCloseDialog(context),
        ),
        const SizedBox(width: AppSpacing.xs),
        _TopIconButton(
          compact: compact,
          icon: AppIcons.info,
          color: AppColors.topbarIconDeepBlue,
          tooltip: 'تفاصيل الوردية',
          onTap: () => AppDialogs.showShiftDetailsDialog(context),
        ),
        const SizedBox(width: AppSpacing.xs),
        _TopIconButton(
          compact: compact,
          icon: AppIcons.calculator,
          color: AppColors.topbarIconIndigo,
          tooltip: 'آلة حاسبة',
        ),
        const SizedBox(width: AppSpacing.xs),
        _TopIconButton(
          compact: compact,
          icon: AppIcons.pause,
          color: AppColors.topbarIconOrange,
          onTap: onOpenSuspended,
          tooltip: 'المبيعات المعلقة',
        ),
        if (trailingPills.isNotEmpty) const SizedBox(width: AppSpacing.sm),
        ..._withSpacing(trailingPills, AppSpacing.xs.toDouble()),
      ],
    );
  }
}

class _RightInfoGroup extends StatelessWidget {
  const _RightInfoGroup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PosBranchLabel(compact: compact),
        SizedBox(width: compact ? 4 : AppSpacing.xs.toDouble()),
        _ProjectBranchSelector(compact: compact),
        SizedBox(width: compact ? 6 : AppSpacing.sm.toDouble()),
        _ClockText(compact: compact),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    this.compact = false,
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  final bool compact;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: compact ? 26 : 30,
        height: compact ? 26 : 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: compact ? 14 : 17, color: AppColors.white),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _TopPillButton extends StatelessWidget {
  const _TopPillButton({
    this.compact = false,
    required this.label,
    required this.color,
    this.icon,
    this.iconBackgroundColor,
    this.iconColor,
    this.textColor,
    this.borderColor,
    this.tooltip,
    this.onTap,
  });

  final bool compact;
  final String label;
  final Color color;
  final IconData? icon;
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final Color? borderColor;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: compact ? 26 : 32,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              label,
              style: AppTextStyles.buttonTextStyle.copyWith(
                fontSize: compact ? 11 : 13,
                color: textColor ?? AppColors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor ?? Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: compact ? 11 : 13,
                    color: iconColor ?? AppColors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.buttonTextStyle.copyWith(
                    fontSize: compact ? 11 : 13,
                    color: textColor ?? AppColors.white,
                  ),
                ),
              ],
            ),
    );
    final tappable = onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: content,
          );
    final resolved = tooltip ?? label;
    if (resolved.trim().isEmpty) return tappable;
    return Tooltip(message: resolved, child: tappable);
  }
}

// ignore: unused_element
class _BranchLabel extends StatelessWidget {
  const _BranchLabel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'الفرع',
      style: AppTextStyles.topbarTitle.copyWith(fontSize: compact ? 13 : 15),
    );
  }
}

// ignore: unused_element
class _BranchNameField extends ConsumerWidget {
  const _BranchNameField({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDbProvider);
    return FutureBuilder<String?>(
      future: db.getSetting('branch_name'),
      builder: (context, snapshot) {
        final branchName = (snapshot.data ?? '').trim();
        final displayName = branchName.isNotEmpty
            ? branchName
            : 'الفرع الافتراضي';

        return Container(
          width: compact ? 120 : 150,
          height: compact ? 26 : 30,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.fieldBorder),
            color: AppColors.fieldBackground,
          ),
          child: Row(
            textDirection: ui.TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.fieldText.copyWith(
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.storefront_outlined,
                size: compact ? 13 : 15,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PosBranchLabel extends StatelessWidget {
  const _PosBranchLabel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'الفرع',
      style: AppTextStyles.topbarTitle.copyWith(fontSize: compact ? 13 : 15),
    );
  }
}

// ignore: unused_element
class _PosBranchSelector extends ConsumerStatefulWidget {
  const _PosBranchSelector({required this.compact});

  final bool compact;

  @override
  ConsumerState<_PosBranchSelector> createState() => _PosBranchSelectorState();
}

class _PosBranchSelectorState extends ConsumerState<_PosBranchSelector> {
  Future<void> _selectBranch(BranchOption branch) async {
    final db = ref.read(appDbProvider);
    await db.setSetting('branch_selection_key', branch.selectionKey);
    await db.setSetting('branch_server_id', '${branch.serverId ?? ''}');
    await db.setSetting('branch_code', branch.code);
    await db.setSetting('branch_name', branch.name);
    await db.setSetting('branch_address', branch.address);
    await db.setSetting('branch_phone', branch.phone);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    return StreamBuilder<String?>(
      stream: db.watchSetting('branch_options_json'),
      builder: (context, optionsSnapshot) {
        final branches = BranchOption.listFromJsonString(optionsSnapshot.data);
        return StreamBuilder<String?>(
          stream: db.watchSetting('branch_selection_key'),
          builder: (context, selectionSnapshot) {
            final selectedKey = (selectionSnapshot.data ?? '').trim();
            BranchOption? selectedBranch;

            if (selectedKey.isNotEmpty) {
              for (final branch in branches) {
                if (branch.selectionKey == selectedKey) {
                  selectedBranch = branch;
                  break;
                }
              }
            }
            selectedBranch ??= branches.isNotEmpty ? branches.first : null;

            final fieldWidth = widget.compact ? 152.0 : 188.0;
            final textStyle = AppTextStyles.fieldText.copyWith(
              fontSize: widget.compact ? 11 : 12,
              color: AppColors.textPrimary,
            );

            return Container(
              width: fieldWidth,
              height: widget.compact ? 26 : 30,
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.fieldBorder),
                color: AppColors.fieldBackground,
              ),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: widget.compact ? 13 : 15,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(
                    width: widget.compact ? 4 : AppSpacing.xs.toDouble(),
                  ),
                  Expanded(
                    child: branches.isEmpty
                        ? Text(
                            'الفرع الافتراضي',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: textStyle,
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBranch?.selectionKey,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: widget.compact ? 15 : 17,
                                color: AppColors.textSecondary,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              style: textStyle,
                              selectedItemBuilder: (context) {
                                return branches
                                    .map(
                                      (branch) => Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          branch.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: textStyle,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false);
                              },
                              items: branches
                                  .map(
                                    (branch) => DropdownMenuItem<String>(
                                      value: branch.selectionKey,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          branch.displayLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: textStyle,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) return;
                                for (final branch in branches) {
                                  if (branch.selectionKey == value) {
                                    _selectBranch(branch);
                                    break;
                                  }
                                }
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProjectBranchSelector extends ConsumerStatefulWidget {
  const _ProjectBranchSelector({required this.compact});

  final bool compact;

  @override
  ConsumerState<_ProjectBranchSelector> createState() =>
      _ProjectBranchSelectorState();
}

class _ProjectBranchSelectorState
    extends ConsumerState<_ProjectBranchSelector> {
  Future<void> _selectBranch(BranchOption branch) async {
    final db = ref.read(appDbProvider);
    await db.setSetting('branch_selection_key', branch.selectionKey);
    await db.setSetting('branch_server_id', '${branch.serverId ?? ''}');
    await db.setSetting('branch_code', branch.code);
    await db.setSetting('branch_name', branch.name);
    await db.setSetting('branch_address', branch.address);
    await db.setSetting('branch_phone', branch.phone);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    return StreamBuilder<String?>(
      stream: db.watchSetting('branch_options_json'),
      builder: (context, optionsSnapshot) {
        final branches = BranchOption.listFromJsonString(optionsSnapshot.data);
        return StreamBuilder<String?>(
          stream: db.watchSetting('branch_selection_key'),
          builder: (context, selectionSnapshot) {
            final selectedKey = (selectionSnapshot.data ?? '').trim();
            BranchOption? selectedBranch;
            for (final branch in branches) {
              if (branch.selectionKey == selectedKey) {
                selectedBranch = branch;
                break;
              }
            }
            selectedBranch ??= branches.isNotEmpty ? branches.first : null;

            final fieldWidth = widget.compact ? 152.0 : 188.0;
            if (branches.isEmpty) {
              return Container(
                width: fieldWidth,
                height: widget.compact ? 26 : 30,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.fieldBorder),
                  color: AppColors.fieldBackground,
                ),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: widget.compact ? 13 : 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(
                      width: widget.compact ? 4 : AppSpacing.xs.toDouble(),
                    ),
                    Expanded(
                      child: Text(
                        'الفرع الافتراضي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.fieldText.copyWith(
                          fontSize: widget.compact ? 11 : 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return PosSelect<String>(
              options: [
                for (final branch in branches)
                  PosSelectOption<String>(
                    value: branch.selectionKey,
                    label: branch.name,
                    subtitle: branch.code.isEmpty ? null : '(${branch.code})',
                  ),
              ],
              value: selectedBranch?.selectionKey,
              onChanged: (value) {
                if (value == null) return;
                for (final branch in branches) {
                  if (branch.selectionKey == value) {
                    _selectBranch(branch);
                    break;
                  }
                }
              },
              hintText: 'اختر الفرع',
              width: fieldWidth,
              height: widget.compact ? 30 : 34,
              borderRadius: 8,
              fieldPadding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 10,
              ),
              leadingIcon: Icons.storefront_outlined,
              leadingIconColor: AppColors.textSecondary,
              leadingIconSize: widget.compact ? 13 : 15,
              enableSearch: branches.length > 6,
              minSearchChars: 0,
              searchHintText: 'ابحث عن الفرع',
              dropdownItemExtent: widget.compact ? 38 : 42,
              maxDropdownHeight: 220,
            );
          },
        );
      },
    );
  }
}

class _ClockText extends StatefulWidget {
  const _ClockText({required this.compact});

  final bool compact;

  @override
  State<_ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<_ClockText> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('a hh:mm:ss dd-MM-yyyy').format(_now);
    return Container(
      height: widget.compact ? 26 : 30,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.fieldBorder),
        color: AppColors.fieldBackground,
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: widget.compact ? 13 : 15,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: widget.compact ? 4 : AppSpacing.xs.toDouble()),
          Text(
            formatted,
            style: AppTextStyles.topbarInfo.copyWith(
              fontSize: widget.compact
                  ? 11
                  : (AppTextStyles.topbarInfo.fontSize ?? 12),
            ),
          ),
        ],
      ),
    );
  }
}
