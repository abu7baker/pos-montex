import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelShiftCreateScreen extends ConsumerStatefulWidget {
  const ControlPanelShiftCreateScreen({super.key});

  @override
  ConsumerState<ControlPanelShiftCreateScreen> createState() =>
      _ControlPanelShiftCreateScreenState();
}

class _ControlPanelShiftCreateScreenState
    extends ConsumerState<ControlPanelShiftCreateScreen> {
  static const String _requireOpeningCashKey = 'shift.require_opening_cash';
  static const String _allowMultipleOpenKey = 'shift.allow_multiple_open';
  static const String _autoClosePreviousKey = 'shift.auto_close_previous';
  static const String _shiftPrefixKey = 'shift.prefix';

  final _shiftNoController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _openedByController = TextEditingController();
  final _openingNoteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDefaults);
  }

  @override
  void dispose() {
    _shiftNoController.dispose();
    _openingBalanceController.dispose();
    _openedByController.dispose();
    _openingNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final db = ref.read(appDbProvider);
    final workstation = await db.getCurrentWorkstation();
    final openingCashRaw = (await db.getSetting('opening_cash_drawer'))?.trim();

    if (!mounted) return;
    setState(() {
      _openingBalanceController.text =
          (openingCashRaw == null || openingCashRaw.isEmpty)
          ? '0'
          : openingCashRaw;
      _openedByController.text = (workstation?.name.trim().isNotEmpty ?? false)
          ? workstation!.name
          : Platform.localHostname;
      _loading = false;
    });
  }

  Future<int> _ensureWorkstationId(AppDb db) async {
    var deviceId = await db.getSetting('device_id');
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await db.setSetting('device_id', deviceId);
    }
    return db.upsertWorkstation(
      deviceId: deviceId,
      name: Platform.localHostname,
    );
  }

  Future<ShiftDb?> _findOpenShift(AppDb db, int workstationId) {
    return (db.select(db.shifts)
          ..where(
            (t) =>
                t.status.equals('open') &
                t.closedAt.isNull() &
                t.workstationId.equals(workstationId),
          )
          ..orderBy([
            (t) => drift.OrderingTerm(
              expression: t.openedAt,
              mode: drift.OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  String _generateShiftNo(String prefix) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '$prefix-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  }

  Future<void> _closeShift(
    AppDb db,
    ShiftDb shift, {
    required String closedBy,
    String? note,
  }) {
    return (db.update(
      db.shifts,
    )..where((t) => t.localId.equals(shift.localId))).write(
      ShiftsCompanion(
        closedAt: drift.Value(DateTime.now()),
        closedBy: drift.Value(closedBy.trim().isEmpty ? null : closedBy.trim()),
        closingNote: drift.Value(
          note?.trim().isEmpty == true ? null : note?.trim(),
        ),
        status: const drift.Value('closed'),
        updatedAtLocal: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> _createNewShift() async {
    if (_saving) return;

    final db = ref.read(appDbProvider);
    final openingBalance =
        double.tryParse(_openingBalanceController.text.trim()) ?? 0;

    final requireOpening = _parseBool(
      await db.getSetting(_requireOpeningCashKey),
      fallback: true,
    );
    final allowMultiple = _parseBool(
      await db.getSetting(_allowMultipleOpenKey),
      fallback: false,
    );
    final autoClosePrevious = _parseBool(
      await db.getSetting(_autoClosePreviousKey),
      fallback: true,
    );

    if (requireOpening && openingBalance <= 0) {
      if (!mounted) return;
      AppFeedback.warning(context, 'الرجاء إدخال رصيد افتتاحي أكبر من صفر');
      return;
    }

    setState(() => _saving = true);
    try {
      final workstationId = await _ensureWorkstationId(db);
      final openShift = await _findOpenShift(db, workstationId);

      if (openShift != null && !allowMultiple) {
        if (autoClosePrevious) {
          await _closeShift(
            db,
            openShift,
            closedBy: _openedByController.text,
            note: 'إغلاق تلقائي عند فتح وردية جديدة',
          );
        } else {
          if (mounted) {
            AppFeedback.warning(
              context,
              'يوجد وردية مفتوحة حالياً. أغلقها أولاً قبل فتح وردية جديدة',
            );
          }
          return;
        }
      }

      final prefixRaw = (await db.getSetting(_shiftPrefixKey))?.trim();
      final prefix = prefixRaw == null || prefixRaw.isEmpty
          ? 'SHIFT'
          : prefixRaw;
      final shiftNo = _shiftNoController.text.trim().isEmpty
          ? _generateShiftNo(prefix)
          : _shiftNoController.text.trim();

      final newShiftId = await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              uuid: const Uuid().v4(),
              shiftNo: drift.Value(shiftNo),
              workstationId: drift.Value(workstationId),
              openedBy: drift.Value(
                _openedByController.text.trim().isEmpty
                    ? Platform.localHostname
                    : _openedByController.text.trim(),
              ),
              openingBalance: drift.Value(openingBalance),
              openingNote: drift.Value(
                _openingNoteController.text.trim().isEmpty
                    ? null
                    : _openingNoteController.text.trim(),
              ),
              openedAt: drift.Value(DateTime.now()),
              status: const drift.Value('open'),
              syncStatus: const drift.Value('PENDING'),
            ),
          );

      final openingValue = openingBalance.toStringAsFixed(2);
      await db.setSetting('current_shift_local_id', newShiftId.toString());
      await db.setSetting('opening_cash_drawer', openingValue);
      await db.setSetting('opening_cash', openingValue);
      await db.setSetting('shift_opening_cash', openingValue);
      await db.setSetting('cash_drawer_opening', openingValue);

      _shiftNoController.clear();
      _openingNoteController.clear();

      if (!mounted) return;
      AppFeedback.success(context, 'تم إنشاء الوردية بنجاح - رقم: $shiftNo');
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر إنشاء الوردية: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _closeCurrentOpenShift() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(appDbProvider);
      final workstationId = await _ensureWorkstationId(db);
      final openShift = await _findOpenShift(db, workstationId);

      if (openShift == null) {
        if (mounted) {
          AppFeedback.warning(context, 'لا توجد وردية مفتوحة حالياً');
        }
        return;
      }

      await _closeShift(
        db,
        openShift,
        closedBy: _openedByController.text,
        note: 'إغلاق يدوي من لوحة التحكم',
      );
      await db.setSetting('current_shift_local_id', null);

      if (!mounted) return;
      AppFeedback.success(context, 'تم إغلاق الوردية الحالية');
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر إغلاق الوردية: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);

    return ControlPanelShell(
      section: ControlPanelSection.shiftCreate,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
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
                    Icons.playlist_add_check,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'إنشاء وردية جديدة',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أنشئ وردية جديدة وحدد الرصيد الافتتاحي وبيانات المسؤول',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.75),
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
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.neutralGrey.withOpacity(0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'بيانات الوردية',
                    style: AppTextStyles.topbarTitle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _shiftNoController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'رقم الوردية (اختياري - تلقائي إذا فارغ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _openingBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _openedByController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'المستخدم المسؤول عن الفتح',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _openingNoteController,
                    textAlign: TextAlign.right,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة الافتتاح (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _createNewShift,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                            ),
                            icon: const Icon(Icons.add, color: AppColors.white),
                            label: Text(
                              _saving ? 'جاري التنفيذ...' : 'فتح وردية جديدة',
                              style: AppTextStyles.buttonTextStyle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _closeCurrentOpenShift,
                            icon: const Icon(Icons.lock_clock),
                            label: const Text('إغلاق الوردية المفتوحة'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FutureBuilder<int>(
              future: _ensureWorkstationId(db),
              builder: (context, workstationSnapshot) {
                final workstationId = workstationSnapshot.data;
                if (workstationId == null) {
                  return const SizedBox.shrink();
                }
                return FutureBuilder<ShiftDb?>(
                  future: _findOpenShift(db, workstationId),
                  builder: (context, snapshot) {
                    final openShift = snapshot.data;
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neutralGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'حالة الوردية الحالية',
                            style: AppTextStyles.topbarTitle,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (openShift == null)
                            const Text(
                              'لا توجد وردية مفتوحة حالياً',
                              style: AppTextStyles.fieldText,
                            )
                          else ...[
                            Text(
                              'رقم الوردية: ${openShift.shiftNo ?? openShift.localId}',
                              style: AppTextStyles.fieldText,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'افتتحت في: ${_formatDateTime(openShift.openedAt)}',
                              style: AppTextStyles.fieldText,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الرصيد الافتتاحي: ${openShift.openingBalance.toStringAsFixed(2)}',
                              style: AppTextStyles.fieldText,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'بواسطة: ${openShift.openedBy?.trim().isNotEmpty == true ? openShift.openedBy : '-'}',
                              style: AppTextStyles.fieldText,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutralGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('آخر الورديات', style: AppTextStyles.topbarTitle),
                  const SizedBox(height: AppSpacing.sm),
                  StreamBuilder<List<ShiftDb>>(
                    stream:
                        (db.select(db.shifts)
                              ..orderBy([
                                (t) => drift.OrderingTerm(
                                  expression: t.openedAt,
                                  mode: drift.OrderingMode.desc,
                                ),
                              ])
                              ..limit(10))
                            .watch(),
                    builder: (context, snapshot) {
                      final shifts = snapshot.data ?? const <ShiftDb>[];
                      if (shifts.isEmpty) {
                        return const Text(
                          'لا توجد ورديات محفوظة بعد',
                          style: AppTextStyles.fieldText,
                        );
                      }
                      return Column(
                        children: shifts.map((shift) {
                          final isOpen =
                              shift.status.trim().toLowerCase() == 'open' &&
                              shift.closedAt == null;
                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? AppColors.selectHover
                                  : AppColors.fieldBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.fieldBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${shift.shiftNo ?? shift.localId} | ${_formatDateTime(shift.openedAt)}',
                                    style: AppTextStyles.fieldText,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  isOpen ? 'مفتوحة' : 'مغلقة',
                                  style: AppTextStyles.topbarInfo,
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
            ),
          ],
        ],
      ),
    );
  }
}

bool _parseBool(String? raw, {required bool fallback}) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return fallback;
  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'off') {
    return false;
  }
  return fallback;
}
