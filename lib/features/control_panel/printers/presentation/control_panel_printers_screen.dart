import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../pos/presentation/widgets/pos_select.dart';
import '../data/printer_repository_provider.dart';
import '../../presentation/control_panel_shell.dart';

enum PrintersPageView { stations, addPrinter, addedPrinters }

class ControlPanelPrintersScreen extends ConsumerStatefulWidget {
  const ControlPanelPrintersScreen({
    super.key,
    this.section = ControlPanelSection.printersStations,
    this.pageView = PrintersPageView.stations,
  });

  const ControlPanelPrintersScreen.stations({super.key})
    : section = ControlPanelSection.printersStations,
      pageView = PrintersPageView.stations;

  const ControlPanelPrintersScreen.addPrinter({super.key})
    : section = ControlPanelSection.printersAdd,
      pageView = PrintersPageView.addPrinter;

  const ControlPanelPrintersScreen.addedPrinters({super.key})
    : section = ControlPanelSection.printersList,
      pageView = PrintersPageView.addedPrinters;

  final ControlPanelSection section;
  final PrintersPageView pageView;

  @override
  ConsumerState<ControlPanelPrintersScreen> createState() =>
      _ControlPanelPrintersScreenState();
}

class _ControlPanelPrintersScreenState
    extends ConsumerState<ControlPanelPrintersScreen> {
  Widget _buildPageSection() {
    switch (widget.pageView) {
      case PrintersPageView.stations:
        return const _PrintStationsSection();
      case PrintersPageView.addPrinter:
        return const _AddPrinterSection();
      case PrintersPageView.addedPrinters:
        return const _PrintersListSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionWidget = _buildPageSection();

    return ControlPanelShell(
      section: widget.section,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          if (!isWide) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _HeroHeader(),
                const SizedBox(height: AppSpacing.lg),
                sectionWidget,
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const _HeroHeader(),
                const SizedBox(height: AppSpacing.lg),
                sectionWidget,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
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
              Icons.print_outlined,
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
                  'إدارة الطابعات',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اربط الطابعة بمحطة طباعة ليتم توزيع الأصناف حسب القسم',
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
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.topbarIconDeepBlue, AppColors.primaryBlue],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.selectHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.topbarTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: AppTextStyles.topbarInfo),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.topbarTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.topbarInfo),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldColumn extends StatelessWidget {
  const _FieldColumn({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.fieldText, textAlign: TextAlign.right),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(height: 44, child: child),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Text(label, style: AppTextStyles.topbarInfo),
    );
  }
}

class _PrintStationsSection extends ConsumerStatefulWidget {
  const _PrintStationsSection();

  @override
  ConsumerState<_PrintStationsSection> createState() =>
      _PrintStationsSectionState();
}

