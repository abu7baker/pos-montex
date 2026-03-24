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

class ControlPanelTablesScreen extends ConsumerStatefulWidget {
  const ControlPanelTablesScreen({super.key});

  @override
  ConsumerState<ControlPanelTablesScreen> createState() =>
      _ControlPanelTablesScreenState();
}

class _ControlPanelTablesScreenState
    extends ConsumerState<ControlPanelTablesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _capacityController = TextEditingController(text: '0');
  final _sortOrderController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;
  int? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _capacityController.dispose();
    _sortOrderController.dispose();
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

  void _resetForm() {
    _nameController.clear();
    _codeController.clear();
    _capacityController.text = '0';
    _sortOrderController.text = '0';
    setState(() {
      _editingId = null;
      _isActive = true;
    });
  }

  void _startEdit(PosTableDb row) {
    _nameController.text = row.name;
    _codeController.text = row.code ?? '';
    _capacityController.text = row.capacity.toString();
    _sortOrderController.text = row.sortOrder.toString();
    setState(() {
      _editingId = row.id;
      _isActive = row.isActive;
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
      final code = _codeController.text.trim();
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;

      int sortOrder;
      if (_sortOrderController.text.trim().isEmpty) {
        sortOrder = _editingId == null ? await db.getNextTableSortOrder() : 0;
      } else {
        sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
      }

      await db.upsertPosTable(
        PosTablesCompanion.insert(
          id: _editingId == null
              ? const drift.Value.absent()
              : drift.Value(_editingId!),
          name: name,
          code: drift.Value(code.isEmpty ? null : code),
          capacity: drift.Value(capacity < 0 ? 0 : capacity),
          sortOrder: drift.Value(sortOrder < 0 ? 0 : sortOrder),
          isActive: drift.Value(_isActive),
          isDeleted: const drift.Value(false),
          updatedAtLocal: drift.Value(DateTime.now()),
        ),
      );

      if (!mounted) return;
      AppFeedback.success(
        context,
        _editingId == null ? 'تم حفظ الطاولة' : 'تم تحديث الطاولة',
      );
      _resetForm();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ الطاولة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PosTableDb row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الطاولة'),
        content: Text('هل تريد حذف الطاولة "${row.name}"؟'),
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

    await ref.read(appDbProvider).softDeletePosTable(row.id);
    if (!mounted) return;
    if (_editingId == row.id) _resetForm();
    AppFeedback.success(context, 'تم حذف الطاولة');
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
              Icons.table_restaurant_outlined,
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
                  'إدارة الطاولات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إضافة وتنظيم طاولات المطعم لتظهر مباشرة داخل شاشة الكاشير',
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
                Text('بيانات الطاولة', style: AppTextStyles.topbarTitle),
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
                      'اسم الطاولة',
                      hint: 'مثال: طاولة 1',
                      icon: Icons.table_restaurant_outlined,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'اسم الطاولة مطلوب'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'الكود',
                      hint: 'اختياري',
                      icon: Icons.qr_code_2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'السعة',
                      icon: Icons.people_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return int.tryParse(value.trim()) == null
                          ? 'رقم غير صالح'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration('الترتيب', icon: Icons.sort),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return int.tryParse(value.trim()) == null
                          ? 'رقم غير صالح'
                          : null;
                    },
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
                'الطاولة مفعّلة',
                style: AppTextStyles.fieldText,
              ),
              subtitle: const Text(
                'الطاولات غير المفعلة لا تظهر في اختيار طاولة بالكاشير',
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
                      : (_editingId == null ? 'حفظ الطاولة' : 'تحديث الطاولة'),
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

  Widget _buildListCard(List<PosTableDb> rows) {
    final filtered = rows.where((row) {
      if (_search.isEmpty) return true;
      return row.id.toString().contains(_search) ||
          row.name.toLowerCase().contains(_search) ||
          (row.code ?? '').toLowerCase().contains(_search) ||
          row.capacity.toString().contains(_search) ||
          row.sortOrder.toString().contains(_search);
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
                      'الطاولات الحالية',
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
                  'بحث باسم الطاولة أو الكود',
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
                    'لا توجد طاولات مطابقة',
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

  Widget _buildWideTable(List<PosTableDb> rows) {
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
                  child: Text('الطاولة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('الكود', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('السعة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('الترتيب', style: AppTextStyles.topbarTitle),
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
                        flex: 2,
                        child: Text(row.name, style: AppTextStyles.fieldText),
                      ),
                      Expanded(
                        child: Text(
                          row.code ?? '-',
                          style: AppTextStyles.topbarInfo,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.capacity.toString(),
                          style: AppTextStyles.fieldText,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.sortOrder.toString(),
                          style: AppTextStyles.fieldText,
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

  Widget _buildCompactList(List<PosTableDb> rows) {
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
            title: Text(row.name, style: AppTextStyles.fieldText),
            subtitle: Text(
              'الكود: ${row.code ?? '-'} - السعة: ${row.capacity} - الترتيب: ${row.sortOrder}',
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
      section: ControlPanelSection.settingsTables,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          _buildFormCard(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<PosTableDb>>(
            stream: db.watchPosTables(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <PosTableDb>[];
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
