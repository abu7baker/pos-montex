import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_icons.dart';
import '../../../../core/payment_methods.dart';
import '../../../../core/payment_methods_provider.dart';
import 'pos_select.dart';

/// اختيار طريقة الدفع باستخدام القائمة الموحدة من [PaymentMethods].
/// يُستخدم في إضافة المصاريف، سند الصرف، سند القبض، وإدارة النقدية.
class PaymentMethodSelect extends ConsumerWidget {
  const PaymentMethodSelect({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'طريقة الدفع',
    this.height = 34,
    this.borderRadius = 6,
    this.fieldPadding,
    this.enableSearch = true,
    this.leadingIcon = AppIcons.cash,
    this.leadingIconBoxed = true,
    this.leadingIconBoxSize = 20,
    this.leadingIconSize = 14,
    this.enabled = true,
    this.maxDropdownHeight = 0,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String hintText;
  final double height;
  final double borderRadius;
  final EdgeInsets? fieldPadding;
  final bool enableSearch;
  final IconData? leadingIcon;
  final bool leadingIconBoxed;
  final double leadingIconBoxSize;
  final double leadingIconSize;
  final bool enabled;

  /// إذا > 0 تصبح قائمة طرق الدفع قابلة للتمرير بهذا الارتفاع (بكسل).
  final double maxDropdownHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods =
        ref.watch(branchPaymentMethodsProvider).valueOrNull ??
        PaymentMethods.options;
    final normalizedValue = value == null
        ? null
        : PaymentMethods.normalizeCode(value!);
    final hasSelectedValue =
        normalizedValue != null &&
        methods.any(
          (method) =>
              PaymentMethods.normalizeCode(method.code) == normalizedValue,
        );

    return PosSelect<String>(
      options: [
        for (final method in methods)
          PosSelectOption(value: method.code, label: method.label),
      ],
      value: hasSelectedValue ? normalizedValue : null,
      onChanged: enabled
          ? (v) => onChanged(
              v ??
                  (methods.isNotEmpty
                      ? methods.first.code
                      : PaymentMethods.defaultCode),
            )
          : null,
      hintText: hintText,
      height: height,
      borderRadius: borderRadius,
      fieldPadding: fieldPadding ?? const EdgeInsets.symmetric(horizontal: 12),
      enableSearch: enableSearch,
      leadingIcon: leadingIcon,
      leadingIconBoxed: leadingIconBoxed,
      leadingIconBoxSize: leadingIconBoxSize,
      leadingIconSize: leadingIconSize,
      enabled: enabled,
      maxDropdownHeight: maxDropdownHeight,
      autoDropdownHeight: maxDropdownHeight <= 0,
    );
  }
}
