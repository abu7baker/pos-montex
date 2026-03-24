import 'dart:convert';
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
import '../../../pos/presentation/widgets/pos_select.dart';
import '../../presentation/control_panel_shell.dart';

bool _containsArabic(String value) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(value);

bool _looksMojibake(String value) {
  return value.contains('Ø') ||
      value.contains('Ù') ||
      value.contains('Ã') ||
      value.contains('Â') ||
      value.contains('\uFFFD');
}

String _fixArabicMojibake(String value) {
  if (value.isEmpty || !_looksMojibake(value)) return value;
  try {
    final decoded = utf8.decode(latin1.encode(value));
    if (_containsArabic(decoded)) return decoded;
  } catch (_) {}
  return value;
}

class ControlPanelInvoiceSettingsScreen extends ConsumerStatefulWidget {
  const ControlPanelInvoiceSettingsScreen({super.key});

  @override
  ConsumerState<ControlPanelInvoiceSettingsScreen> createState() =>
      _ControlPanelInvoiceSettingsScreenState();
}

class _ControlPanelInvoiceSettingsScreenState
    extends ConsumerState<ControlPanelInvoiceSettingsScreen> {
  int _paperSize = 80;
  bool _bootstrapped = false;

  final _storeNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _vatNoController = TextEditingController();
  final _crNoController = TextEditingController();
  bool _savingStore = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final db = ref.read(appDbProvider);
      await db.ensureDefaultInvoiceTemplates();
      await _loadStoreSettings(db);
      if (mounted) setState(() => _bootstrapped = true);
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    _vatNoController.dispose();
    _crNoController.dispose();
    super.dispose();
  }

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

  Future<void> _loadStoreSettings(AppDb db) async {
    _storeNameController.text = _fixArabicMojibake(
      (await db.getSetting('store_name')) ?? '',
    );
    _branchNameController.text = _fixArabicMojibake(
      (await db.getSetting('branch_name')) ?? '',
    );
    _branchAddressController.text = _fixArabicMojibake(
      (await db.getSetting('branch_address')) ?? '',
    );
    _branchPhoneController.text = _fixArabicMojibake(
      (await db.getSetting('branch_phone')) ?? '',
    );
    _vatNoController.text = _fixArabicMojibake(
      (await db.getSetting('vat_no')) ?? '',
    );
    _crNoController.text = _fixArabicMojibake(
      (await db.getSetting('cr_no')) ?? '',
    );
  }

  Future<void> _saveStoreSettings() async {
    if (_savingStore) return;
    setState(() => _savingStore = true);
    try {
      final db = ref.read(appDbProvider);
      await db.setSetting('store_name', _storeNameController.text.trim());
      await db.setSetting('branch_name', _branchNameController.text.trim());
      await db.setSetting(
        'branch_address',
        _branchAddressController.text.trim(),
      );
      await db.setSetting('branch_phone', _branchPhoneController.text.trim());
      await db.setSetting('vat_no', _vatNoController.text.trim());
      await db.setSetting('cr_no', _crNoController.text.trim());
      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ بيانات المنشأة');
    } finally {
      if (mounted) setState(() => _savingStore = false);
    }
  }

  Future<void> _openTemplateEditor({InvoiceTemplateDb? template}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InvoiceTemplateEditorDialog(
        initialTemplate: template,
        defaultPaperSize: _paperSize,
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
              Icons.receipt_long,
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
                  'إعدادات الفواتير',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'صمم القوالب وحدد عناصر الفاتورة وشعار المنشأة',
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

  Widget _buildStoreInfoCard() {
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
              Icon(Icons.storefront, size: 18, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.xs),
              Text('بيانات المنشأة', style: AppTextStyles.topbarTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _storeNameController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'اسم المنشأة',
                    icon: Icons.store_outlined,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _branchNameController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'اسم الفرع',
                    icon: Icons.account_tree_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _branchAddressController,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            decoration: _fieldDecoration(
              'العنوان',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _branchPhoneController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'الهاتف',
                    icon: Icons.call_outlined,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _vatNoController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'الرقم الضريبي',
                    icon: Icons.verified_outlined,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _crNoController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'السجل التجاري',
                    icon: Icons.assignment_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _savingStore ? null : _saveStoreSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.save, size: 18, color: AppColors.white),
              label: Text(
                _savingStore ? 'جاري الحفظ...' : 'حفظ بيانات المنشأة',
                style: AppTextStyles.buttonTextStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesCard(AppDb db) {
    final paperOptions = const <PosSelectOption<int>>[
      PosSelectOption(value: 80, label: '80mm'),
      PosSelectOption(value: 210, label: 'A4'),
    ];

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
                Icons.receipt_long,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.xs),
              Text('قوالب الفواتير', style: AppTextStyles.topbarTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PosSelectField<int>(
                  label: 'حجم الورق',
                  hintText: 'اختر الحجم',
                  options: paperOptions,
                  value: _paperSize,
                  onChanged: (value) =>
                      setState(() => _paperSize = value ?? _paperSize),
                  leadingIcon: Icons.receipt_long,
                  enableSearch: false,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _openTemplateEditor(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.white),
                  label: Text(
                    'إضافة قالب',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<InvoiceTemplateDb>>(
            stream: db.watchInvoiceTemplates(_paperSize),
            builder: (context, snapshot) {
              final templates = snapshot.data ?? const <InvoiceTemplateDb>[];
              if (templates.isEmpty) {
                return const Text(
                  'لا توجد قوالب بعد',
                  style: AppTextStyles.topbarInfo,
                );
              }
              return Column(
                children: templates.map((template) {
                  final label = template.isDefault ? 'افتراضي' : 'قالب';
                  final templateName = _fixArabicMojibake(template.name);
                  final headerTitle = _fixArabicMojibake(template.headerTitle);
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                templateName,
                                style: AppTextStyles.topbarTitle,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: template.isDefault
                                    ? AppColors.selectSelected
                                    : AppColors.selectHover,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.fieldBorder,
                                ),
                              ),
                              child: Text(
                                label,
                                style: AppTextStyles.topbarInfo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'العنوان: $headerTitle',
                          style: AppTextStyles.topbarInfo,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (!template.isDefault)
                              TextButton.icon(
                                onPressed: () =>
                                    db.setDefaultInvoiceTemplate(template.id),
                                icon: const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                                label: const Text('تعيين افتراضي'),
                              ),
                            TextButton.icon(
                              onPressed: () =>
                                  _openTemplateEditor(template: template),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              label: const Text('تعديل'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('حذف القالب'),
                                      content: Text(
                                        'هل تريد حذف قالب "$templateName"طں',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          child: const Text('حذف'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirmed != true) return;
                                await db.deleteInvoiceTemplate(template.id);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.dangerRed,
                              ),
                              label: const Text('حذف'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    return ControlPanelShell(
      section: ControlPanelSection.settingsInvoices,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          if (_bootstrapped) _buildStoreInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildTemplatesCard(db),
        ],
      ),
    );
  }
}

class _InvoiceTemplateEditorDialog extends ConsumerStatefulWidget {
  const _InvoiceTemplateEditorDialog({
    required this.initialTemplate,
    required this.defaultPaperSize,
  });

  final InvoiceTemplateDb? initialTemplate;
  final int defaultPaperSize;

  @override
  ConsumerState<_InvoiceTemplateEditorDialog> createState() =>
      _InvoiceTemplateEditorDialogState();
}

class _InvoiceTemplateEditorDialogState
    extends ConsumerState<_InvoiceTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  final _logoController = TextEditingController();
  bool _saving = false;
  bool _setAsDefault = false;
  int _paperSize = 80;

  bool _showLogo = true;
  bool _showHeaderName = true;
  bool _showBranchAddress = true;
  bool _showPhone = true;
  bool _showVat = true;
  bool _showCr = true;
  bool _showInvoiceNo = true;
  bool _showDate = true;
  bool _showCustomer = true;
  bool _showItemsCount = true;
  bool _showSubtotal = true;
  bool _showDiscount = true;
  bool _showTax = true;
  bool _showTotal = true;
  bool _showAmountWords = true;
  bool _showPaymentLabel = true;
  bool _showPaid = true;
  bool _showRemaining = true;
  bool _showQr = true;

  @override
  void initState() {
    super.initState();
    final template = widget.initialTemplate;
    _paperSize = template?.paperSize ?? widget.defaultPaperSize;
    _nameController.text = _fixArabicMojibake(template?.name ?? '');
    _headerController.text = _fixArabicMojibake(
      template?.headerTitle ?? 'فاتورة ضريبية مبسطة',
    );
    _footerController.text = _fixArabicMojibake(template?.footerText ?? '');
    _logoController.text = template?.logoPath ?? '';
    _setAsDefault = template?.isDefault ?? false;

    _showLogo = template?.showLogo ?? true;
    _showHeaderName = template?.showHeaderName ?? true;
    _showBranchAddress = template?.showBranchAddress ?? true;
    _showPhone = template?.showPhone ?? true;
    _showVat = template?.showVat ?? true;
    _showCr = template?.showCr ?? true;
    _showInvoiceNo = template?.showInvoiceNo ?? true;
    _showDate = template?.showDate ?? true;
    _showCustomer = template?.showCustomer ?? true;
    _showItemsCount = template?.showItemsCount ?? true;
    _showSubtotal = template?.showSubtotal ?? true;
    _showDiscount = template?.showDiscount ?? true;
    _showTax = template?.showTax ?? true;
    _showTotal = template?.showTotal ?? true;
    _showAmountWords = template?.showAmountWords ?? true;
    _showPaymentLabel = template?.showPaymentLabel ?? true;
    _showPaid = template?.showPaid ?? true;
    _showRemaining = template?.showRemaining ?? true;
    _showQr = template?.showQr ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _logoController.dispose();
    super.dispose();
  }

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

  Future<String?> _copyLogoToAppDir(PlatformFile file, Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(
      p.join(dir.path, 'montex_pos_images', 'invoices'),
    );
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final ext = p.extension(file.name).isEmpty
        ? '.png'
        : p.extension(file.name);
    final fileName =
        'invoice_logo_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(imagesDir.path, fileName);
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  Future<void> _pickLogo() async {
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
    final storedPath = await _copyLogoToAppDir(file, bytes);
    if (!mounted) return;
    setState(() {
      _logoController.text = storedPath ?? file.path ?? '';
    });
  }

  Future<void> _saveTemplate() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final name = _nameController.text.trim();
      final headerTitle = _headerController.text.trim();
      final footerText = _footerController.text.trim();
      final logoPath = _logoController.text.trim();

      final id = await db.upsertInvoiceTemplate(
        InvoiceTemplatesCompanion(
          id: widget.initialTemplate == null
              ? const drift.Value.absent()
              : drift.Value(widget.initialTemplate!.id),
          name: drift.Value(name),
          paperSize: drift.Value(_paperSize),
          isDefault: drift.Value(_setAsDefault),
          headerTitle: drift.Value(headerTitle),
          footerText: drift.Value(footerText.isEmpty ? null : footerText),
          logoPath: drift.Value(logoPath.isEmpty ? null : logoPath),
          showLogo: drift.Value(_showLogo),
          showHeaderName: drift.Value(_showHeaderName),
          showBranchAddress: drift.Value(_showBranchAddress),
          showPhone: drift.Value(_showPhone),
          showVat: drift.Value(_showVat),
          showCr: drift.Value(_showCr),
          showInvoiceNo: drift.Value(_showInvoiceNo),
          showDate: drift.Value(_showDate),
          showCustomer: drift.Value(_showCustomer),
          showItemsCount: drift.Value(_showItemsCount),
          showSubtotal: drift.Value(_showSubtotal),
          showDiscount: drift.Value(_showDiscount),
          showTax: drift.Value(_showTax),
          showTotal: drift.Value(_showTotal),
          showAmountWords: drift.Value(_showAmountWords),
          showPaymentLabel: drift.Value(_showPaymentLabel),
          showPaid: drift.Value(_showPaid),
          showRemaining: drift.Value(_showRemaining),
          showQr: drift.Value(_showQr),
          updatedAtLocal: drift.Value(DateTime.now()),
        ),
      );

      if (_setAsDefault) {
        await db.setDefaultInvoiceTemplate(id);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildLogoPreview() {
    final path = _logoController.text.trim();
    if (path.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.selectHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: const Icon(
          Icons.image_outlined,
          size: 32,
          color: AppColors.textSecondary,
        ),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.selectHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Text('المسار غير موجود', style: AppTextStyles.selectValidation),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(file, width: 120, height: 120, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paperOptions = const <PosSelectOption<int>>[
      PosSelectOption(value: 80, label: '80mm'),
      PosSelectOption(value: 210, label: 'A4'),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text('بيانات القالب', style: AppTextStyles.topbarTitle),
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
                          'اسم القالب',
                          icon: Icons.label_outline,
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'الاسم مطلوب'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PosSelectField<int>(
                        label: 'حجم الورق',
                        hintText: 'اختر الحجم',
                        options: paperOptions,
                        value: _paperSize,
                        onChanged: widget.initialTemplate == null
                            ? (value) => setState(
                                () => _paperSize = value ?? _paperSize,
                              )
                            : null,
                        leadingIcon: Icons.receipt_long,
                        enableSearch: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _headerController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'عنوان الفاتورة',
                    icon: Icons.title_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _footerController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: _fieldDecoration(
                    'نص التذييل (اختياري)',
                    icon: Icons.subject_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoPreview(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _logoController,
                            readOnly: true,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            decoration: _fieldDecoration(
                              'الشعار',
                              icon: Icons.image_outlined,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickLogo,
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
                                    'رفع شعار',
                                    style: AppTextStyles.buttonTextDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => _logoController.clear()),
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
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: const [
                    Icon(
                      Icons.view_quilt_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text('مكونات القالب', style: AppTextStyles.topbarTitle),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _TemplateToggle(
                      label: 'إظهار الشعار',
                      value: _showLogo,
                      onChanged: (v) => setState(() => _showLogo = v),
                    ),
                    _TemplateToggle(
                      label: 'اسم المنشأة',
                      value: _showHeaderName,
                      onChanged: (v) => setState(() => _showHeaderName = v),
                    ),
                    _TemplateToggle(
                      label: 'العنوان',
                      value: _showBranchAddress,
                      onChanged: (v) => setState(() => _showBranchAddress = v),
                    ),
                    _TemplateToggle(
                      label: 'الهاتف',
                      value: _showPhone,
                      onChanged: (v) => setState(() => _showPhone = v),
                    ),
                    _TemplateToggle(
                      label: 'الرقم الضريبي',
                      value: _showVat,
                      onChanged: (v) => setState(() => _showVat = v),
                    ),
                    _TemplateToggle(
                      label: 'السجل التجاري',
                      value: _showCr,
                      onChanged: (v) => setState(() => _showCr = v),
                    ),
                    _TemplateToggle(
                      label: 'رقم الفاتورة',
                      value: _showInvoiceNo,
                      onChanged: (v) => setState(() => _showInvoiceNo = v),
                    ),
                    _TemplateToggle(
                      label: 'التاريخ والوقت',
                      value: _showDate,
                      onChanged: (v) => setState(() => _showDate = v),
                    ),
                    _TemplateToggle(
                      label: 'اسم العميل',
                      value: _showCustomer,
                      onChanged: (v) => setState(() => _showCustomer = v),
                    ),
                    _TemplateToggle(
                      label: 'إجمالي العدد',
                      value: _showItemsCount,
                      onChanged: (v) => setState(() => _showItemsCount = v),
                    ),
                    _TemplateToggle(
                      label: 'الإجمالي قبل الضريبة',
                      value: _showSubtotal,
                      onChanged: (v) => setState(() => _showSubtotal = v),
                    ),
                    _TemplateToggle(
                      label: 'الخصم',
                      value: _showDiscount,
                      onChanged: (v) => setState(() => _showDiscount = v),
                    ),
                    _TemplateToggle(
                      label: 'الضريبة',
                      value: _showTax,
                      onChanged: (v) => setState(() => _showTax = v),
                    ),
                    _TemplateToggle(
                      label: 'الإجمالي شامل الضريبة',
                      value: _showTotal,
                      onChanged: (v) => setState(() => _showTotal = v),
                    ),
                    _TemplateToggle(
                      label: 'كتابة المبلغ',
                      value: _showAmountWords,
                      onChanged: (v) => setState(() => _showAmountWords = v),
                    ),
                    _TemplateToggle(
                      label: 'طريقة الدفع',
                      value: _showPaymentLabel,
                      onChanged: (v) => setState(() => _showPaymentLabel = v),
                    ),
                    _TemplateToggle(
                      label: 'المبلغ المدفوع',
                      value: _showPaid,
                      onChanged: (v) => setState(() => _showPaid = v),
                    ),
                    _TemplateToggle(
                      label: 'المستحق',
                      value: _showRemaining,
                      onChanged: (v) => setState(() => _showRemaining = v),
                    ),
                    _TemplateToggle(
                      label: 'QR ضريبي',
                      value: _showQr,
                      onChanged: (v) => setState(() => _showQr = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  value: _setAsDefault,
                  onChanged: (value) =>
                      setState(() => _setAsDefault = value ?? false),
                  activeColor: AppColors.primaryBlue,
                  title: const Text(
                    'تعيين كقالب افتراضي لهذا الحجم',
                    style: AppTextStyles.fieldText,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveTemplate,
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
                            _saving ? 'جاري الحفظ...' : 'حفظ القالب',
                            style: AppTextStyles.buttonTextStyle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primaryBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'إغلاق',
                            style: AppTextStyles.buttonTextStyle.copyWith(
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateToggle extends StatelessWidget {
  const _TemplateToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: AppTextStyles.topbarInfo),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppColors.selectSelected,
      checkmarkColor: AppColors.primaryBlue,
      showCheckmark: true,
    );
  }
}
