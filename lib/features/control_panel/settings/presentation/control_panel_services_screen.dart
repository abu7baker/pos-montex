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

class ControlPanelServicesScreen extends ConsumerStatefulWidget {
  const ControlPanelServicesScreen({super.key});

  @override
  ConsumerState<ControlPanelServicesScreen> createState() =>
      _ControlPanelServicesScreenState();
}

class _ControlPanelServicesScreenState
    extends ConsumerState<ControlPanelServicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;
  int? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
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
    _descriptionController.clear();
    _costController.text = '0';
    setState(() {
      _editingId = null;
      _isActive = true;
    });
  }

  void _startEdit(ServiceDb row) {
    _nameController.text = row.name;
    _descriptionController.text = row.description ?? '';
    _costController.text = row.cost.toStringAsFixed(2);
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
      final description = _descriptionController.text.trim();
      final cost = double.tryParse(_costController.text.trim()) ?? 0;

      await db.upsertService(
        ServicesCompanion.insert(
          id: _editingId == null
              ? const drift.Value.absent()
              : drift.Value(_editingId!),
          name: name,
          description: drift.Value(description.isEmpty ? null : description),
          cost: drift.Value(cost),
          isActive: drift.Value(_isActive),
          isDeleted: const drift.Value(false),
          updatedAtLocal: drift.Value(DateTime.now()),
        ),
      );

      if (!mounted) return;
      AppFeedback.success(
        context,
        _editingId == null ? 'تم حفظ الخدمة' : 'تم تحديث الخدمة',
      );
      _resetForm();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر حفظ الخدمة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ServiceDb row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الخدمة'),
        content: Text('هل تريد حذف الخدمة "${row.name}"؟'),
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

    await ref.read(appDbProvider).softDeleteService(row.id);
    if (!mounted) return;
    if (_editingId == row.id) _resetForm();
    AppFeedback.success(context, 'تم حذف الخدمة');
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
              Icons.room_service_outlined,
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
                  'إدارة الخدمات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إضافة خدمات الفاتورة مثل محلي وسفري وتوصيل مع تكلفة كل خدمة',
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
                Text('بيانات الخدمة', style: AppTextStyles.topbarTitle),
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
                      'اسم الخدمة',
                      hint: 'مثال: سفري أو توصيل',
                      icon: Icons.room_service_outlined,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'اسم الخدمة مطلوب'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: _fieldDecoration(
                      'التكلفة',
                      icon: Icons.payments_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return double.tryParse(value.trim()) == null
                          ? 'قيمة غير صحيحة'
                          : null;
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
              minLines: 2,
              maxLines: 4,
              decoration: _fieldDecoration(
                'الوصف',
                hint: 'اختياري',
                icon: Icons.notes_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              value: _isActive,
              activeColor: AppColors.successGreen,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'الخدمة مفعّلة',
                style: AppTextStyles.fieldText,
              ),
              subtitle: const Text(
                'الخدمات غير المفعلة لا تظهر في الكاشير',
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
                      : (_editingId == null ? 'حفظ الخدمة' : 'تحديث الخدمة'),
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

  Widget _buildListCard(List<ServiceDb> rows) {
    final filtered = rows.where((row) {
      if (_search.isEmpty) return true;
      return row.id.toString().contains(_search) ||
          row.name.toLowerCase().contains(_search) ||
          (row.description ?? '').toLowerCase().contains(_search) ||
          row.cost.toStringAsFixed(2).contains(_search);
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
                      'الخدمات الحالية',
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
                  'بحث باسم الخدمة أو الوصف',
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
                    'لا توجد خدمات مطابقة',
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

  Widget _buildWideTable(List<ServiceDb> rows) {
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
                  child: Text('الخدمة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('التكلفة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  child: Text('الحالة', style: AppTextStyles.topbarTitle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('الوصف', style: AppTextStyles.topbarTitle),
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
                          row.cost.toStringAsFixed(2),
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
                        child: Text(
                          row.description ?? '-',
                          style: AppTextStyles.topbarInfo,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildCompactList(List<ServiceDb> rows) {
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
              'التكلفة: ${row.cost.toStringAsFixed(2)} - ${row.isActive ? 'مفعلة' : 'موقفة'}',
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
      section: ControlPanelSection.settingsServices,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          _buildFormCard(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<ServiceDb>>(
            stream: db.watchServices(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <ServiceDb>[];
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
