import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../pos/presentation/widgets/pos_select.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelAddProductScreen extends ConsumerStatefulWidget {
  const ControlPanelAddProductScreen({super.key});

  @override
  ConsumerState<ControlPanelAddProductScreen> createState() =>
      _ControlPanelAddProductScreenState();
}

enum _ProductsSubSection { productsList, productForm, categories }

enum _ProductsStockFilter { all, inStock, lowStock, outOfStock }

class _ControlPanelAddProductScreenState
    extends ConsumerState<ControlPanelAddProductScreen> {
  static const int _noBrandId = -1;

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _imageController = TextEditingController();
  final _searchController = TextEditingController();

  int? _categoryId;
  int? _brandId;
  int? _editingProductId;
  int? _productsCategoryFilterId;
  int? _productsBrandFilterId;
  _ProductsSubSection _activeSection = _ProductsSubSection.productsList;
  _ProductsStockFilter _productsStockFilter = _ProductsStockFilter.all;
  bool _saving = false;
  bool _pickingImage = false;
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageController.dispose();
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

  Future<String?> _copyImageToAppDir(PlatformFile file, Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(
      p.join(dir.path, 'montex_pos_images', 'products'),
    );
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }

    final ext = p.extension(file.name).isEmpty
        ? '.png'
        : p.extension(file.name);
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(imagesDir.path, fileName);
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) return;

      final storedPath = await _copyImageToAppDir(file, bytes);
      setState(() {
        _imageBytes = bytes;
        _imageController.text = storedPath ?? file.path ?? '';
      });
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _saveProduct() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_categoryId == null) {
      AppFeedback.warning(context, 'اختر القسم أولاً');
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;
      final imagePath = _imageController.text.trim();
      final isEditing = _editingProductId != null;
      final id = isEditing ? _editingProductId! : await db.getNextProductId();

      Uint8List? bytes = _imageBytes;
      if ((bytes == null || bytes.isEmpty) && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          bytes = await file.readAsBytes();
        }
      }

      await db.upsertProducts([
        ProductsCompanion.insert(
          id: drift.Value(id),
          name: name,
          description: drift.Value(description.isEmpty ? null : description),
          price: drift.Value(price),
          stock: drift.Value(stock),
          categoryId: drift.Value(_categoryId),
          brandId: drift.Value(_brandId),
          imagePath: drift.Value(imagePath.isEmpty ? null : imagePath),
          imageData: drift.Value(bytes),
          updatedAt: drift.Value(DateTime.now()),
        ),
      ]);

      if (!mounted) return;
      AppFeedback.success(
        context,
        isEditing ? 'تم تحديث المنتج بنجاح' : 'تم حفظ المنتج بنجاح',
      );
      _resetForm();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _stockController.text = '0';
    _imageController.clear();
    setState(() {
      _categoryId = null;
      _brandId = null;
      _imageBytes = null;
      _editingProductId = null;
    });
  }

  void _startEditProduct(ProductDb product) {
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _stockController.text = product.stock.toString();
    _imageController.text = product.imagePath ?? '';
    setState(() {
      _categoryId = product.categoryId;
      _brandId = product.brandId;
      _imageBytes = product.imageData;
      _editingProductId = product.id;
      _activeSection = _ProductsSubSection.productForm;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _deleteProduct(ProductDb product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف المنتج "${product.name}"؟'),
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
    await (db.update(db.products)..where((t) => t.id.equals(product.id))).write(
      ProductsCompanion(
        isDeleted: const drift.Value(true),
        isActive: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    if (_editingProductId == product.id) {
      _resetForm();
    }
    AppFeedback.success(context, 'تم حذف المنتج');
  }

  List<ProductDb> _filterProducts(List<ProductDb> products) {
    final filtered = products.where((product) => !product.isDeleted).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return filtered;
  }

  Widget _buildImagePreview() {
    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          _imageBytes!,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
 
    final path = _imageController.text.trim();
    if (path.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/logo.jpg',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
        ),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/logo.jpg',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(file, width: 160, height: 160, fit: BoxFit.cover),
    );
  }

  String _sectionLabel(_ProductsSubSection section) {
    switch (section) {
      case _ProductsSubSection.productsList:
        return 'قائمة المنتجات';
      case _ProductsSubSection.productForm:
        return _editingProductId == null ? 'إضافة منتج' : 'تعديل المنتج';
      case _ProductsSubSection.categories:
        return 'الأقسام';
    }
  }

  IconData _sectionIcon(_ProductsSubSection section) {
    switch (section) {
      case _ProductsSubSection.productsList:
        return Icons.view_list_rounded;
      case _ProductsSubSection.productForm:
        return Icons.add_box_outlined;
      case _ProductsSubSection.categories:
        return Icons.category_outlined;
    }
  }

  Widget _buildSectionTabs() {
    const sections = [
      _ProductsSubSection.productsList,
      _ProductsSubSection.productForm,
      _ProductsSubSection.categories,
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final content = sections.map((section) {
            final selected = _activeSection == section;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _activeSection = section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _sectionIcon(section),
                      size: 18,
                      color: selected
                          ? AppColors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _sectionLabel(section),
                      style: AppTextStyles.fieldText.copyWith(
                        color: selected
                            ? AppColors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          if (isWide) {
            return Row(
              children: [
                for (var i = 0; i < content.length; i++) ...[
                  Expanded(child: content[i]),
                  if (i != content.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var i = 0; i < content.length; i++) ...[
                SizedBox(width: double.infinity, child: content[i]),
                if (i != content.length - 1)
                  const SizedBox(height: AppSpacing.xs),
              ],
            ],
          );
        },
      ),
    );
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
              Icons.inventory_2_outlined,
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
                  'إدارة المنتجات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تنظيم  لقائمة المنتجات مع إضافة المنتجات وإدارة الأقسام',
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

  Widget _buildPreviewCard({
    required String? categoryName,
    required String? brandName,
  }) {
    final name = _nameController.text.trim().isEmpty
        ? 'اسم المنتج'
        : _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final category = (categoryName == null || categoryName.trim().isEmpty)
        ? 'بدون قسم'
        : categoryName.trim();
    final brand = (brandName == null || brandName.trim().isEmpty)
        ? 'بدون علامة تجارية'
        : brandName.trim();

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
              Text('معاينة المنتج', style: AppTextStyles.topbarTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: _buildImagePreview()),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            style: AppTextStyles.topbarTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PreviewPill(label: 'السعر', value: price.toStringAsFixed(2)),
              const SizedBox(width: AppSpacing.sm),
              _PreviewPill(label: 'المخزون', value: stock.toString()),
            ],
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
                  Icons.branding_watermark_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    brand,
                    style: AppTextStyles.topbarInfo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.fieldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Text(
                description,
                style: AppTextStyles.fieldText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
                  Icons.category_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    category,
                    style: AppTextStyles.topbarInfo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildFormCard(
    List<ProductCategoryDb> categories,
    List<BrandDb> brands,
  ) {
    final currentValue = categories.any((element) => element.id == _categoryId)
        ? _categoryId
        : null;
    final categoryOptions = categories
        .map((c) => PosSelectOption<int>(value: c.id, label: c.name))
        .toList();
    final brandOptions = <PosSelectOption<int>>[
      const PosSelectOption<int>(value: _noBrandId, label: 'بدون علامة تجارية'),
      ...brands.map((b) => PosSelectOption<int>(value: b.id, label: b.name)),
    ];
    final currentBrandValue = _brandId == null
        ? _noBrandId
        : (brandOptions.any((option) => option.value == _brandId)
              ? _brandId!
              : _noBrandId);

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
                Text('بيانات المنتج', style: AppTextStyles.topbarTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'اسم المنتج',
                      icon: Icons.sell_outlined,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'الاسم مطلوب'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'السعر',
                      icon: Icons.payments_outlined,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'السعر مطلوب';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null) return 'قيمة غير صحيحة';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: _fieldDecoration(
                'الوصف (اختياري)',
                hint: 'وصف مختصر للمنتج',
                icon: Icons.notes_outlined,
              ),
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: PosSelectField<int>(
                    label: 'القسم',
                    hintText: 'اختر قسم',
                    options: categoryOptions,
                    value: currentValue,
                    onChanged: (value) => setState(() => _categoryId = value),
                    leadingIcon: Icons.category_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'المخزون',
                      icon: Icons.inventory_2_outlined,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            PosSelectField<int>(
              label: 'العلامة التجارية (اختياري)',
              hintText: 'اختر علامة تجارية',
              options: brandOptions,
              value: currentBrandValue,
              onChanged: (value) => setState(
                () => _brandId = (value == null || value == _noBrandId)
                    ? null
                    : value,
              ),
              leadingIcon: Icons.branding_watermark_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _imageController,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'صورة المنتج (اختياري)',
                      hint: 'يمكن ترك الصورة فارغة',
                      icon: Icons.image_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _pickingImage ? null : _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.upload_file,
                      size: 18,
                      color: AppColors.white,
                    ),
                    label: Text(
                      _pickingImage ? 'جاري التحميل...' : 'رفع الصورة',
                      style: AppTextStyles.buttonTextStyle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(
                        Icons.save,
                        size: 18,
                        color: AppColors.white,
                      ),
                      label: Text(
                        _saving
                            ? 'جاري الحفظ...'
                            : (_editingProductId == null
                                  ? 'حفظ المنتج'
                                  : 'تحديث المنتج'),
                        style: AppTextStyles.buttonTextStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.controlPanelAddCategory,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                      label: Text(
                        'إضافة قسم جديد',
                        style: AppTextStyles.buttonTextStyle.copyWith(
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_editingProductId != null) ...[
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

  Widget _buildProductImageThumb(ProductDb product) {
    final bytes = product.imageData;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    final path = (product.imagePath ?? '').trim();
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 38, height: 38, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildProductsWideTable({
    required List<ProductDb> rows,
    required Map<int, String> categoryById,
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
                  flex: 3,
                  child: Text('المنتج', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('القسم', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('السعر', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('المخزون', style: AppTextStyles.topbarTitle),
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
                final product = rows[index];
                final categoryName = product.categoryId == null
                    ? 'بدون قسم'
                    : (categoryById[product.categoryId!] ?? 'بدون قسم');
                final isEditing = _editingProductId == product.id;

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
                        flex: 3,
                        child: Row(
                          children: [
                            _buildProductImageThumb(product),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                product.name,
                                style: AppTextStyles.fieldText,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          categoryName,
                          style: AppTextStyles.topbarInfo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          product.price.toStringAsFixed(2),
                          style: AppTextStyles.fieldText,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          product.stock.toString(),
                          style: AppTextStyles.fieldText,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _startEditProduct(product),
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
                              onPressed: () => _deleteProduct(product),
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

  Widget _buildProductsCompactList({
    required List<ProductDb> rows,
    required Map<int, String> categoryById,
  }) {
    return SizedBox(
      height: 420,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.neutralGrey),
        itemBuilder: (context, index) {
          final product = rows[index];
          final categoryName = product.categoryId == null
              ? 'بدون قسم'
              : (categoryById[product.categoryId!] ?? 'بدون قسم');

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            leading: _buildProductImageThumb(product),
            title: Text(product.name, style: AppTextStyles.fieldText),
            subtitle: Text(
              'القسم: $categoryName • السعر: ${product.price.toStringAsFixed(2)} • المخزون: ${product.stock}',
              style: AppTextStyles.topbarInfo,
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => _startEditProduct(product),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => _deleteProduct(product),
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

  bool _matchesStockFilter(ProductDb product) {
    switch (_productsStockFilter) {
      case _ProductsStockFilter.all:
        return true;
      case _ProductsStockFilter.inStock:
        return product.stock > 0;
      case _ProductsStockFilter.lowStock:
        return product.stock > 0 && product.stock <= 5;
      case _ProductsStockFilter.outOfStock:
        return product.stock <= 0;
    }
  }

  Widget _buildProductsMetric({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.topbarInfo.copyWith(color: color)),
          const SizedBox(width: AppSpacing.xs),
          Text(value, style: AppTextStyles.topbarTitle.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildProductsCard({
    required List<ProductDb> products,
    required List<ProductCategoryDb> categories,
    required List<BrandDb> brands,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category.name,
    };
    final brandById = {for (final brand in brands) brand.id: brand.name};
    final baseRows = _filterProducts(products);
    final rows = baseRows.where((product) {
      if (_productsCategoryFilterId != null &&
          product.categoryId != _productsCategoryFilterId) {
        return false;
      }
      if (_productsBrandFilterId != null &&
          product.brandId != _productsBrandFilterId) {
        return false;
      }
      if (!_matchesStockFilter(product)) {
        return false;
      }

      final categoryName = product.categoryId == null
          ? ''
          : (categoryById[product.categoryId!] ?? '');
      final brandName = product.brandId == null
          ? ''
          : (brandById[product.brandId!] ?? '');
      final description = (product.description ?? '').toLowerCase();
      if (_searchQuery.isEmpty) return true;
      return product.name.toLowerCase().contains(_searchQuery) ||
          product.id.toString().contains(_searchQuery) ||
          categoryName.toLowerCase().contains(_searchQuery) ||
          brandName.toLowerCase().contains(_searchQuery) ||
          description.contains(_searchQuery);
    }).toList();
    final outOfStockCount = baseRows.where((p) => p.stock <= 0).length;
    final lowStockCount = baseRows
        .where((p) => p.stock > 0 && p.stock <= 5)
        .length;

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
          final isWide = constraints.maxWidth >= 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'قائمة المنتجات',
                      style: AppTextStyles.topbarTitle,
                    ),
                  ),
                  _PreviewPill(label: 'العدد', value: rows.length.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _buildProductsMetric(
                    label: 'إجمالي المنتجات',
                    value: baseRows.length.toString(),
                    color: AppColors.primaryBlue,
                    icon: Icons.inventory_2_outlined,
                  ),
                  _buildProductsMetric(
                    label: 'منخفض المخزون',
                    value: lowStockCount.toString(),
                    color: AppColors.topbarIconOrange,
                    icon: Icons.inventory_outlined,
                  ),
                  _buildProductsMetric(
                    label: 'نفد المخزون',
                    value: outOfStockCount.toString(),
                    color: AppColors.dangerRed,
                    icon: Icons.report_gmailerrorred_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _searchController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  'بحث باسم المنتج أو القسم أو الرقم',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, filterConstraints) {
                  final compactFilters = filterConstraints.maxWidth < 880;
                  final categoryFilterOptions = <PosSelectOption<int>>[
                    const PosSelectOption<int>(value: 0, label: 'كل الأقسام'),
                    ...categories.map(
                      (category) => PosSelectOption<int>(
                        value: category.id,
                        label: category.name,
                      ),
                    ),
                  ];
                  final brandFilterOptions = <PosSelectOption<int>>[
                    const PosSelectOption<int>(value: 0, label: 'كل العلامات'),
                    ...brands.map(
                      (brand) => PosSelectOption<int>(
                        value: brand.id,
                        label: brand.name,
                      ),
                    ),
                  ];
                  const stockFilterOptions =
                      <PosSelectOption<_ProductsStockFilter>>[
                        PosSelectOption<_ProductsStockFilter>(
                          value: _ProductsStockFilter.all,
                          label: 'كل الحالات',
                        ),
                        PosSelectOption<_ProductsStockFilter>(
                          value: _ProductsStockFilter.inStock,
                          label: 'متوفر',
                        ),
                        PosSelectOption<_ProductsStockFilter>(
                          value: _ProductsStockFilter.lowStock,
                          label: 'مخزون منخفض',
                        ),
                        PosSelectOption<_ProductsStockFilter>(
                          value: _ProductsStockFilter.outOfStock,
                          label: 'نفد المخزون',
                        ),
                      ];
                  final controls = <Widget>[
                    SizedBox(
                      width: compactFilters ? double.infinity : 220,
                      child: PosSelectField<int>(
                        label: 'فلتر القسم',
                        hintText: 'اختر قسم',
                        options: categoryFilterOptions,
                        value: _productsCategoryFilterId ?? 0,
                        leadingIcon: Icons.category_outlined,
                        onChanged: (value) {
                          final next = value ?? 0;
                          setState(
                            () => _productsCategoryFilterId = next == 0
                                ? null
                                : next,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: compactFilters ? double.infinity : 220,
                      child: PosSelectField<int>(
                        label: 'فلتر العلامة التجارية',
                        hintText: 'اختر علامة',
                        options: brandFilterOptions,
                        value: _productsBrandFilterId ?? 0,
                        leadingIcon: Icons.branding_watermark_outlined,
                        onChanged: (value) {
                          final next = value ?? 0;
                          setState(
                            () => _productsBrandFilterId = next == 0
                                ? null
                                : next,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: compactFilters ? double.infinity : 220,
                      child: PosSelectField<_ProductsStockFilter>(
                        label: 'فلتر المخزون',
                        hintText: 'اختر الحالة',
                        options: stockFilterOptions,
                        value: _productsStockFilter,
                        leadingIcon: Icons.filter_alt_outlined,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _productsStockFilter = value);
                        },
                      ),
                    ),
                  ];

                  if (compactFilters) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...controls.expand(
                          (w) => [w, const SizedBox(height: 8)],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _productsCategoryFilterId = null;
                                _productsBrandFilterId = null;
                                _productsStockFilter = _ProductsStockFilter.all;
                              });
                            },
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('مسح الفلاتر'),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      ...controls
                          .expand(
                            (w) => [
                              Expanded(child: w),
                              const SizedBox(width: 8),
                            ],
                          )
                          .toList()
                        ..removeLast(),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _productsCategoryFilterId = null;
                              _productsBrandFilterId = null;
                              _productsStockFilter = _ProductsStockFilter.all;
                            });
                          },
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('مسح'),
                        ),
                      ),
                    ],
                  );
                },
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
                    'لا توجد منتجات مطابقة',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.fieldHint,
                  ),
                )
              else if (isWide)
                _buildProductsWideTable(rows: rows, categoryById: categoryById)
              else
                _buildProductsCompactList(
                  rows: rows,
                  categoryById: categoryById,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoriesSubSection({
    required List<ProductCategoryDb> categories,
    required List<ProductDb> products,
  }) {
    final activeCategories = categories.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final productCountByCategory = <int, int>{};
    for (final product in products.where((p) => !p.isDeleted)) {
      final id = product.categoryId;
      if (id == null) continue;
      productCountByCategory[id] = (productCountByCategory[id] ?? 0) + 1;
    }

    final emptyCategories = activeCategories
        .where((c) => (productCountByCategory[c.id] ?? 0) == 0)
        .length;

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
            children: [
              const Icon(
                Icons.category_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: Text('الأقسام', style: AppTextStyles.topbarTitle),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.controlPanelAddCategory,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text(
                    'فتح إدارة الأقسام',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildProductsMetric(
                label: 'عدد الأقسام',
                value: activeCategories.length.toString(),
                color: AppColors.primaryBlue,
                icon: Icons.category_outlined,
              ),
              _buildProductsMetric(
                label: 'أقسام بدون منتجات',
                value: emptyCategories.toString(),
                color: AppColors.topbarIconOrange,
                icon: Icons.rule_folder_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (activeCategories.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.selectHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: const Text(
                'لا توجد أقسام حالياً',
                textAlign: TextAlign.center,
                style: AppTextStyles.fieldHint,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.neutralGrey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 420,
                child: ListView.separated(
                  itemCount: activeCategories.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.neutralGrey),
                  itemBuilder: (context, index) {
                    final category = activeCategories[index];
                    final count = productCountByCategory[category.id] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.selectHover,
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.topbarInfo,
                        ),
                      ),
                      title: Text(
                        category.name,
                        style: AppTextStyles.fieldText,
                      ),
                      subtitle: Text(
                        count == 0 ? 'بدون منتجات' : '$count منتج',
                        style: AppTextStyles.topbarInfo,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: category.isActive
                              ? AppColors.successGreen.withOpacity(0.12)
                              : AppColors.dangerRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category.isActive ? 'نشط' : 'موقف',
                          style: AppTextStyles.topbarInfo.copyWith(
                            color: category.isActive
                                ? AppColors.successGreen
                                : AppColors.dangerRed,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(appDbProvider);

    return ControlPanelShell(
      section: ControlPanelSection.productsAdd,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTabs(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<ProductCategoryDb>>(
            stream: db.watchProductCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <ProductCategoryDb>[];
              String? categoryName;
              if (_categoryId != null) {
                final match = categories
                    .where((c) => c.id == _categoryId)
                    .toList();
                if (match.isNotEmpty) {
                  categoryName = match.first.name;
                }
              }
              return StreamBuilder<List<BrandDb>>(
                stream: db.watchBrands(activeOnly: true),
                builder: (context, brandSnapshot) {
                  final brands = brandSnapshot.data ?? const <BrandDb>[];
                  String? brandName;
                  if (_brandId != null) {
                    final match = brands
                        .where((b) => b.id == _brandId)
                        .toList();
                    if (match.isNotEmpty) {
                      brandName = match.first.name;
                    }
                  }

                  return StreamBuilder<List<ProductDb>>(
                    stream: db.watchProducts(),
                    builder: (context, productSnapshot) {
                      final allProducts =
                          productSnapshot.data ?? const <ProductDb>[];
                      switch (_activeSection) {
                        case _ProductsSubSection.productsList:
                          return _buildProductsCard(
                            products: allProducts,
                            categories: categories,
                            brands: brands,
                          );
                        case _ProductsSubSection.productForm:
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 980;
                              final formCard = _buildFormCard(
                                categories,
                                brands,
                              );
                              final previewCard = _buildPreviewCard(
                                categoryName: categoryName,
                                brandName: brandName,
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
                          );
                        case _ProductsSubSection.categories:
                          return _buildCategoriesSubSection(
                            categories: categories,
                            products: allProducts,
                          );
                      }
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

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label, required this.value});

  final String label;
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
          Text(label, style: AppTextStyles.topbarInfo),
          const SizedBox(width: AppSpacing.xs),
          Text(value, style: AppTextStyles.topbarTitle),
        ],
      ),
    );
  }
}
