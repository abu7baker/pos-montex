import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelBrandsScreen extends ConsumerStatefulWidget {
  const ControlPanelBrandsScreen({super.key});

  @override
  ConsumerState<ControlPanelBrandsScreen> createState() =>
      _ControlPanelBrandsScreenState();
}

class _ControlPanelBrandsScreenState
    extends ConsumerState<ControlPanelBrandsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePathController = TextEditingController();
  final _searchController = TextEditingController();

  Uint8List? _pickedBytes;
  bool _isActive = true;
  bool _saving = false;
  bool _pickingImage = false;
  int? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imagePathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _search => _searchController.text.trim().toLowerCase();

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
      p.join(dir.path, 'montex_pos_images', 'brands'),
    );
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }

    final ext = p.extension(file.name).isEmpty
        ? '.png'
        : p.extension(file.name);
    final fileName = 'brand_${DateTime.now().millisecondsSinceEpoch}$ext';
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
        _pickedBytes = bytes;
        _imagePathController.text = storedPath ?? file.path ?? '';
      });
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _imagePathController.clear();
    setState(() {
      _pickedBytes = null;
      _editingId = null;
      _isActive = true;
    });
  }

  void _startEdit(BrandDb row) {
    _nameController.text = row.name;
    _descriptionController.text = row.description ?? '';
    _imagePathController.text = row.imagePath ?? '';
    setState(() {
      _editingId = row.id;
      _isActive = row.isActive;
      _pickedBytes = null;
    });
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final imagePath = _imagePathController.text.trim();

      await db.upsertBrand(
        BrandsCompanion.insert(
          id: _editingId == null
              ? const drift.Value.absent()
              : drift.Value(_editingId!),
          name: name,
          description: drift.Value(description.isEmpty ? null : description),
          imagePath: drift.Value(imagePath.isEmpty ? null : imagePath),
          isActive: drift.Value(_isActive),
          isDeleted: const drift.Value(false),
          updatedAtLocal: drift.Value(DateTime.now()),
        ),
      );

      if (!mounted) return;
      AppFeedback.success(
        context,
        _editingId == null
            ? 'تم حفظ العلامة التجارية'
            : 'تم تحديث العلامة التجارية',
      );
      _resetForm();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ العلامة التجارية: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(BrandDb row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف العلامة التجارية'),
        content: Text('هل تريد حذف العلامة "${row.name}"؟'),
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

    await ref.read(appDbProvider).softDeleteBrand(row.id);
    if (!mounted) return;
    if (_editingId == row.id) _resetForm();
    AppFeedback.success(context, 'تم حذف العلامة التجارية');
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
              Icons.branding_watermark_outlined,
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
                  'إدارة العلامات التجارية',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إضافة وتحديث العلامات التجارية وربطها بالمنتجات في النظام',
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

  Widget _imagePreview() {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _pickedBytes!,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    final path = _imagePathController.text.trim();
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: 90, height: 90, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 26,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildFormCard() {
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
                Text('بيانات العلامة', style: AppTextStyles.topbarTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: _fieldDecoration(
                'اسم العلامة التجارية',
                icon: Icons.branding_watermark_outlined,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'الاسم مطلوب'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              minLines: 2,
              maxLines: 4,
              decoration: _fieldDecoration(
                'الوصف',
                hint: 'اختياري',
                icon: Icons.notes_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _imagePreview(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _imagePathController,
                        readOnly: true,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        decoration: _fieldDecoration(
                          'مسار الصورة (اختياري)',
                          icon: Icons.image_outlined,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickingImage ? null : _pickImage,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.upload_file,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              label: Text(
                                _pickingImage ? 'جاري...' : 'رفع صورة',
                                style: AppTextStyles.buttonTextDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _imagePathController.clear();
                                _pickedBytes = null;
                              }),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.dangerRed,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.dangerRed,
                              ),
                              label: const Text('إزالة'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              value: _isActive,
              activeColor: AppColors.successGreen,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'العلامة مفعّلة',
                style: AppTextStyles.fieldText,
              ),
              subtitle: const Text(
                'العلامات غير المفعلة لا تظهر في الفلاتر',
                style: AppTextStyles.fieldHint,
              ),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
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
                      : (_editingId == null ? 'حفظ العلامة' : 'تحديث العلامة'),
                  style: AppTextStyles.buttonTextStyle,
                ),
              ),
            ),
            if (_editingId != null) ...[
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

  Widget _brandThumb(BrandDb row) {
    final path = (row.imagePath ?? '').trim();
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

  Widget _buildListCard(List<BrandDb> rows) {
    final filtered = rows.where((row) {
      if (_search.isEmpty) return true;
      return row.id.toString().contains(_search) ||
          row.name.toLowerCase().contains(_search) ||
          (row.description ?? '').toLowerCase().contains(_search);
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
          final isWide = constraints.maxWidth >= 940;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.list_alt_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'العلامات الحالية',
                      style: AppTextStyles.topbarTitle,
                    ),
                  ),
                  _CountPill(value: filtered.length.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _searchController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  'بحث باسم العلامة',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.selectHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: const Text(
                    'لا توجد علامات مطابقة',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.fieldHint,
                  ),
                )
              else if (isWide)
                _buildWideTable(filtered)
              else
                _buildCompactList(filtered),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideTable(List<BrandDb> rows) {
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
                  child: Text('العلامة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('الوصف', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('الحالة', style: AppTextStyles.topbarTitle),
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
                final row = rows[index];
                final isEditing = row.id == _editingId;
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
                            _brandThumb(row),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                row.name,
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
                          row.description ?? '-',
                          style: AppTextStyles.topbarInfo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.isActive ? 'مفعلة' : 'موقفة',
                          style: AppTextStyles.topbarInfo.copyWith(
                            color: row.isActive
                                ? AppColors.successGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _startEdit(row),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                                minimumSize: const Size(86, 34),
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
                              onPressed: () => _delete(row),
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

  Widget _buildCompactList(List<BrandDb> rows) {
    return SizedBox(
      height: 420,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.neutralGrey),
        itemBuilder: (context, index) {
          final row = rows[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            leading: _brandThumb(row),
            title: Text(row.name, style: AppTextStyles.fieldText),
            subtitle: Text(
              row.description?.trim().isEmpty == false
                  ? row.description!
                  : 'بدون وصف',
              style: AppTextStyles.topbarInfo,
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => _startEdit(row),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => _delete(row),
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
      section: ControlPanelSection.productsBrands,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          _buildFormCard(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<BrandDb>>(
            stream: db.watchBrands(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <BrandDb>[];
              return _buildListCard(rows);
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
