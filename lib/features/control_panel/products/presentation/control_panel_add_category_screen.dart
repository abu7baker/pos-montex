import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../pos/presentation/widgets/pos_select.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelAddCategoryScreen extends ConsumerStatefulWidget {
  const ControlPanelAddCategoryScreen({super.key});

  @override
  ConsumerState<ControlPanelAddCategoryScreen> createState() =>
      _ControlPanelAddCategoryScreenState();
}

class _ControlPanelAddCategoryScreenState
    extends ConsumerState<ControlPanelAddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  String? _stationCode;
  int? _editingCategoryId;
  bool _saving = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.fieldText,
      hintText: hint,
      hintStyle: AppTextStyles.fieldHint,
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: AppColors.textSecondary),
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

  Future<void> _saveCategory() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_stationCode == null || _stationCode!.trim().isEmpty) {
      AppFeedback.warning(context, 'محطة الطباعة مطلوبة');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final isEditing = _editingCategoryId != null;
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final stationCode = _stationCode?.trim();

      await db.upsertProductCategory(
        ProductCategoriesCompanion.insert(
          id: isEditing
              ? drift.Value(_editingCategoryId!)
              : const drift.Value.absent(),
          name: name,
          description: drift.Value(description.isEmpty ? null : description),
          stationCode: drift.Value(
            stationCode == null || stationCode.isEmpty ? null : stationCode,
          ),
          updatedAtLocal: drift.Value(DateTime.now()),
        ),
      );

      if (!mounted) return;
      AppFeedback.success(
        context,
        isEditing ? 'تم تحديث القسم بنجاح' : 'تم حفظ القسم بنجاح',
      );
      _resetForm();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCategory(ProductCategoryDb category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text('هل تريد حذف القسم "${category.name}"؟'),
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

    final db = ref.read(appDbProvider);
    await (db.update(
      db.productCategories,
    )..where((t) => t.id.equals(category.id))).write(
      ProductCategoriesCompanion(
        isDeleted: const drift.Value(true),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    if (_editingCategoryId == category.id) {
      _resetForm();
    }
    AppFeedback.success(context, 'تم حذف القسم');
  }

  void _startEditCategory(ProductCategoryDb category) {
    _nameController.text = category.name;
    _descriptionController.text = category.description ?? '';
    setState(() {
      _stationCode = category.stationCode;
      _editingCategoryId = category.id;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _stationCode = null;
      _editingCategoryId = null;
    });
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.topbarIconDeepBlue],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إدارة الأقسام',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أضف الأقسام وعدلها واحذفها مع ربط محطة الطباعة',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(List<PrintStationDb> stations) {
    final stationValue = stations.any((s) => s.code == _stationCode)
        ? _stationCode
        : null;
    final stationOptions = stations
        .map(
          (s) => PosSelectOption<String>(
            value: s.code,
            label: '${s.name} (${s.code})',
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.edit_note, size: 18, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text('بيانات القسم', style: AppTextStyles.topbarTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: _fieldDecoration(
                'اسم القسم',
                icon: Icons.bookmark_border,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'الاسم مطلوب'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              minLines: 3,
              maxLines: 5,
              decoration: _fieldDecoration(
                'وصف القسم',
                hint: 'اختياري: اكتب وصفًا مختصرًا',
                icon: Icons.notes_outlined,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            PosSelectField<String>(
              label: 'محطة الطباعة',
              hintText: 'اختر محطة الطباعة',
              options: stationOptions,
              value: stationValue,
              onChanged: (value) => setState(() => _stationCode = value),
              leadingIcon: Icons.print_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save, size: 18, color: AppColors.white),
                label: Text(
                  _saving
                      ? 'جاري الحفظ...'
                      : (_editingCategoryId == null
                            ? 'حفظ القسم'
                            : 'تحديث القسم'),
                  style: AppTextStyles.buttonTextStyle,
                ),
              ),
            ),
            if (_editingCategoryId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _resetForm,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.fieldBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.restart_alt,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    'إلغاء التعديل',
                    style: AppTextStyles.buttonTextDark.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(String? stationLabel) {
    final name = _nameController.text.trim().isEmpty
        ? 'اسم القسم'
        : _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? 'وصف القسم'
        : _descriptionController.text.trim();
    final station = (stationLabel == null || stationLabel.trim().isEmpty)
        ? 'بدون محطة'
        : stationLabel.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(
                Icons.preview_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.xs),
              Text('معاينة القسم', style: AppTextStyles.topbarTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.selectHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.topbarTitle),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTextStyles.topbarInfo,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.selectHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.print_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    station,
                    style: AppTextStyles.topbarInfo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesCard({
    required List<ProductCategoryDb> categories,
    required List<ProductDb> products,
    required List<PrintStationDb> stations,
  }) {
    final stationByCode = {
      for (final station in stations) station.code: station.name,
    };
    final productCountByCategory = <int, int>{};
    for (final product in products.where((p) => !p.isDeleted)) {
      final categoryId = product.categoryId;
      if (categoryId == null) continue;
      productCountByCategory[categoryId] =
          (productCountByCategory[categoryId] ?? 0) + 1;
    }

    final normalized = categories.toList()
      ..sort((a, b) => b.updatedAtLocal.compareTo(a.updatedAtLocal));
    final rows = normalized.where((category) {
      if (_searchQuery.isEmpty) return true;
      final station = (stationByCode[category.stationCode ?? ''] ?? '')
          .toLowerCase();
      final description = (category.description ?? '').toLowerCase();
      return category.name.toLowerCase().contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          station.contains(_searchQuery) ||
          category.id.toString().contains(_searchQuery);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.view_list_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'الأقسام الحالية',
                      style: AppTextStyles.topbarTitle,
                    ),
                  ),
                  _CountPill(value: rows.length.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _searchController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  'بحث باسم القسم أو المحطة',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (rows.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.selectHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: const Text(
                    'لا توجد أقسام مطابقة',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.fieldHint,
                  ),
                )
              else if (isWide)
                _buildWideCategoriesTable(
                  rows: rows,
                  stationByCode: stationByCode,
                  productCountByCategory: productCountByCategory,
                )
              else
                _buildCompactCategoriesList(
                  rows: rows,
                  stationByCode: stationByCode,
                  productCountByCategory: productCountByCategory,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideCategoriesTable({
    required List<ProductCategoryDb> rows,
    required Map<String, String> stationByCode,
    required Map<int, int> productCountByCategory,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutralGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.neutralGrey)),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text('القسم', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 3,
                  child: Text('الوصف', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('محطة الطباعة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('المنتجات', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('الإجراءات', style: AppTextStyles.topbarTitle),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.neutralGrey),
              itemBuilder: (context, index) {
                final category = rows[index];
                final stationCode = (category.stationCode ?? '').trim();
                final stationLabel = stationCode.isEmpty
                    ? '-'
                    : ((stationByCode[stationCode] ?? stationCode));
                final productsCount = productCountByCategory[category.id] ?? 0;
                final isEditing = _editingCategoryId == category.id;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 9,
                  ),
                  color: isEditing
                      ? AppColors.selectSelected.withOpacity(0.5)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          category.name,
                          style: AppTextStyles.fieldText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          category.description ?? '-',
                          style: AppTextStyles.topbarInfo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          stationLabel,
                          style: AppTextStyles.topbarInfo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          productsCount.toString(),
                          style: AppTextStyles.fieldText,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _startEditCategory(category),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                                minimumSize: const Size(88, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              label: Text(
                                'تعديل',
                                style: AppTextStyles.fieldText.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            OutlinedButton.icon(
                              onPressed: () => _deleteCategory(category),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.dangerRed,
                                ),
                                minimumSize: const Size(82, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.dangerRed,
                              ),
                              label: Text(
                                'حذف',
                                style: AppTextStyles.fieldText.copyWith(
                                  color: AppColors.dangerRed,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCategoriesList({
    required List<ProductCategoryDb> rows,
    required Map<String, String> stationByCode,
    required Map<int, int> productCountByCategory,
  }) {
    return SizedBox(
      height: 420,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.neutralGrey),
        itemBuilder: (context, index) {
          final category = rows[index];
          final stationCode = (category.stationCode ?? '').trim();
          final stationLabel = stationCode.isEmpty
              ? '-'
              : (stationByCode[stationCode] ?? stationCode);
          final productsCount = productCountByCategory[category.id] ?? 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.selectHover,
              child: Text(
                productsCount.toString(),
                style: AppTextStyles.fieldText.copyWith(fontSize: 11),
              ),
            ),
            title: Text(category.name, style: AppTextStyles.fieldText),
            subtitle: Text(
              'المحطة: $stationLabel',
              style: AppTextStyles.topbarInfo,
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => _startEditCategory(category),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => _deleteCategory(category),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.dangerRed,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);

    return ControlPanelShell(
      section: ControlPanelSection.productsCategoryAdd,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<PrintStationDb>>(
            stream: db.watchPrintStations(),
            builder: (context, stationSnapshot) {
              final stations = stationSnapshot.data ?? const <PrintStationDb>[];
              String? stationLabel;
              if (_stationCode != null) {
                final match = stations
                    .where((s) => s.code == _stationCode)
                    .toList();
                if (match.isNotEmpty) {
                  stationLabel = '${match.first.name} (${match.first.code})';
                }
              }

              return StreamBuilder<List<ProductCategoryDb>>(
                stream: db.watchProductCategories(),
                builder: (context, categorySnapshot) {
                  final categories =
                      categorySnapshot.data ?? const <ProductCategoryDb>[];
                  return StreamBuilder<List<ProductDb>>(
                    stream: db.watchProducts(),
                    builder: (context, productSnapshot) {
                      final products =
                          productSnapshot.data ?? const <ProductDb>[];

                      return Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 980;
                              final formCard = _buildFormCard(stations);
                              final previewCard = _buildPreviewCard(
                                stationLabel,
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: formCard),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(flex: 2, child: previewCard),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  formCard,
                                  const SizedBox(height: AppSpacing.lg),
                                  previewCard,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildCategoriesCard(
                            categories: categories,
                            products: products,
                            stations: stations,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          const Text('العدد', style: AppTextStyles.topbarInfo),
          const SizedBox(width: AppSpacing.xs),
          Text(value, style: AppTextStyles.topbarTitle),
        ],
      ),
    );
  }
}
