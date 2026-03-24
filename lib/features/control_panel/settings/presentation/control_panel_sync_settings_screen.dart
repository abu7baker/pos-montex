import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../control_panel/presentation/control_panel_shell.dart';
import '../../../contacts/data/contacts_sync_service.dart';
import '../../../pos/data/sales_sync_service.dart';
import '../../../products/data/products_sync_service.dart';

class ControlPanelSyncSettingsScreen extends ConsumerStatefulWidget {
  const ControlPanelSyncSettingsScreen({super.key});

  @override
  ConsumerState<ControlPanelSyncSettingsScreen> createState() =>
      _ControlPanelSyncSettingsScreenState();
}

class _ControlPanelSyncSettingsScreenState
    extends ConsumerState<ControlPanelSyncSettingsScreen> {
  static const List<String> _syncStageMessages = <String>[
    'يتم تجهيز طلب المزامنة',
    'يتم الاتصال بالخادم',
    'يتم فحص البيانات',
    'يتم تحديث البيانات المحلية',
  ];

  bool _loadingSnapshot = true;
  bool _productsSyncing = false;
  int _productsCount = 0;
  int _lastProcessedCount = 0;
  DateTime? _lastProductsSyncAt;
  String? _productsError;
  String _productsStage = _syncStageMessages.first;
  Timer? _stageTimer;

  bool _contactsSyncing = false;
  int _customersCount = 0;
  int _lastContactsProcessedCount = 0;
  DateTime? _lastContactsSyncAt;
  String? _contactsError;
  String _contactsStage = _syncStageMessages.first;
  Timer? _contactsStageTimer;

  bool _salesSyncing = false;
  int _pendingSalesCount = 0;
  int _lastSalesSyncedCount = 0;
  int _lastSalesFailedCount = 0;
  int _lastSalesSkippedCount = 0;
  DateTime? _lastSalesSyncAt;
  String? _salesError;
  String _salesStage = _syncStageMessages.first;
  Timer? _salesStageTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadSnapshot);
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _contactsStageTimer?.cancel();
    _salesStageTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    if (!_loadingSnapshot && mounted) {
      setState(() => _loadingSnapshot = true);
    }

    try {
      final db = ref.read(appDbProvider);
      final lastSyncRaw = await db.getApiMeta('last_products_sync_at');
      final productsCount = (await db.getAllProducts()).length;
      final lastContactsRaw = await db.getApiMeta('last_contacts_sync_at');
      final customersCount = (await (db.select(db.customers)).get()).length;
      final lastSalesRaw = await db.getApiMeta('last_sales_sync_at');
      final salesRows = await (db.select(db.sales)).get();
      final pendingSalesCount = salesRows
          .where((sale) => sale.serverSaleId == null)
          .where(
            (sale) =>
                sale.syncStatus == 'PENDING' || sale.syncStatus == 'FAILED',
          )
          .where(
            (sale) => sale.status != 'QUOTATION' && sale.status != 'quotation',
          )
          .length;

      if (!mounted) return;
      setState(() {
        _productsCount = productsCount;
        _lastProductsSyncAt = DateTime.tryParse(lastSyncRaw ?? '');
        _customersCount = customersCount;
        _lastContactsSyncAt = DateTime.tryParse(lastContactsRaw ?? '');
        _pendingSalesCount = pendingSalesCount;
        _lastSalesSyncAt = DateTime.tryParse(lastSalesRaw ?? '');
        _loadingSnapshot = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSnapshot = false);
    }
  }

  Future<void> _syncProducts() async {
    if (_productsSyncing) return;

    _stageTimer?.cancel();
    var stageIndex = 0;

    setState(() {
      _productsSyncing = true;
      _productsError = null;
      _productsStage = _syncStageMessages.first;
    });

    _stageTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted || !_productsSyncing) return;
      stageIndex = (stageIndex + 1) % _syncStageMessages.length;
      setState(() => _productsStage = _syncStageMessages[stageIndex]);
    });

    try {
      final syncedCount = await ref
          .read(productsSyncServiceProvider)
          .syncProducts();
      await _loadSnapshot();
      if (!mounted) return;
      setState(() {
        _productsSyncing = false;
        _lastProcessedCount = syncedCount;
        _productsStage = syncedCount > 0
            ? 'اكتملت مزامنة المنتجات بنجاح'
            : 'اكتملت المزامنة ولا توجد تحديثات جديدة';
      });
      AppFeedback.success(
        context,
        syncedCount > 0
            ? 'اكتملت مزامنة المنتجات. تمت معالجة $syncedCount سجل.'
            : 'اكتملت المزامنة ولا توجد تحديثات جديدة.',
      );
    } catch (error) {
      final friendlyError = _formatOperationError(
        error,
        entityLabel: 'مزامنة المنتجات',
      );
      if (!mounted) return;
      setState(() {
        _productsSyncing = false;
        _productsError = friendlyError;
        _productsStage = 'تعذرت مزامنة المنتجات';
      });
      AppFeedback.error(context, friendlyError);
    } finally {
      _stageTimer?.cancel();
      _stageTimer = null;
    }
  }

  Future<void> _syncContacts() async {
    if (_contactsSyncing) return;

    _contactsStageTimer?.cancel();
    var stageIndex = 0;

    setState(() {
      _contactsSyncing = true;
      _contactsError = null;
      _contactsStage = _syncStageMessages.first;
    });

    _contactsStageTimer = Timer.periodic(const Duration(milliseconds: 1100), (
      _,
    ) {
      if (!mounted || !_contactsSyncing) return;
      stageIndex = (stageIndex + 1) % _syncStageMessages.length;
      setState(() => _contactsStage = _syncStageMessages[stageIndex]);
    });

    try {
      final syncedCount = await ref
          .read(contactsSyncServiceProvider)
          .syncContactsToCustomers();
      await ref
          .read(appDbProvider)
          .setApiMeta(
            'last_contacts_sync_at',
            DateTime.now().toIso8601String(),
          );
      await _loadSnapshot();
      if (!mounted) return;
      setState(() {
        _contactsSyncing = false;
        _lastContactsProcessedCount = syncedCount;
        _contactsStage = syncedCount > 0
            ? 'اكتملت مزامنة العملاء بنجاح'
            : 'اكتملت المزامنة ولا توجد تحديثات جديدة';
      });
      AppFeedback.success(
        context,
        syncedCount > 0
            ? 'اكتملت مزامنة العملاء. تمت معالجة $syncedCount سجل.'
            : 'اكتملت المزامنة ولا توجد تحديثات جديدة.',
      );
    } catch (error) {
      final friendlyError = _formatOperationError(
        error,
        entityLabel: 'مزامنة العملاء',
      );
      if (!mounted) return;
      setState(() {
        _contactsSyncing = false;
        _contactsError = friendlyError;
        _contactsStage = 'تعذرت مزامنة العملاء';
      });
      AppFeedback.error(context, friendlyError);
    } finally {
      _contactsStageTimer?.cancel();
      _contactsStageTimer = null;
    }
  }

  Future<void> _syncSales() async {
    if (_salesSyncing) return;

    _salesStageTimer?.cancel();
    var stageIndex = 0;

    setState(() {
      _salesSyncing = true;
      _salesError = null;
      _salesStage = _syncStageMessages.first;
    });

    _salesStageTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted || !_salesSyncing) return;
      stageIndex = (stageIndex + 1) % _syncStageMessages.length;
      setState(() => _salesStage = _syncStageMessages[stageIndex]);
    });

    try {
      final result = await ref
          .read(salesSyncServiceProvider)
          .syncPendingSales();
      await _loadSnapshot();
      if (!mounted) return;
      setState(() {
        _salesSyncing = false;
        _lastSalesSyncedCount = result.syncedCount;
        _lastSalesFailedCount = result.failedCount;
        _lastSalesSkippedCount = result.skippedCount;
        _salesStage = result.syncedCount > 0
            ? 'اكتمل رفع الفواتير بنجاح'
            : result.failedCount > 0
            ? 'اكتملت المحاولة مع وجود أخطاء'
            : 'لا توجد فواتير محلية جاهزة للرفع';
      });

      final message = result.syncedCount > 0 || result.failedCount > 0
          ? 'تم رفع ${result.syncedCount} فاتورة. فشل ${result.failedCount}. تم تجاوز ${result.skippedCount}.'
          : 'لا توجد فواتير محلية جاهزة للرفع.';

      if (result.failedCount > 0) {
        AppFeedback.error(context, message);
      } else {
        AppFeedback.success(context, message);
      }
    } catch (error) {
      final friendlyError = _formatOperationError(
        error,
        entityLabel: 'رفع الفواتير',
      );
      if (!mounted) return;
      setState(() {
        _salesSyncing = false;
        _salesError = friendlyError;
        _salesStage = 'تعذر رفع الفواتير';
      });
      AppFeedback.error(context, friendlyError);
    } finally {
      _salesStageTimer?.cancel();
      _salesStageTimer = null;
    }
  }

  // ignore: unused_element
  String _formatSyncError(Object error, {required String entityLabel}) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      final cleanMessage = message.substring('Exception: '.length).trim();
      if (cleanMessage.isNotEmpty) {
        return cleanMessage;
      }
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'انتهت صلاحية الجلسة مع الخادم. أعد تسجيل الدخول ثم حاول $entityLabel مرة أخرى.';
      }
      if (statusCode == 429) {
        return 'الخادم يرفض الطلبات مؤقتاً بسبب كثرة المحاولات. انتظر قليلاً ثم أعد المحاولة.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'الخادم غير متاح حالياً أو حدث خطأ داخلي. حاول مرة أخرى بعد قليل.';
      }

      final isNetworkIssue =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      if (isNetworkIssue) {
        return 'تعذر الاتصال بالخادم. تحقق من الإنترنت أو من إعدادات السيرفر ثم أعد المحاولة.';
      }
    }

    if (message.isNotEmpty) {
      return message;
    }

    return 'تعذرت مزامنة المنتجات حالياً. حاول مرة أخرى.';
  }

  String _formatOperationError(Object error, {required String entityLabel}) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      final cleanMessage = message.substring('Exception: '.length).trim();
      if (cleanMessage.isNotEmpty) {
        return cleanMessage;
      }
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'انتهت صلاحية الجلسة مع الخادم. أعد تسجيل الدخول ثم حاول $entityLabel مرة أخرى.';
      }
      if (statusCode == 429) {
        return 'الخادم يرفض الطلبات مؤقتاً بسبب كثرة المحاولات. انتظر قليلاً ثم أعد المحاولة.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'الخادم غير متاح حالياً أو حدث خطأ داخلي. حاول مرة أخرى بعد قليل.';
      }

      final isNetworkIssue =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      if (isNetworkIssue) {
        return 'تعذر الاتصال بالخادم. تحقق من الإنترنت أو من إعدادات السيرفر ثم أعد المحاولة.';
      }
    }

    if (message.isNotEmpty) {
      return message;
    }

    return 'تعذرت عملية المزامنة حالياً. حاول مرة أخرى.';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'لم تتم أي مزامنة بعد';
    return DateFormat('yyyy-MM-dd hh:mm a').format(value);
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.pillDarkBlue],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.white.withOpacity(0.22)),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  size: 30,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إعدادات المزامنة',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المزامنة اليدوية تمنحك تحكماً كاملاً. لن يبدأ جلب البيانات بعد تسجيل الدخول إلا عندما تطلبه أنت.',
                      style: TextStyle(
                        color: AppColors.white.withOpacity(0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.inventory_2_outlined,
              title: 'المنتجات المحلية',
              value: _loadingSnapshot ? '...' : _productsCount.toString(),
              accent: AppColors.topbarIconDeepBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MetricTile(
              icon: Icons.update_outlined,
              title: 'آخر مزامنة',
              value: _loadingSnapshot
                  ? '...'
                  : _formatDateTime(_lastProductsSyncAt),
              accent: AppColors.successGreen,
              compact: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MetricTile(
              icon: Icons.people_alt_outlined,
              title: 'العملاء المحليون',
              value: _loadingSnapshot ? '...' : _customersCount.toString(),
              accent: AppColors.pillPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    final statusColor = _productsError != null
        ? AppColors.dangerRed
        : _productsSyncing
        ? AppColors.topbarIconDeepBlue
        : AppColors.successGreen;

    final statusLabel = _productsError != null
        ? 'تحتاج مراجعة'
        : _productsSyncing
        ? 'جار التنفيذ'
        : 'جاهزة';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.topbarIconDeepBlue, AppColors.pillBlue],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_rounded,
                  color: AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مزامنة المنتجات',
                      style: AppTextStyles.topbarTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تشغيل يدوي لجلب المنتجات وتطبيق التغييرات من الخادم.',
                      style: AppTextStyles.fieldHint,
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _productsSyncing
                ? Column(
                    key: const ValueKey('syncing'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 8),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _productsStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: AppColors.topbarIconDeepBlue,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('idle'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _productsError?.trim().isNotEmpty == true
                            ? _productsError!
                            : _productsStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: _productsError != null
                              ? AppColors.dangerRed
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (_lastProcessedCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'آخر تشغيل عالج $_lastProcessedCount سجل.',
                          style: AppTextStyles.fieldHint,
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _productsSyncing ? null : _loadSnapshot,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تحديث الحالة'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _productsSyncing ? null : _syncProducts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: AnimatedRotation(
                    turns: _productsSyncing ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    child: Icon(
                      _productsSyncing
                          ? Icons.autorenew_rounded
                          : Icons.sync_rounded,
                      size: 18,
                    ),
                  ),
                  label: Text(
                    _productsSyncing
                        ? 'جار مزامنة المنتجات'
                        : 'بدء مزامنة المنتجات',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSyncCard() {
    final statusColor = _contactsError != null
        ? AppColors.dangerRed
        : _contactsSyncing
        ? AppColors.pillPurple
        : AppColors.successGreen;

    final statusLabel = _contactsError != null
        ? 'تحتاج مراجعة'
        : _contactsSyncing
        ? 'جار التنفيذ'
        : 'جاهزة';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.pillPurple, AppColors.pillPink],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مزامنة العملاء',
                      style: AppTextStyles.topbarTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تشغيل يدوي لجلب العملاء وتحديث قاعدة البيانات المحلية.',
                      style: AppTextStyles.fieldHint,
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _contactsSyncing
                ? Column(
                    key: const ValueKey('contacts_syncing'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 8),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _contactsStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: AppColors.pillPurple,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('contacts_idle'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _contactsError?.trim().isNotEmpty == true
                            ? _contactsError!
                            : _contactsStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: _contactsError != null
                              ? AppColors.dangerRed
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (_lastContactsProcessedCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'آخر تشغيل عالج $_lastContactsProcessedCount سجل.',
                          style: AppTextStyles.fieldHint,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'آخر مزامنة: ${_formatDateTime(_lastContactsSyncAt)}',
                        style: AppTextStyles.fieldHint,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _contactsSyncing ? null : _loadSnapshot,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تحديث الحالة'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _contactsSyncing ? null : _syncContacts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pillPurple,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: AnimatedRotation(
                    turns: _contactsSyncing ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    child: Icon(
                      _contactsSyncing
                          ? Icons.autorenew_rounded
                          : Icons.sync_rounded,
                      size: 18,
                    ),
                  ),
                  label: Text(
                    _contactsSyncing
                        ? 'جار مزامنة العملاء'
                        : 'بدء مزامنة العملاء',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          SizedBox(
            width: 220,
            child: _MetricTile(
              icon: Icons.inventory_2_outlined,
              title: 'المنتجات المحلية',
              value: _loadingSnapshot ? '...' : _productsCount.toString(),
              accent: AppColors.topbarIconDeepBlue,
            ),
          ),
          SizedBox(
            width: 220,
            child: _MetricTile(
              icon: Icons.update_outlined,
              title: 'آخر مزامنة منتجات',
              value: _loadingSnapshot
                  ? '...'
                  : _formatDateTime(_lastProductsSyncAt),
              accent: AppColors.successGreen,
              compact: true,
            ),
          ),
          SizedBox(
            width: 220,
            child: _MetricTile(
              icon: Icons.people_alt_outlined,
              title: 'العملاء المحليون',
              value: _loadingSnapshot ? '...' : _customersCount.toString(),
              accent: AppColors.pillPurple,
            ),
          ),
          SizedBox(
            width: 220,
            child: _MetricTile(
              icon: Icons.receipt_long_outlined,
              title: 'فواتير جاهزة للرفع',
              value: _loadingSnapshot ? '...' : _pendingSalesCount.toString(),
              accent: AppColors.topbarIconOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSyncCard() {
    final statusColor = _salesError != null
        ? AppColors.dangerRed
        : _salesSyncing
        ? AppColors.topbarIconOrange
        : AppColors.successGreen;

    final statusLabel = _salesError != null
        ? 'تحتاج مراجعة'
        : _salesSyncing
        ? 'جار التنفيذ'
        : 'جاهزة';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.topbarIconOrange,
                      AppColors.topbarPrayer,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رفع الفواتير',
                      style: AppTextStyles.topbarTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'يرفع المبيعات المحلية غير المرفوعة إلى مسار البيع في السيرفر عند توفر الاتصال.',
                      style: AppTextStyles.fieldHint,
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _salesSyncing
                ? Column(
                    key: const ValueKey('sales_syncing'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 8),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _salesStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: AppColors.topbarIconOrange,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('sales_idle'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _salesError?.trim().isNotEmpty == true
                            ? _salesError!
                            : _salesStage,
                        style: AppTextStyles.fieldText.copyWith(
                          color: _salesError != null
                              ? AppColors.dangerRed
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الفواتير الجاهزة الآن: $_pendingSalesCount',
                        style: AppTextStyles.fieldHint,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'آخر رفع: ${_formatDateTime(_lastSalesSyncAt)}',
                        style: AppTextStyles.fieldHint,
                      ),
                      if (_lastSalesSyncedCount > 0 ||
                          _lastSalesFailedCount > 0 ||
                          _lastSalesSkippedCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'آخر تشغيل: نجح $_lastSalesSyncedCount، فشل $_lastSalesFailedCount، تم تجاوز $_lastSalesSkippedCount.',
                          style: AppTextStyles.fieldHint,
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _salesSyncing ? null : _loadSnapshot,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تحديث الحالة'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _salesSyncing ? null : _syncSales,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.topbarIconOrange,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: AnimatedRotation(
                    turns: _salesSyncing ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    child: Icon(
                      _salesSyncing
                          ? Icons.autorenew_rounded
                          : Icons.cloud_upload_rounded,
                      size: 18,
                    ),
                  ),
                  label: Text(
                    _salesSyncing ? 'جار رفع الفواتير' : 'بدء رفع الفواتير',
                    style: AppTextStyles.buttonTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ControlPanelShell(
      section: ControlPanelSection.settingsSync,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHero(),
          const SizedBox(height: AppSpacing.lg),
          _buildOverviewSection(),
          const SizedBox(height: AppSpacing.lg),
          _buildSyncCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildContactsSyncCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildSalesSyncCard(),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: AppTextStyles.fieldHint)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.fieldText.copyWith(
              fontSize: compact ? 13 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.fieldHint.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
