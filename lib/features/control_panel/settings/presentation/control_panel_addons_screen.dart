import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelAddonsScreen extends ConsumerStatefulWidget {
  const ControlPanelAddonsScreen({super.key});

  @override
  ConsumerState<ControlPanelAddonsScreen> createState() =>
      _ControlPanelAddonsScreenState();
}

class _ControlPanelAddonsScreenState
    extends ConsumerState<ControlPanelAddonsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _search => _searchController.text.trim().toLowerCase();

  Future<void> _openGroupEditor({
    AddonGroupDb? group,
    List<AddonItemDb> initialItems = const <AddonItemDb>[],
  }) async {
    final result = await showDialog<_AddonGroupPayload>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddonGroupEditorDialog(
        initialName: group?.name,
        initialActive: group?.isActive ?? true,
        initialItems: initialItems
            .map((item) => _AddonItemDraft(name: item.name, price: item.price))
            .toList(),
      ),
    );
    if (result == null) return;

    try {
      final db = ref.read(appDbProvider);
      await db.transaction(() async {
        final groupId =
            group?.id ??
            await db.upsertAddonGroup(
              AddonGroupsCompanion.insert(
                name: result.name,
                isActive: drift.Value(result.isActive),
                isDeleted: const drift.Value(false),
                updatedAtLocal: drift.Value(DateTime.now()),
              ),
            );
        if (group != null) {
          await db.upsertAddonGroup(
            AddonGroupsCompanion(
              id: drift.Value(group.id),
              name: drift.Value(result.name),
              isActive: drift.Value(result.isActive),
              isDeleted: const drift.Value(false),
              updatedAtLocal: drift.Value(DateTime.now()),
            ),
          );
        }
        await db.replaceAddonItems(groupId, [
          for (var i = 0; i < result.items.length; i++)
            AddonItemsCompanion.insert(
              groupId: groupId,
              name: result.items[i].name,
              price: drift.Value(result.items[i].price),
              sortOrder: drift.Value(i),
            ),
        ]);
      });
      if (!mounted) return;
      AppFeedback.success(
        context,
        group == null ? 'تم حفظ مجموعة الإضافات' : 'تم تحديث مجموعة الإضافات',
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ مجموعة الإضافات: $error');
    }
  }

  Future<void> _openProductsDialog({
    required AddonGroupDb group,
    required List<ProductDb> allProducts,
    required Set<int> selectedIds,
  }) async {
    final result = await showDialog<Set<int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddonProductsDialog(
        groupName: group.name,
        products: allProducts,
        selectedIds: selectedIds,
      ),
    );
    if (result == null) return;

    try {
      await ref
          .read(appDbProvider)
          .replaceGroupProductAddonLinks(group.id, result.toList()..sort());
      if (!mounted) return;
      AppFeedback.success(context, 'تم تحديث المنتجات المرتبطة بالمجموعة');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ ربط المنتجات: $error');
    }
  }

  Future<void> _deleteGroup(AddonGroupDb group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مجموعة الإضافات'),
        content: Text(
          'هل تريد حذف المجموعة "${group.name}" نهائيًا من الإدارة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف', style: AppTextStyles.buttonTextStyle),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(appDbProvider).softDeleteAddonGroup(group.id);
      if (!mounted) return;
      AppFeedback.success(context, 'تم حذف مجموعة الإضافات');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حذف مجموعة الإضافات: $error');
    }
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.topbarIconDeepBlue],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.topbarIconDeepBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.playlist_add_circle_outlined,
              color: AppColors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إدارة إضافات المنتجات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 6),
                Text(
                  'أنشئ مجموعات إضافات للمطعم، عرّف أسعار كل إضافة، ثم اربطها بالمنتجات الجاهزة للعمل داخل الكاشير.',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: 'ابحث باسم المجموعة أو الإضافة أو المنتج',
      hintStyle: AppTextStyles.fieldHint,
      prefixIcon: const Icon(Icons.search, size: 18),
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.summaryLabel.copyWith(color: color),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.topbarTitle,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.right,
              decoration: _searchDecoration(),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _openGroupEditor(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('إضافة مجموعة إضافات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);

    return ControlPanelShell(
      section: ControlPanelSection.settingsAddons,
      child: StreamBuilder<List<AddonGroupDb>>(
        stream: db.watchAddonGroups(),
        builder: (context, groupsSnap) {
          return StreamBuilder<List<AddonItemDb>>(
            stream: db.watchAddonItems(),
            builder: (context, itemsSnap) {
              return StreamBuilder<List<ProductAddonLinkDb>>(
                stream: db.watchProductAddonLinks(),
                builder: (context, linksSnap) {
                  return StreamBuilder<List<ProductDb>>(
                    stream: db.watchProducts(),
                    builder: (context, productsSnap) {
                      final groups = groupsSnap.data ?? const <AddonGroupDb>[];
                      final items = itemsSnap.data ?? const <AddonItemDb>[];
                      final links =
                          linksSnap.data ?? const <ProductAddonLinkDb>[];
                      final products = productsSnap.data ?? const <ProductDb>[];

                      final itemsByGroup = <int, List<AddonItemDb>>{};
                      for (final item in items) {
                        itemsByGroup
                            .putIfAbsent(item.groupId, () => [])
                            .add(item);
                      }
                      final linkedProductIdsByGroup = <int, Set<int>>{};
                      for (final link in links) {
                        linkedProductIdsByGroup
                            .putIfAbsent(link.groupId, () => <int>{})
                            .add(link.productId);
                      }
                      final productsById = {
                        for (final product in products.where(
                          (p) => !p.isDeleted,
                        ))
                          product.id: product,
                      };

                      final filteredGroups = groups.where((group) {
                        if (_search.isEmpty) return true;
                        final itemText =
                            (itemsByGroup[group.id] ?? const <AddonItemDb>[])
                                .map((item) => item.name)
                                .join(' ')
                                .toLowerCase();
                        final productText =
                            (linkedProductIdsByGroup[group.id] ?? const <int>{})
                                .map((id) => productsById[id]?.name ?? '')
                                .join(' ')
                                .toLowerCase();
                        final haystack = '${group.name} $itemText $productText'
                            .toLowerCase();
                        return haystack.contains(_search);
                      }).toList();

                      final totalItems = items.length;
                      final totalLinks = links.length;
                      final activeGroups = groups
                          .where((group) => group.isActive)
                          .length;

                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _buildHero(),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: [
                              _buildMetricCard(
                                title: 'مجموعات الإضافات',
                                value: '${groups.length}',
                                icon: Icons.layers_outlined,
                                color: AppColors.primaryBlue,
                              ),
                              _buildMetricCard(
                                title: 'الإضافات المعرفة',
                                value: '$totalItems',
                                icon: Icons.playlist_add_check_circle_outlined,
                                color: AppColors.successGreen,
                              ),
                              _buildMetricCard(
                                title: 'المنتجات المرتبطة',
                                value: '$totalLinks',
                                icon: Icons.inventory_2_outlined,
                                color: AppColors.warningPurple,
                              ),
                              _buildMetricCard(
                                title: 'المجموعات النشطة',
                                value: '$activeGroups',
                                icon: Icons.verified_outlined,
                                color: AppColors.topbarIconDeepBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildActionBar(),
                          const SizedBox(height: AppSpacing.lg),
                          _GroupsTableCard(
                            groups: filteredGroups,
                            itemsByGroup: itemsByGroup,
                            linkedProductIdsByGroup: linkedProductIdsByGroup,
                            productsById: productsById,
                            onEdit: (group) => _openGroupEditor(
                              group: group,
                              initialItems:
                                  itemsByGroup[group.id] ??
                                  const <AddonItemDb>[],
                            ),
                            onManageProducts: (group) => _openProductsDialog(
                              group: group,
                              allProducts: products,
                              selectedIds:
                                  linkedProductIdsByGroup[group.id] ?? <int>{},
                            ),
                            onDelete: _deleteGroup,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupsTableCard extends StatelessWidget {
  const _GroupsTableCard({
    required this.groups,
    required this.itemsByGroup,
    required this.linkedProductIdsByGroup,
    required this.productsById,
    required this.onEdit,
    required this.onManageProducts,
    required this.onDelete,
  });

  final List<AddonGroupDb> groups;
  final Map<int, List<AddonItemDb>> itemsByGroup;
  final Map<int, Set<int>> linkedProductIdsByGroup;
  final Map<int, ProductDb> productsById;
  final ValueChanged<AddonGroupDb> onEdit;
  final ValueChanged<AddonGroupDb> onManageProducts;
  final ValueChanged<AddonGroupDb> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutralGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'مجموعات إضافات المنتجات',
                    style: AppTextStyles.topbarTitle,
                    textAlign: TextAlign.right,
                  ),
                ),
                _CountBadge(value: groups.length),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.controlPanelHeaderBlue,
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'مجموعة الإضافات',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 4,
                  child: Text(
                    'الإضافات',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 4,
                  child: Text(
                    'منتجات مفعلة',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 3,
                  child: Text(
                    'خيارات',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'لا توجد مجموعات إضافات حتى الآن',
                style: AppTextStyles.fieldHint,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final group in groups)
              _GroupRow(
                group: group,
                items: itemsByGroup[group.id] ?? const <AddonItemDb>[],
                linkedProductNames:
                    (linkedProductIdsByGroup[group.id] ?? const <int>{})
                        .map((id) => productsById[id]?.name ?? 'منتج #$id')
                        .toList(),
                onEdit: () => onEdit(group),
                onManageProducts: () => onManageProducts(group),
                onDelete: () => onDelete(group),
              ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.items,
    required this.linkedProductNames,
    required this.onEdit,
    required this.onManageProducts,
    required this.onDelete,
  });

  final AddonGroupDb group;
  final List<AddonItemDb> items;
  final List<String> linkedProductNames;
  final VoidCallback onEdit;
  final VoidCallback onManageProducts;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final additionLabels = [
      for (final item in items)
        item.price > 0
            ? '${item.name} (${item.price.toStringAsFixed(2)} ريال)'
            : item.name,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.neutralGrey.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  group.name,
                  style: AppTextStyles.fieldText.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 6),
                _StatusPill(active: group.isActive),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: additionLabels.isEmpty
                  ? const [_MutedCaption(text: 'لا توجد إضافات داخل المجموعة')]
                  : [
                      for (final label in additionLabels)
                        _InfoChip(text: label, color: AppColors.primaryBlue),
                    ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: linkedProductNames.isEmpty
                  ? const [_MutedCaption(text: 'لا توجد منتجات مربوطة')]
                  : [
                      for (final name in linkedProductNames)
                        _InfoChip(text: name, color: AppColors.successGreen),
                    ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _ActionMiniButton(
                  label: 'تعديل',
                  icon: Icons.edit_outlined,
                  color: AppColors.primaryBlue,
                  onTap: onEdit,
                ),
                _ActionMiniButton(
                  label: 'إدارة المنتجات',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.successGreen,
                  onTap: onManageProducts,
                ),
                _ActionMiniButton(
                  label: 'حذف',
                  icon: Icons.delete_outline,
                  color: AppColors.dangerRed,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonGroupEditorDialog extends StatefulWidget {
  const _AddonGroupEditorDialog({
    this.initialName,
    this.initialActive = true,
    this.initialItems = const <_AddonItemDraft>[],
  });

  final String? initialName;
  final bool initialActive;
  final List<_AddonItemDraft> initialItems;

  @override
  State<_AddonGroupEditorDialog> createState() =>
      _AddonGroupEditorDialogState();
}

class _AddonGroupEditorDialogState extends State<_AddonGroupEditorDialog> {
  late final TextEditingController _nameController;
  late bool _isActive;
  late final List<_AddonLineControllers> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _isActive = widget.initialActive;
    _rows = widget.initialItems.isEmpty
        ? [_AddonLineControllers()]
        : widget.initialItems
              .map(
                (item) => _AddonLineControllers(
                  name: item.name,
                  price: item.price == 0 ? '' : item.price.toStringAsFixed(2),
                ),
              )
              .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.fieldHint,
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }

  void _addRow() {
    setState(() => _rows.add(_AddonLineControllers()));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    final target = _rows.removeAt(index);
    target.dispose();
    setState(() {});
  }

  void _submit() {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppFeedback.error(context, 'اسم مجموعة الإضافات مطلوب');
      return;
    }
    final items = <_AddonItemDraft>[];
    for (final row in _rows) {
      final itemName = row.nameController.text.trim();
      final rawPrice = row.priceController.text.trim();
      if (itemName.isEmpty && rawPrice.isEmpty) continue;
      if (itemName.isEmpty) {
        AppFeedback.error(context, 'اسم الإضافة مطلوب في كل سطر مستخدم');
        return;
      }
      final price = double.tryParse(rawPrice.isEmpty ? '0' : rawPrice);
      if (price == null || price < 0) {
        AppFeedback.error(context, 'سعر الإضافة غير صحيح');
        return;
      }
      items.add(_AddonItemDraft(name: itemName, price: price));
    }
    if (items.isEmpty) {
      AppFeedback.error(context, 'أدخل إضافة واحدة على الأقل');
      return;
    }

    setState(() => _saving = true);
    Navigator.of(
      context,
    ).pop(_AddonGroupPayload(name: name, isActive: _isActive, items: items));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      widget.initialName == null
                          ? 'إضافة مجموعة إضافات'
                          : 'تعديل مجموعة الإضافات',
                      style: AppTextStyles.topbarTitle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      decoration: _fieldDecoration('اسم مجموعة الإضافات'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('نشطة', style: AppTextStyles.fieldText),
                        Switch.adaptive(
                          value: _isActive,
                          activeThumbColor: AppColors.successGreen,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'الإضافات',
                style: AppTextStyles.topbarTitle,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.controlPanelHeaderBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 42),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'السعر',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الإضافة',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < _rows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => i == 0 ? _addRow() : _removeRow(i),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? AppColors.primaryBlue
                                        : AppColors.dangerRed,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    i == 0 ? Icons.add : Icons.remove,
                                    color: AppColors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: _rows[i].priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.center,
                                  decoration: _fieldDecoration('السعر'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _rows[i].nameController,
                                  textAlign: TextAlign.right,
                                  decoration: _fieldDecoration('اسم الإضافة'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
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

class _AddonProductsDialog extends StatefulWidget {
  const _AddonProductsDialog({
    required this.groupName,
    required this.products,
    required this.selectedIds,
  });

  final String groupName;
  final List<ProductDb> products;
  final Set<int> selectedIds;

  @override
  State<_AddonProductsDialog> createState() => _AddonProductsDialogState();
}

class _AddonProductsDialogState extends State<_AddonProductsDialog> {
  final _searchController = TextEditingController();
  late final Set<int> _selectedIds = {...widget.selectedIds};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _search => _searchController.text.trim().toLowerCase();

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      hintText: 'أدخل اسم المنتج أو الباركود أو مسح الباركود',
      hintStyle: AppTextStyles.fieldHint,
      prefixIcon: const Icon(Icons.search, size: 18),
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products
        .where((product) => !product.isDeleted)
        .where((product) {
          if (_search.isEmpty) return true;
          final haystack =
              '${product.name} ${product.id} ${product.serverId ?? ''}'
                  .toLowerCase();
          return haystack.contains(_search);
        })
        .toList();

    final selectedProducts = widget.products
        .where(
          (product) => _selectedIds.contains(product.id) && !product.isDeleted,
        )
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: RichText(
                      textAlign: TextAlign.right,
                      text: TextSpan(
                        style: AppTextStyles.topbarTitle,
                        children: [
                          const TextSpan(text: 'منتجات للإضافات: '),
                          TextSpan(
                            text: widget.groupName,
                            style: const TextStyle(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.right,
                decoration: _fieldDecoration(),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.controlPanelHeaderBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'المنتجات المختارة',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: selectedProducts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(
                          'لم يتم ربط أي منتج بعد',
                          style: AppTextStyles.fieldHint,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          for (final product in selectedProducts)
                            InputChip(
                              label: Text(product.name),
                              selected: true,
                              onDeleted: () => setState(() {
                                _selectedIds.remove(product.id);
                              }),
                              deleteIconColor: AppColors.white,
                              backgroundColor: AppColors.successGreen,
                              selectedColor: AppColors.successGreen,
                              labelStyle: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.controlPanelHeaderBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'المنتجات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.neutralGrey),
                  ),
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final selected = _selectedIds.contains(product.id);
                      return ListTile(
                        dense: true,
                        leading: IconButton(
                          onPressed: () => setState(() {
                            if (selected) {
                              _selectedIds.remove(product.id);
                            } else {
                              _selectedIds.add(product.id);
                            }
                          }),
                          icon: Icon(
                            selected
                                ? Icons.cancel_rounded
                                : Icons.add_circle_rounded,
                            color: selected
                                ? AppColors.dangerRed
                                : AppColors.primaryBlue,
                          ),
                          tooltip: selected ? 'إزالة المنتج' : 'إضافة المنتج',
                        ),
                        title: Text(
                          product.name,
                          style: AppTextStyles.fieldText,
                          textAlign: TextAlign.right,
                        ),
                        subtitle: Text(
                          '(${product.serverId ?? product.id})',
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedIds),
                    child: const Text('حفظ'),
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

class _ActionMiniButton extends StatelessWidget {
  const _ActionMiniButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.successGreen : AppColors.warningPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'نشطة' : 'موقوفة',
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MutedCaption extends StatelessWidget {
  const _MutedCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.fieldHint,
      textAlign: TextAlign.right,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '$value',
        style: AppTextStyles.summaryLabel.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddonItemDraft {
  const _AddonItemDraft({required this.name, required this.price});

  final String name;
  final double price;
}

class _AddonGroupPayload {
  const _AddonGroupPayload({
    required this.name,
    required this.isActive,
    required this.items,
  });

  final String name;
  final bool isActive;
  final List<_AddonItemDraft> items;
}

class _AddonLineControllers {
  _AddonLineControllers({String name = '', String price = ''})
    : nameController = TextEditingController(text: name),
      priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController priceController;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}