class _PrintStationsSectionState extends ConsumerState<_PrintStationsSection> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveStation() async {
    if (_saving) return;
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      AppFeedback.warning(context, 'أدخل كود واسم المحطة');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      await db.upsertPrintStation(code: code, name: name);
      _codeController.clear();
      _nameController.clear();
      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ محطة الطباعة');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    IconData? icon,
    bool showLabel = true,
  }) {
    return InputDecoration(
      labelText: showLabel ? label : null,
      labelStyle: AppTextStyles.fieldText,
      floatingLabelBehavior: showLabel
          ? FloatingLabelBehavior.auto
          : FloatingLabelBehavior.never,
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);

    return _PanelCard(
      title: 'محطات الطباعة',
      icon: Icons.store_mall_directory_outlined,
      subtitle: 'أنشئ محطات لربط الطابعات وتوزيع الأصناف حسب القسم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _FieldColumn(
                  label: 'كود المحطة',
                  child: TextField(
                    controller: _codeController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: _fieldDecoration(
                      hint: 'KITCHEN',
                      icon: Icons.qr_code,
                      showLabel: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FieldColumn(
                  label: 'اسم المحطة',
                  child: TextField(
                    controller: _nameController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: _fieldDecoration(
                      hint: 'المطبخ',
                      icon: Icons.storefront,
                      showLabel: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveStation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.white),
                  label: Text(
                    _saving ? 'جاري الحفظ...' : 'إضافة محطة',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<PrintStationDb>>(
            stream: db.watchPrintStations(),
            builder: (context, snapshot) {
              final stations = snapshot.data ?? const <PrintStationDb>[];
              if (stations.isEmpty) {
                return const Text(
                  'لم يتم إضافة محطات بعد',
                  style: AppTextStyles.topbarInfo,
                );
              }
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: stations
                    .map(
                      (s) => Container(
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.name, style: AppTextStyles.topbarInfo),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '(${s.code})',
                              style: AppTextStyles.topbarTitle,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddPrinterSection extends ConsumerStatefulWidget {
  const _AddPrinterSection();

  @override
  ConsumerState<_AddPrinterSection> createState() => _AddPrinterSectionState();
}

class _AddPrinterSectionState extends ConsumerState<_AddPrinterSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _windowsNameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _btController = TextEditingController();
  final _copiesController = TextEditingController(text: '1');

  String _printerType = 'طابعة أقسام';
  String _connectionType = 'WINDOWS';
  int _paperSize = 80;
  final List<String> _selectedStations = [];
  final List<int> _selectedCategoryIds = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _windowsNameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _btController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    IconData? icon,
    bool showLabel = true,
  }) {
    return InputDecoration(
      labelText: showLabel ? label : null,
      labelStyle: AppTextStyles.fieldText,
      floatingLabelBehavior: showLabel
          ? FloatingLabelBehavior.auto
          : FloatingLabelBehavior.never,
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

  Future<int> _ensureWorkstationId(AppDb db) async {
    var deviceId = await db.getSetting('device_id');
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await db.setSetting('device_id', deviceId);
    }
    final name = Platform.localHostname;
    return db.upsertWorkstation(deviceId: deviceId, name: name);
  }

  Future<void> _savePrinter(List<PrintStationDb> stations) async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_selectedStations.isEmpty) {
      AppFeedback.warning(context, 'اختر محطة طباعة واحدة على الأقل');
      return;
    }

    final db = ref.read(appDbProvider);
    final repo = ref.read(printerRepositoryProvider);
    final workstationId = await _ensureWorkstationId(db);

    final name = _nameController.text.trim();
    final connectionType = _connectionType;
    String? windowsPrinterName;
    String? ip;
    int? port;
    String? btMac;

    if (connectionType == 'WINDOWS') {
      windowsPrinterName = _windowsNameController.text.trim();
      if (windowsPrinterName.isEmpty) {
        AppFeedback.warning(context, 'أدخل اسم طابعة Windows');
        return;
      }
    }

    if (connectionType == 'NETWORK') {
      ip = _ipController.text.trim();
      port = int.tryParse(_portController.text.trim()) ?? 9100;
      if (ip.isEmpty) {
        AppFeedback.warning(context, 'أدخل عنوان IP');
        return;
      }
    }

    if (connectionType == 'BLUETOOTH') {
      btMac = _btController.text.trim();
      if (btMac.isEmpty) {
        AppFeedback.warning(context, 'أدخل MAC للطابعة');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final printerId = await repo.savePrinter(
        name: name,
        type: _printerType,
        connectionType: connectionType,
        stationCode: _selectedStations.first,
        windowsPrinterName: windowsPrinterName,
        ip: ip,
        port: port,
        btMac: btMac,
        copies: int.tryParse(_copiesController.text.trim()),
        paperSize: _paperSize,
        workstationId: workstationId,
      );

      await db.setPrinterStations(
        printerId: printerId,
        stationCodes: _selectedStations,
      );

      if (_printerType == 'طابعة أقسام' && _selectedCategoryIds.isNotEmpty) {
        if (_selectedStations.length != 1) {
          AppFeedback.warning(context, 'اختر محطة واحدة فقط لربط الأقسام');
        } else {
          await db.assignCategoriesToStation(
            categoryIds: _selectedCategoryIds,
            stationCode: _selectedStations.first,
          );
        }
      }

      if (!mounted) return;
      AppFeedback.success(context, 'تم حفظ الطابعة وربطها بالمحطات');
      _nameController.clear();
      _windowsNameController.clear();
      _ipController.clear();
      _portController.text = '9100';
      _btController.clear();
      _copiesController.text = '1';
      setState(() {
        _selectedStations.clear();
        _selectedCategoryIds.clear();
        _connectionType = 'WINDOWS';
        _printerType = 'طابعة أقسام';
        _paperSize = 80;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildConnectionFields() {
    if (_connectionType == 'WINDOWS') {
      return FutureBuilder<List<String>>(
        future: ref.read(printerRepositoryProvider).listInstalledPrinters(),
        builder: (context, snapshot) {
          final installed = snapshot.data ?? const <String>[];
          if (installed.isEmpty) {
            return _FieldColumn(
              label: 'اسم طابعة Windows',
              child: TextFormField(
                key: const ValueKey('windows-input'),
                controller: _windowsNameController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                textAlignVertical: TextAlignVertical.center,
                decoration: _fieldDecoration(
                  icon: Icons.print_outlined,
                  showLabel: false,
                ),
                validator: (value) =>
                    (_connectionType == 'WINDOWS' &&
                        (value == null || value.trim().isEmpty))
                    ? 'هذا الحقل مطلوب'
                    : null,
              ),
            );
          }
          final options = installed
              .map((name) => PosSelectOption<String>(value: name, label: name))
              .toList();
          return PosSelectField<String>(
            key: const ValueKey('windows-select'),
            label: 'طابعات Windows',
            hintText: 'اختر طابعة',
            options: options,
            value: installed.contains(_windowsNameController.text)
                ? _windowsNameController.text
                : null,
            onChanged: (value) =>
                setState(() => _windowsNameController.text = value ?? ''),
            leadingIcon: Icons.print_outlined,
            enableSearch: true,
          );
        },
      );
    }

    if (_connectionType == 'NETWORK') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        key: const ValueKey('network-fields'),
        children: [
          Expanded(
            flex: 2,
            child: _FieldColumn(
              label: 'عنوان IP',
              child: TextFormField(
                controller: _ipController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                textAlignVertical: TextAlignVertical.center,
                decoration: _fieldDecoration(
                  icon: Icons.router,
                  showLabel: false,
                ),
                validator: (value) =>
                    (_connectionType == 'NETWORK' &&
                        (value == null || value.trim().isEmpty))
                    ? 'هذا الحقل مطلوب'
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _FieldColumn(
              label: 'Port',
              child: TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                textAlignVertical: TextAlignVertical.center,
                decoration: _fieldDecoration(
                  icon: Icons.numbers,
                  showLabel: false,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_connectionType == 'BLUETOOTH') {
      return _FieldColumn(
        label: 'Bluetooth MAC',
        child: TextFormField(
          key: const ValueKey('bluetooth-field'),
          controller: _btController,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          textAlignVertical: TextAlignVertical.center,
          decoration: _fieldDecoration(icon: Icons.bluetooth, showLabel: false),
          validator: (value) =>
              (_connectionType == 'BLUETOOTH' &&
                  (value == null || value.trim().isEmpty))
              ? 'هذا الحقل مطلوب'
              : null,
        ),
      );
    }

    return Container(
      key: const ValueKey('usb-note'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.selectHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'سيتم دعم تفاصيل USB لاحقاً (Vendor/Product/Serial)',
              style: AppTextStyles.topbarInfo,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    final printerTypeOptions = const <PosSelectOption<String>>[
      PosSelectOption(value: 'طابعة أقسام', label: 'طابعة أقسام'),
      PosSelectOption(value: 'مجمعه', label: 'مجمعه'),
    ];
    final connectionTypeOptions = const <PosSelectOption<String>>[
      PosSelectOption(value: 'WINDOWS', label: 'Windows'),
      PosSelectOption(value: 'NETWORK', label: 'شبكة'),
      PosSelectOption(value: 'BLUETOOTH', label: 'Bluetooth'),
      PosSelectOption(value: 'USB', label: 'USB'),
    ];
    final paperSizeOptions = const <PosSelectOption<int>>[
      PosSelectOption(value: 80, label: '80mm'),
      PosSelectOption(value: 210, label: 'A4'),
    ];

    return _PanelCard(
      title: 'إضافة طابعة',
      icon: Icons.print,
      subtitle: 'عرّف الطابعة واربطها بمحطات الطباعة والأقسام',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              title: 'بيانات الطابعة',
              subtitle: 'الاسم ونوع الطابعة ونوع الاتصال',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: _FieldColumn(
                    label: 'اسم الطابعة',
                    child: TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: _fieldDecoration(
                        icon: Icons.badge_outlined,
                        showLabel: false,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'الاسم مطلوب'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PosSelectField<String>(
                    label: 'نوع الطابعة',
                    hintText: 'اختر نوع الطابعة',
                    options: printerTypeOptions,
                    value: _printerType,
                    onChanged: (value) =>
                        setState(() => _printerType = value ?? _printerType),
                    leadingIcon: Icons.layers_outlined,
                    enableSearch: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PosSelectField<String>(
                    label: 'الاتصال',
                    hintText: 'اختر نوع الاتصال',
                    options: connectionTypeOptions,
                    value: _connectionType,
                    onChanged: (value) => setState(
                      () => _connectionType = value ?? _connectionType,
                    ),
                    leadingIcon: Icons.cable,
                    enableSearch: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle(
              title: 'تفاصيل الاتصال',
              subtitle: 'حدد بيانات الاتصال حسب نوع الطابعة',
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _buildConnectionFields(),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle(
              title: 'إعدادات الطباعة',
              subtitle: 'حجم الورق وعدد النسخ',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: PosSelectField<int>(
                    label: 'حجم الورق',
                    hintText: 'اختر حجم الورق',
                    options: paperSizeOptions,
                    value: _paperSize,
                    onChanged: (value) =>
                        setState(() => _paperSize = value ?? _paperSize),
                    leadingIcon: Icons.receipt_long,
                    enableSearch: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FieldColumn(
                    label: 'عدد النسخ',
                    child: TextFormField(
                      controller: _copiesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: _fieldDecoration(
                        icon: Icons.copy,
                        showLabel: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle(
              title: 'محطات الطباعة',
              subtitle: 'اختر محطة واحدة أو أكثر للطابعة',
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<List<PrintStationDb>>(
              stream: db.watchPrintStations(),
              builder: (context, snapshot) {
                final stations = snapshot.data ?? const <PrintStationDb>[];
                if (stations.isEmpty) {
                  return const Text(
                    'أضف محطة طباعة أولاً لربط الطابعة بها',
                    style: AppTextStyles.topbarInfo,
                  );
                }
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: stations.map((s) {
                    final isSelected = _selectedStations.contains(s.code);
                    return FilterChip(
                      label: Text('${s.name} (${s.code})'),
                      selected: isSelected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedStations.add(s.code);
                          } else {
                            _selectedStations.remove(s.code);
                          }
                        });
                      },
                      selectedColor: AppColors.selectSelected,
                      checkmarkColor: AppColors.primaryBlue,
                    );
                  }).toList(),
                );
              },
            ),
            if (_printerType == 'طابعة أقسام') ...[
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle(
                title: 'الأقسام المرتبطة',
                subtitle: 'يتم الطباعة حسب الأقسام المرتبطة بالمحطة',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _selectedStations.length == 1
                    ? 'حدد الأقسام التي ستطبع على هذه الطابعة'
                    : 'اختر محطة واحدة أولاً لتفعيل ربط الأقسام',
                style: AppTextStyles.topbarInfo,
              ),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<ProductCategoryDb>>(
                stream: db.watchProductCategories(),
                builder: (context, catSnap) {
                  final categories =
                      catSnap.data ?? const <ProductCategoryDb>[];
                  if (categories.isEmpty) {
                    return const Text(
                      'لا توجد أقسام بعد',
                      style: AppTextStyles.topbarInfo,
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: categories.map((c) {
                      final isSelected = _selectedCategoryIds.contains(c.id);
                      return FilterChip(
                        label: Text(c.name),
                        selected: isSelected,
                        onSelected: _selectedStations.length == 1
                            ? (value) {
                                setState(() {
                                  if (value) {
                                    _selectedCategoryIds.add(c.id);
                                  } else {
                                    _selectedCategoryIds.remove(c.id);
                                  }
                                });
                              }
                            : null,
                        selectedColor: AppColors.selectSelected,
                        checkmarkColor: AppColors.primaryBlue,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final stations = await db.getPrintStations();
                        await _savePrinter(stations);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save, size: 18, color: AppColors.white),
                label: Text(
                  _saving ? 'جاري الحفظ...' : 'حفظ الطابعة',
                  style: AppTextStyles.buttonTextStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintersListSection extends ConsumerWidget {
  const _PrintersListSection();

  String _connectionLabel(String value) {
    switch (value) {
      case 'WINDOWS':
        return 'Windows';
      case 'NETWORK':
        return 'شبكة';
      case 'BLUETOOTH':
        return 'Bluetooth';
      case 'USB':
        return 'USB';
      default:
        return value;
    }
  }

  String _paperLabel(int paperSize) {
    if (paperSize == 210) return 'A4';
    return '${paperSize}mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDbProvider);

    return _PanelCard(
      title: 'الطابعات المضافة',
      icon: Icons.list_alt,
      subtitle: 'تحكم بالطابعات المرتبطة وبيانات الاتصال',
      child: StreamBuilder<List<PrinterDb>>(
        stream: (db.select(
          db.printers,
        )..where((t) => t.isDeleted.equals(false))).watch(),
        builder: (context, snapshot) {
          final printers = snapshot.data ?? const <PrinterDb>[];
          if (printers.isEmpty) {
            return const Text(
              'لا توجد طابعات مضافة',
              style: AppTextStyles.topbarInfo,
            );
          }
          return Column(
            children: printers.map((p) {
              return FutureBuilder<List<PrinterStationMapDb>>(
                future: (db.select(
                  db.printerStationMap,
                )..where((t) => t.printerId.equals(p.id))).get(),
                builder: (context, mapSnap) {
                  final mappings =
                      mapSnap.data ?? const <PrinterStationMapDb>[];
                  final stations = mappings
                      .map((m) => m.stationCode)
                      .toSet()
                      .join(', ');
                  final tags = <String>[
                    p.type,
                    _connectionLabel(p.connectionType),
                    _paperLabel(p.paperSize),
                    if (p.copies > 1) 'نسخ: ${p.copies}',
                  ];

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
                                p.name,
                                style: AppTextStyles.topbarTitle,
                              ),
                            ),
                            IconButton(
                              tooltip: 'تعديل الطابعة',
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                              onPressed: () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => PrinterEditDialog(printer: p),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'حذف الطابعة',
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.dangerRed,
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('حذف الطابعة'),
                                      content: Text(
                                        'هل تريد حذف الطابعة "${p.name}"؟',
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
                                await (db.update(
                                  db.printers,
                                )..where((t) => t.id.equals(p.id))).write(
                                  PrintersCompanion(
                                    isDeleted: const drift.Value(true),
                                    enabled: const drift.Value(false),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: tags
                              .map((tag) => _InfoChip(label: tag))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if ((p.windowsPrinterName ?? '').isNotEmpty)
                          Text(
                            'Windows: ${p.windowsPrinterName}',
                            style: AppTextStyles.topbarInfo,
                          ),
                        if ((p.ip ?? '').isNotEmpty)
                          Text(
                            'IP: ${p.ip}:${p.port}',
                            style: AppTextStyles.topbarInfo,
                          ),
                        if ((p.btMac ?? '').isNotEmpty)
                          Text(
                            'BT: ${p.btMac}',
                            style: AppTextStyles.topbarInfo,
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.selectHover,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.fieldBorder),
                          ),
                          child: Text(
                            stations.isEmpty ? 'بدون محطات' : stations,
                            style: AppTextStyles.topbarInfo,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class PrinterEditDialog extends ConsumerStatefulWidget {
  const PrinterEditDialog({super.key, required this.printer});

  final PrinterDb printer;

  @override
  ConsumerState<PrinterEditDialog> createState() => _PrinterEditDialogState();
}

class _PrinterEditDialogState extends ConsumerState<PrinterEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _windowsNameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _btController = TextEditingController();
  final _copiesController = TextEditingController(text: '1');

  String _printerType = 'طابعة أقسام';
  String _connectionType = 'WINDOWS';
  int _paperSize = 80;
  final List<String> _selectedStations = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.printer;
    _nameController.text = p.name;
    _windowsNameController.text = p.windowsPrinterName ?? '';
    _ipController.text = p.ip ?? '';
    _portController.text = p.port.toString();
    _btController.text = p.btMac ?? '';
    _copiesController.text = p.copies.toString();
    _printerType = p.type;
    _connectionType = p.connectionType;
    _paperSize = p.paperSize;

    Future.microtask(_loadStations);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _windowsNameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _btController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    final db = ref.read(appDbProvider);
    final maps = await (db.select(
      db.printerStationMap,
    )..where((t) => t.printerId.equals(widget.printer.id))).get();
    if (!mounted) return;
    setState(() {
      _selectedStations
        ..clear()
        ..addAll(maps.map((m) => m.stationCode));
    });
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    IconData? icon,
    bool showLabel = true,
  }) {
    return InputDecoration(
      labelText: showLabel ? label : null,
      labelStyle: AppTextStyles.fieldText,
      floatingLabelBehavior: showLabel
          ? FloatingLabelBehavior.auto
          : FloatingLabelBehavior.never,
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

  Future<int> _ensureWorkstationId(AppDb db) async {
    var deviceId = await db.getSetting('device_id');
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await db.setSetting('device_id', deviceId);
    }
    final name = Platform.localHostname;
    return db.upsertWorkstation(deviceId: deviceId, name: name);
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_selectedStations.isEmpty) {
      AppFeedback.warning(context, 'اختر محطة طباعة واحدة على الأقل');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final repo = ref.read(printerRepositoryProvider);
      final workstationId =
          widget.printer.workstationId ?? await _ensureWorkstationId(db);

      String? windowsPrinterName;
      String? ip;
      int? port;
      String? btMac;

      if (_connectionType == 'WINDOWS') {
        windowsPrinterName = _windowsNameController.text.trim();
        if (windowsPrinterName.isEmpty) {
          AppFeedback.warning(context, 'أدخل اسم طابعة Windows');
          return;
        }
      }

      if (_connectionType == 'NETWORK') {
        ip = _ipController.text.trim();
        port = int.tryParse(_portController.text.trim()) ?? 9100;
        if (ip.isEmpty) {
          AppFeedback.warning(context, 'أدخل عنوان IP');
          return;
        }
      }

      if (_connectionType == 'BLUETOOTH') {
        btMac = _btController.text.trim();
        if (btMac.isEmpty) {
          AppFeedback.warning(context, 'أدخل MAC للطابعة');
          return;
        }
      }

      final printerId = await repo.savePrinter(
        id: widget.printer.id,
        name: _nameController.text.trim(),
        type: _printerType,
        connectionType: _connectionType,
        stationCode: _selectedStations.first,
        windowsPrinterName: windowsPrinterName,
        ip: ip,
        port: port,
        btMac: btMac,
        copies: int.tryParse(_copiesController.text.trim()),
        paperSize: _paperSize,
        workstationId: workstationId,
      );

      await db.setPrinterStations(
        printerId: printerId,
        stationCodes: _selectedStations,
      );

      if (!mounted) return;
      Navigator.pop(context);
      AppFeedback.success(context, 'تم تحديث الطابعة بنجاح');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerTypeOptions = const <PosSelectOption<String>>[
      PosSelectOption(value: 'طابعة أقسام', label: 'طابعة أقسام'),
      PosSelectOption(value: 'مجمعه', label: 'مجمعه'),
    ];
    final connectionTypeOptions = const <PosSelectOption<String>>[
      PosSelectOption(value: 'WINDOWS', label: 'Windows'),
      PosSelectOption(value: 'NETWORK', label: 'شبكة'),
      PosSelectOption(value: 'BLUETOOTH', label: 'Bluetooth'),
      PosSelectOption(value: 'USB', label: 'USB'),
    ];
    final paperSizeOptions = const <PosSelectOption<int>>[
      PosSelectOption(value: 80, label: '80mm'),
      PosSelectOption(value: 210, label: 'A4'),
    ];

    final db = ref.watch(appDbProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: 720,
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
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text('تعديل الطابعة', style: AppTextStyles.topbarTitle),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _FieldColumn(
                        label: 'اسم الطابعة',
                        child: TextFormField(
                          controller: _nameController,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _fieldDecoration(
                            icon: Icons.badge_outlined,
                            showLabel: false,
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'الاسم مطلوب'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PosSelectField<String>(
                        label: 'نوع الطابعة',
                        hintText: 'اختر نوع الطابعة',
                        options: printerTypeOptions,
                        value: _printerType,
                        onChanged: (value) => setState(
                          () => _printerType = value ?? _printerType,
                        ),
                        leadingIcon: Icons.layers_outlined,
                        enableSearch: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PosSelectField<String>(
                        label: 'الاتصال',
                        hintText: 'اختر نوع الاتصال',
                        options: connectionTypeOptions,
                        value: _connectionType,
                        onChanged: (value) => setState(
                          () => _connectionType = value ?? _connectionType,
                        ),
                        leadingIcon: Icons.cable,
                        enableSearch: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_connectionType == 'WINDOWS')
                  FutureBuilder<List<String>>(
                    future: ref
                        .read(printerRepositoryProvider)
                        .listInstalledPrinters(),
                    builder: (context, snapshot) {
                      final installed = snapshot.data ?? const <String>[];
                      if (installed.isEmpty) {
                        return _FieldColumn(
                          label: 'اسم طابعة Windows',
                          child: TextFormField(
                            controller: _windowsNameController,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: _fieldDecoration(
                              icon: Icons.print_outlined,
                              showLabel: false,
                            ),
                            validator: (value) =>
                                (_connectionType == 'WINDOWS' &&
                                    (value == null || value.trim().isEmpty))
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                        );
                      }
                      final options = installed
                          .map(
                            (name) => PosSelectOption<String>(
                              value: name,
                              label: name,
                            ),
                          )
                          .toList();
                      return PosSelectField<String>(
                        label: 'طابعات Windows',
                        hintText: 'اختر طابعة',
                        options: options,
                        value: installed.contains(_windowsNameController.text)
                            ? _windowsNameController.text
                            : null,
                        onChanged: (value) => setState(
                          () => _windowsNameController.text = value ?? '',
                        ),
                        leadingIcon: Icons.print_outlined,
                        enableSearch: true,
                      );
                    },
                  ),
                if (_connectionType == 'NETWORK')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _FieldColumn(
                          label: 'عنوان IP',
                          child: TextFormField(
                            controller: _ipController,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: _fieldDecoration(
                              icon: Icons.router,
                              showLabel: false,
                            ),
                            validator: (value) =>
                                (_connectionType == 'NETWORK' &&
                                    (value == null || value.trim().isEmpty))
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _FieldColumn(
                          label: 'Port',
                          child: TextFormField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: _fieldDecoration(
                              icon: Icons.numbers,
                              showLabel: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_connectionType == 'BLUETOOTH')
                  _FieldColumn(
                    label: 'Bluetooth MAC',
                    child: TextFormField(
                      controller: _btController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: _fieldDecoration(
                        icon: Icons.bluetooth,
                        showLabel: false,
                      ),
                      validator: (value) =>
                          (_connectionType == 'BLUETOOTH' &&
                              (value == null || value.trim().isEmpty))
                          ? 'هذا الحقل مطلوب'
                          : null,
                    ),
                  ),
                if (_connectionType == 'USB')
                  Text(
                    'سيتم دعم تفاصيل USB لاحقاً (Vendor/Product/Serial)',
                    style: AppTextStyles.topbarInfo,
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PosSelectField<int>(
                        label: 'حجم الورق',
                        hintText: 'اختر حجم الورق',
                        options: paperSizeOptions,
                        value: _paperSize,
                        onChanged: (value) =>
                            setState(() => _paperSize = value ?? _paperSize),
                        leadingIcon: Icons.receipt_long,
                        enableSearch: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _FieldColumn(
                        label: 'عدد النسخ',
                        child: TextFormField(
                          controller: _copiesController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _fieldDecoration(
                            icon: Icons.copy,
                            showLabel: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                StreamBuilder<List<PrintStationDb>>(
                  stream: db.watchPrintStations(),
                  builder: (context, snapshot) {
                    final stations = snapshot.data ?? const <PrintStationDb>[];
                    if (stations.isEmpty) {
                      return const Text(
                        'أضف محطة طباعة أولاً لربط الطابعة بها',
                        style: AppTextStyles.topbarInfo,
                      );
                    }
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: stations.map((s) {
                        final isSelected = _selectedStations.contains(s.code);
                        return FilterChip(
                          label: Text('${s.name} (${s.code})'),
                          selected: isSelected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedStations.add(s.code);
                              } else {
                                _selectedStations.remove(s.code);
                              }
                            });
                          },
                          selectedColor: AppColors.selectSelected,
                          checkmarkColor: AppColors.primaryBlue,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
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
                          icon: const Icon(
                            Icons.save,
                            size: 18,
                            color: AppColors.white,
                          ),
                          label: Text(
                            _saving ? 'جاري الحفظ...' : 'حفظ التعديلات',
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
