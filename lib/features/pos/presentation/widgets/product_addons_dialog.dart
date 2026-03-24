import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../cart_provider.dart';

class ProductAddonGroupView {
  const ProductAddonGroupView({required this.group, required this.items});

  final AddonGroupDb group;
  final List<AddonItemDb> items;
}

class ProductAddonsDialog extends StatefulWidget {
  const ProductAddonsDialog({
    super.key,
    required this.productName,
    required this.groups,
    required this.initialSelected,
  });

  final String productName;
  final List<ProductAddonGroupView> groups;
  final List<CartAddonSelection> initialSelected;

  static Future<List<CartAddonSelection>?> show(
    BuildContext context, {
    required String productName,
    required List<ProductAddonGroupView> groups,
    required List<CartAddonSelection> initialSelected,
  }) {
    return showDialog<List<CartAddonSelection>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ProductAddonsDialog(
          productName: productName,
          groups: groups,
          initialSelected: initialSelected,
        ),
      ),
    );
  }

  @override
  State<ProductAddonsDialog> createState() => _ProductAddonsDialogState();
}

class _ProductAddonsDialogState extends State<ProductAddonsDialog> {
  late final Map<int, CartAddonSelection> _selectedByItemId = {
    for (final addon in widget.initialSelected) addon.itemId: addon,
  };

  void _toggleAddon(AddonGroupDb group, AddonItemDb item) {
    setState(() {
      if (_selectedByItemId.containsKey(item.id)) {
        _selectedByItemId.remove(item.id);
      } else {
        _selectedByItemId[item.id] = CartAddonSelection(
          groupId: group.id,
          groupName: group.name,
          itemId: item.id,
          itemName: item.name,
          price: item.price,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(
        top: 74,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'الإضافات للمنتجات:',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.topbarIconBlue,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
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
              const SizedBox(height: 12),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final section in widget.groups) ...[
                          _AddonGroupCard(
                            title: section.group.name,
                            children: [
                              for (final item in section.items)
                                _AddonChoiceChip(
                                  label: item.price > 0
                                      ? '${item.name} (${item.price.toStringAsFixed(2)} ريال)'
                                      : item.name,
                                  selected: _selectedByItemId.containsKey(
                                    item.id,
                                  ),
                                  onTap: () =>
                                      _toggleAddon(section.group, item),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  FilledButton(
                    onPressed: () {
                      final selected = _selectedByItemId.values.toList()
                        ..sort((a, b) {
                          final groupCompare = a.groupId.compareTo(b.groupId);
                          if (groupCompare != 0) return groupCompare;
                          return a.itemId.compareTo(b.itemId);
                        });
                      Navigator.of(context).pop(selected);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.controlPanelHeaderBlue,
                    ),
                    child: const Text('إضافة'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonGroupCard extends StatelessWidget {
  const _AddonGroupCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              title,
              style: AppTextStyles.fieldText.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              textDirection: TextDirection.rtl,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonChoiceChip extends StatelessWidget {
  const _AddonChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFE11D48) : const Color(0xFF0B4A8A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
