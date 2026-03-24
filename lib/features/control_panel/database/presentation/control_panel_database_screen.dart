import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../presentation/control_panel_shell.dart';

class ControlPanelDatabaseScreen extends ConsumerWidget {
  const ControlPanelDatabaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDbProvider);

    return ControlPanelShell(
      section: ControlPanelSection.database,
      child: _DatabaseOverview(db: db),
    );
  }
}

class _DatabaseOverview extends StatefulWidget {
  const _DatabaseOverview({required this.db});

  final AppDb db;

  @override
  State<_DatabaseOverview> createState() => _DatabaseOverviewState();
}

class _DatabaseOverviewState extends State<_DatabaseOverview> {
  bool _clearing = false;
  int? _expandedTableIndex;

  AppDb get db => widget.db;

  Future<void> _confirmAndClear(BuildContext context) async {
    if (_clearing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تفريغ قاعدة البيانات'),
          content: const Text(
            'سيتم حذف جميع البيانات من قاعدة البيانات بما في ذلك المنتجات والمبيعات والإعدادات. '
            'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
              child: const Text('حذف الكل'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    try {
      await db.clearAllData();
      if (!mounted) return;
      AppFeedback.success(context, 'تم تفريغ قاعدة البيانات بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'تعذر تفريغ قاعدة البيانات: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tables = <_TableDefinition>[
      _TableDefinition(
        title: 'Products',
        subtitle: 'المنتجات',
        icon: Icons.inventory_2_outlined,
        color: AppColors.topbarIconBlue,
        columns: const [
          _ColumnMeta('id', 'int', 'PK'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('description', 'text', 'NULL'),
          _ColumnMeta('price', 'real', 'DEFAULT 0'),
          _ColumnMeta('stock', 'int', 'DEFAULT 0'),
          _ColumnMeta('category_id', 'int', 'FK'),
          _ColumnMeta('brand_id', 'int', 'FK / NULL'),
          _ColumnMeta('image_path', 'text', 'NULL'),
          _ColumnMeta('image_data', 'blob', 'NULL'),
          _ColumnMeta('station_code', 'text', 'DEFAULT ""'),
          _ColumnMeta('is_active', 'bool', 'DEFAULT true'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at', 'datetime', 'NULL'),
        ],
        previewBuilder: () => _ProductsPreview(db: db),
      ),
      _TableDefinition(
        title: 'ProductCategories',
        subtitle: 'أقسام المنتجات',
        icon: Icons.category_outlined,
        color: AppColors.pillMutedPurple,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('description', 'text', 'NULL'),
          _ColumnMeta('station_code', 'text', 'NULL'),
          _ColumnMeta('image_path', 'text', 'NULL'),
          _ColumnMeta('is_active', 'bool', 'DEFAULT true'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _ProductCategoriesPreview(db: db),
      ),
      _TableDefinition(
        title: 'Settings',
        subtitle: 'الإعدادات',
        icon: Icons.settings_outlined,
        color: AppColors.topbarIconIndigo,
        columns: const [
          _ColumnMeta('key', 'text', 'PK'),
          _ColumnMeta('value', 'text', 'NULL'),
        ],
        previewBuilder: () => _SettingsPreview(db: db),
      ),
      _TableDefinition(
        title: 'InvoiceTemplates',
        subtitle: 'Invoice templates',
        icon: Icons.receipt_long,
        color: AppColors.pillBlue,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('paper_size', 'int', 'NOT NULL'),
          _ColumnMeta('is_default', 'bool', 'DEFAULT false'),
          _ColumnMeta('header_title', 'text', 'DEFAULT value'),
          _ColumnMeta('footer_text', 'text', 'NULL'),
          _ColumnMeta('logo_path', 'text', 'NULL'),
          _ColumnMeta('show_logo', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_header_name', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_branch_address', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_phone', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_vat', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_cr', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_invoice_no', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_date', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_customer', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_items_count', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_subtotal', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_discount', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_tax', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_total', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_amount_words', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_payment_label', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_paid', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_remaining', 'bool', 'DEFAULT true'),
          _ColumnMeta('show_qr', 'bool', 'DEFAULT true'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _InvoiceTemplatesPreview(db: db),
      ),
      _TableDefinition(
        title: 'ApiMeta',
        subtitle: 'بيانات الربط API',
        icon: Icons.api_outlined,
        color: AppColors.topbarIconDeepBlue,
        columns: const [
          _ColumnMeta('key', 'text', 'PK'),
          _ColumnMeta('value', 'text', 'NULL'),
        ],
        previewBuilder: () => _ApiMetaPreview(db: db),
      ),
      _TableDefinition(
        title: 'PrintStations',
        subtitle: 'محطات الطباعة',
        icon: Icons.print_outlined,
        color: AppColors.topbarIconOrange,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('code', 'text', 'UNIQUE'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
        ],
        previewBuilder: () => _PrintStationsPreview(db: db),
      ),
      _TableDefinition(
        title: 'Workstations',
        subtitle: 'أجهزة الكاشير',
        icon: Icons.devices_outlined,
        color: AppColors.pillMutedPurple,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('device_id', 'text', 'UNIQUE'),
          _ColumnMeta('name', 'text', 'DEFAULT ""'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('last_seen_at', 'datetime', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _WorkstationsPreview(db: db),
      ),
      _TableDefinition(
        title: 'Printers',
        subtitle: 'الطابعات',
        icon: Icons.print,
        color: AppColors.pillPurple,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('type', 'text', 'NOT NULL'),
          _ColumnMeta('station_code', 'text', 'FK'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('workstation_id', 'int', 'FK'),
          _ColumnMeta('connection_type', 'text', 'DEFAULT WINDOWS'),
          _ColumnMeta('ip', 'text', 'NULL'),
          _ColumnMeta('port', 'int', 'DEFAULT 9100'),
          _ColumnMeta('windows_printer_name', 'text', 'NULL'),
          _ColumnMeta('bt_mac', 'text', 'NULL'),
          _ColumnMeta('usb_vendor_id', 'int', 'NULL'),
          _ColumnMeta('usb_product_id', 'int', 'NULL'),
          _ColumnMeta('usb_serial', 'text', 'NULL'),
          _ColumnMeta('paper_size', 'int', 'DEFAULT 80'),
          _ColumnMeta('copies', 'int', 'DEFAULT 1'),
          _ColumnMeta('char_per_line', 'int', 'NULL'),
          _ColumnMeta('code_page', 'text', 'NULL'),
          _ColumnMeta('capability_profile', 'text', 'NULL'),
          _ColumnMeta('cut_after_print', 'bool', 'DEFAULT true'),
          _ColumnMeta('open_cash_drawer', 'bool', 'DEFAULT false'),
          _ColumnMeta('enabled', 'bool', 'DEFAULT true'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('last_test_at', 'datetime', 'NULL'),
          _ColumnMeta('last_seen_at', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _PrintersPreview(db: db),
      ),
      _TableDefinition(
        title: 'PrinterStationMap',
        subtitle: 'ربط الطابعات بالمحطات',
        icon: Icons.link_outlined,
        color: AppColors.pillPink,
        columns: const [
          _ColumnMeta('workstation_id', 'int', 'FK'),
          _ColumnMeta('printer_id', 'int', 'PK / FK'),
          _ColumnMeta('station_code', 'text', 'PK'),
          _ColumnMeta('enabled', 'bool', 'DEFAULT true'),
        ],
        previewBuilder: () => _PrinterStationMapPreview(db: db),
      ),
      _TableDefinition(
        title: 'Sales',
        subtitle: 'المبيعات',
        icon: Icons.receipt_long,
        color: AppColors.pillBlue,
        columns: const [
          _ColumnMeta('local_id', 'int', 'PK AUTO'),
          _ColumnMeta('uuid', 'text', 'UNIQUE'),
          _ColumnMeta('server_sale_id', 'int', 'NULL'),
          _ColumnMeta('invoice_no', 'text', 'NULL'),
          _ColumnMeta('daily_order_no', 'int', 'DEFAULT 0'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('cashier_server_id', 'int', 'NULL'),
          _ColumnMeta('customer_id', 'int', 'FK / NULL'),
          _ColumnMeta('service_id', 'int', 'FK / NULL'),
          _ColumnMeta('service_name_snapshot', 'text', 'NULL'),
          _ColumnMeta('service_cost', 'real', 'DEFAULT 0'),
          _ColumnMeta('table_id', 'int', 'FK / NULL'),
          _ColumnMeta('table_name_snapshot', 'text', 'NULL'),
          _ColumnMeta('shift_local_id', 'int', 'FK / NULL'),
          _ColumnMeta('note', 'text', 'NULL'),
          _ColumnMeta('items_count', 'int', 'DEFAULT 0'),
          _ColumnMeta('subtotal', 'real', 'DEFAULT 0'),
          _ColumnMeta('tax', 'real', 'DEFAULT 0'),
          _ColumnMeta('discount', 'real', 'DEFAULT 0'),
          _ColumnMeta('paid_total', 'real', 'DEFAULT 0'),
          _ColumnMeta('remaining', 'real', 'DEFAULT 0'),
          _ColumnMeta('total', 'real', 'NOT NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT queued'),
          _ColumnMeta('sync_status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_error', 'text', 'NULL'),
          _ColumnMeta('synced_at', 'datetime', 'NULL'),
          _ColumnMeta('zatca_status', 'text', 'NULL'),
          _ColumnMeta('zatca_response', 'text', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('completed_at_local', 'datetime', 'NULL'),
        ],
        previewBuilder: () => _SalesPreview(db: db),
      ),
      _TableDefinition(
        title: 'SaleItems',
        subtitle: 'عناصر المبيعات',
        icon: Icons.list_alt,
        color: AppColors.pillRed,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('sale_local_id', 'int', 'FK'),
          _ColumnMeta('product_id', 'int', 'FK'),
          _ColumnMeta('category_id', 'int', 'FK / NULL'),
          _ColumnMeta('category_name_snapshot', 'text', 'NULL'),
          _ColumnMeta('server_product_id', 'int', 'NULL'),
          _ColumnMeta('name_snapshot', 'text', 'DEFAULT ""'),
          _ColumnMeta('qty', 'int', 'NOT NULL'),
          _ColumnMeta('price', 'real', 'NOT NULL'),
          _ColumnMeta('total', 'real', 'DEFAULT 0'),
          _ColumnMeta('station_code', 'text', 'DEFAULT ""'),
          _ColumnMeta('note', 'text', 'NULL'),
        ],
        previewBuilder: () => _SaleItemsPreview(db: db),
      ),
      _TableDefinition(
        title: 'SalePayments',
        subtitle: 'مدفوعات المبيعات',
        icon: Icons.payments_outlined,
        color: AppColors.topbarIconDeepBlue,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('sale_local_id', 'int', 'FK'),
          _ColumnMeta('server_payment_id', 'int', 'NULL'),
          _ColumnMeta('method_code', 'text', 'NOT NULL'),
          _ColumnMeta('amount', 'real', 'NOT NULL'),
          _ColumnMeta('reference', 'text', 'NULL'),
          _ColumnMeta('note', 'text', 'NULL'),
        ],
        previewBuilder: () => _SalePaymentsPreview(db: db),
      ),
      _TableDefinition(
        title: 'Customers',
        subtitle: 'Customers',
        icon: Icons.people_outline,
        color: AppColors.topbarIconIndigo,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('code', 'text', 'NULL'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('activity', 'text', 'NULL'),
          _ColumnMeta('mobile', 'text', 'NOT NULL'),
          _ColumnMeta('mobile_alt', 'text', 'NULL'),
          _ColumnMeta('phone', 'text', 'NULL'),
          _ColumnMeta('email', 'text', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _CustomersPreview(db: db),
      ),
      _TableDefinition(
        title: 'PrintJobs',
        subtitle: 'مهام الطباعة',
        icon: Icons.print_disabled_outlined,
        color: AppColors.warningPurple,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('sale_local_id', 'int', 'FK'),
          _ColumnMeta('station_code', 'text', 'NOT NULL'),
          _ColumnMeta('printer_id', 'int', 'NULL'),
          _ColumnMeta('job_type', 'text', 'NOT NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('tries', 'int', 'DEFAULT 0'),
          _ColumnMeta('last_error', 'text', 'NULL'),
          _ColumnMeta('payload', 'text', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
          _ColumnMeta('printed_at', 'datetime', 'NULL'),
        ],
        previewBuilder: () => _PrintJobsPreview(db: db),
      ),
      _TableDefinition(
        title: 'SyncQueue',
        subtitle: 'طابور المزامنة',
        icon: Icons.sync_alt,
        color: AppColors.topbarIconRed,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('entity_type', 'text', 'NOT NULL'),
          _ColumnMeta('entity_local_id', 'int', 'NOT NULL'),
          _ColumnMeta('action', 'text', 'NOT NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('tries', 'int', 'DEFAULT 0'),
          _ColumnMeta('last_error', 'text', 'NULL'),
          _ColumnMeta('next_retry_at', 'datetime', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _SyncQueuePreview(db: db),
      ),
      _TableDefinition(
        title: 'Shifts',
        subtitle: 'الورديات',
        icon: Icons.schedule,
        color: AppColors.topbarIconDeepBlue,
        columns: const [
          _ColumnMeta('local_id', 'int', 'PK AUTO'),
          _ColumnMeta('uuid', 'text', 'UNIQUE'),
          _ColumnMeta('server_shift_id', 'int', 'NULL'),
          _ColumnMeta('shift_no', 'text', 'NULL'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('cashier_server_id', 'int', 'NULL'),
          _ColumnMeta('workstation_id', 'int', 'FK / NULL'),
          _ColumnMeta('opened_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('opened_by', 'text', 'NULL'),
          _ColumnMeta('opening_balance', 'real', 'DEFAULT 0'),
          _ColumnMeta('opening_note', 'text', 'NULL'),
          _ColumnMeta('closed_at', 'datetime', 'NULL'),
          _ColumnMeta('closed_by', 'text', 'NULL'),
          _ColumnMeta('closing_note', 'text', 'NULL'),
          _ColumnMeta('actual_cash', 'real', 'DEFAULT 0'),
          _ColumnMeta('status', 'text', 'DEFAULT open'),
          _ColumnMeta('sync_status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_error', 'text', 'NULL'),
          _ColumnMeta('synced_at', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _ShiftsPreview(db: db),
      ),
      _TableDefinition(
        title: 'Services',
        subtitle: 'الخدمات',
        icon: Icons.room_service_outlined,
        color: AppColors.pillBlue,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('description', 'text', 'NULL'),
          _ColumnMeta('cost', 'real', 'DEFAULT 0'),
          _ColumnMeta('is_active', 'bool', 'DEFAULT true'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _ServicesPreview(db: db),
      ),
      _TableDefinition(
        title: 'Tables',
        subtitle: 'طاولات المطعم',
        icon: Icons.table_restaurant,
        color: AppColors.topbarIconOrange,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('code', 'text', 'UNIQUE / NULL'),
          _ColumnMeta('capacity', 'int', 'DEFAULT 0'),
          _ColumnMeta('sort_order', 'int', 'DEFAULT 0'),
          _ColumnMeta('is_active', 'bool', 'DEFAULT true'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _PosTablesPreview(db: db),
      ),
      _TableDefinition(
        title: 'Brands',
        subtitle: 'العلامات التجارية',
        icon: Icons.workspace_premium_outlined,
        color: AppColors.pillMutedPurple,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('server_id', 'int', 'NULL'),
          _ColumnMeta('name', 'text', 'NOT NULL'),
          _ColumnMeta('description', 'text', 'NULL'),
          _ColumnMeta('image_path', 'text', 'NULL'),
          _ColumnMeta('is_active', 'bool', 'DEFAULT true'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
          _ColumnMeta('deleted_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_server', 'datetime', 'NULL'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _BrandsPreview(db: db),
      ),
      _TableDefinition(
        title: 'ReceiptVouchers',
        subtitle: 'سندات القبض',
        icon: Icons.receipt,
        color: AppColors.pillPink,
        columns: const [
          _ColumnMeta('local_id', 'int', 'PK AUTO'),
          _ColumnMeta('uuid', 'text', 'UNIQUE'),
          _ColumnMeta('server_voucher_id', 'int', 'NULL'),
          _ColumnMeta('voucher_no', 'text', 'NULL'),
          _ColumnMeta('shift_local_id', 'int', 'FK / NULL'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('cashier_server_id', 'int', 'NULL'),
          _ColumnMeta('customer_id', 'int', 'FK / NULL'),
          _ColumnMeta('amount', 'real', 'NOT NULL'),
          _ColumnMeta('payment_method_code', 'text', 'DEFAULT ""'),
          _ColumnMeta('reference', 'text', 'NULL'),
          _ColumnMeta('note', 'text', 'NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT ACTIVE'),
          _ColumnMeta('sync_status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_error', 'text', 'NULL'),
          _ColumnMeta('synced_at', 'datetime', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
        ],
        previewBuilder: () => _ReceiptVouchersPreview(db: db),
      ),
      _TableDefinition(
        title: 'PaymentVouchers',
        subtitle: 'سندات الصرف',
        icon: Icons.payments_outlined,
        color: AppColors.warningPurple,
        columns: const [
          _ColumnMeta('local_id', 'int', 'PK AUTO'),
          _ColumnMeta('uuid', 'text', 'UNIQUE'),
          _ColumnMeta('server_voucher_id', 'int', 'NULL'),
          _ColumnMeta('voucher_no', 'text', 'NULL'),
          _ColumnMeta('shift_local_id', 'int', 'FK / NULL'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('cashier_server_id', 'int', 'NULL'),
          _ColumnMeta('amount', 'real', 'NOT NULL'),
          _ColumnMeta('expense_type', 'text', 'DEFAULT ""'),
          _ColumnMeta('reference', 'text', 'NULL'),
          _ColumnMeta('note', 'text', 'NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT ACTIVE'),
          _ColumnMeta('sync_status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_error', 'text', 'NULL'),
          _ColumnMeta('synced_at', 'datetime', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
          _ColumnMeta('is_deleted', 'bool', 'DEFAULT false'),
        ],
        previewBuilder: () => _PaymentVouchersPreview(db: db),
      ),
      _TableDefinition(
        title: 'SalesReturns',
        subtitle: 'مرتجعات المبيعات',
        icon: Icons.assignment_return_outlined,
        color: AppColors.topbarIconRed,
        columns: const [
          _ColumnMeta('local_id', 'int', 'PK AUTO'),
          _ColumnMeta('uuid', 'text', 'UNIQUE'),
          _ColumnMeta('server_return_id', 'int', 'NULL'),
          _ColumnMeta('return_no', 'text', 'NULL'),
          _ColumnMeta('original_sale_local_id', 'int', 'FK / NULL'),
          _ColumnMeta('shift_local_id', 'int', 'FK / NULL'),
          _ColumnMeta('branch_server_id', 'int', 'NULL'),
          _ColumnMeta('cashier_server_id', 'int', 'NULL'),
          _ColumnMeta('subtotal', 'real', 'DEFAULT 0'),
          _ColumnMeta('tax', 'real', 'DEFAULT 0'),
          _ColumnMeta('discount', 'real', 'DEFAULT 0'),
          _ColumnMeta('total', 'real', 'DEFAULT 0'),
          _ColumnMeta('reason', 'text', 'NULL'),
          _ColumnMeta('status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_status', 'text', 'DEFAULT PENDING'),
          _ColumnMeta('sync_error', 'text', 'NULL'),
          _ColumnMeta('synced_at', 'datetime', 'NULL'),
          _ColumnMeta('created_at', 'datetime', 'DEFAULT now'),
          _ColumnMeta('updated_at_local', 'datetime', 'DEFAULT now'),
        ],
        previewBuilder: () => _SalesReturnsPreview(db: db),
      ),
      _TableDefinition(
        title: 'SalesReturnItems',
        subtitle: 'تفاصيل مرتجعات المبيعات',
        icon: Icons.reorder_outlined,
        color: AppColors.controlPanelHeaderBlue,
        columns: const [
          _ColumnMeta('id', 'int', 'PK AUTO'),
          _ColumnMeta('return_local_id', 'int', 'FK'),
          _ColumnMeta('product_id', 'int', 'FK'),
          _ColumnMeta('server_product_id', 'int', 'NULL'),
          _ColumnMeta('name_snapshot', 'text', 'DEFAULT ""'),
          _ColumnMeta('qty', 'int', 'NOT NULL'),
          _ColumnMeta('price', 'real', 'NOT NULL'),
          _ColumnMeta('total', 'real', 'DEFAULT 0'),
          _ColumnMeta('note', 'text', 'NULL'),
        ],
        previewBuilder: () => _SalesReturnItemsPreview(db: db),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.controlPanelHeaderBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storage_rounded,
                  color: AppColors.controlPanelHeaderBlue,
                ),
              ),
              title: const Text(
                'Montex POS (SQLite)',
                style: AppTextStyles.topbarTitle,
              ),
              subtitle: const Text(
                'قاعدة البيانات',
                style: AppTextStyles.topbarInfo,
              ),
              children: [
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Text('الجداول', style: AppTextStyles.topbarTitle),
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _clearing
                            ? null
                            : () => _confirmAndClear(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dangerRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(
                          Icons.delete_forever,
                          size: 16,
                          color: AppColors.white,
                        ),
                        label: Text(
                          _clearing
                              ? 'جارٍ التفريغ...'
                              : 'تفريغ قاعدة البيانات',
                          style: AppTextStyles.buttonTextStyle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ...tables.asMap().entries.map(
                  (entry) => _TableTile(
                    definition: entry.value,
                    isExpanded: _expandedTableIndex == entry.key,
                    onExpansionChanged: (expanded) {
                      setState(
                        () => _expandedTableIndex = expanded ? entry.key : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TableDefinition {
  const _TableDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.columns,
    required this.previewBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_ColumnMeta> columns;
  final Widget Function() previewBuilder;
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.definition,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  final _TableDefinition definition;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('${definition.title}_$isExpanded'),
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: definition.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(definition.icon, color: definition.color),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    definition.title,
                    style: AppTextStyles.topbarTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.selectHover,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'عرض البيانات',
                    style: AppTextStyles.topbarInfo,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              definition.subtitle,
              style: AppTextStyles.topbarInfo,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              const SizedBox(height: AppSpacing.sm),
              _ColumnsTable(columns: definition.columns),
              const SizedBox(height: AppSpacing.md),
              definition.previewBuilder(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnsTable extends StatelessWidget {
  const _ColumnsTable({required this.columns});

  final List<_ColumnMeta> columns;

  @override
  Widget build(BuildContext context) {
    final minWidth = columns.length * 120.0 < 520
        ? 520.0
        : columns.length * 120.0;
    const headingRowHeight = 36.0;
    const dataRowHeight = 36.0;
    final tableHeight = headingRowHeight + (columns.length * dataRowHeight) + 2;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          height: tableHeight,
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowHeight: headingRowHeight,
            dataRowHeight: dataRowHeight,
            columns: const [
              DataColumn2(label: Text('العمود'), size: ColumnSize.L),
              DataColumn2(label: Text('النوع'), fixedWidth: 140),
              DataColumn2(label: Text('الخصائص'), size: ColumnSize.L),
            ],
            rows: columns
                .map(
                  (c) => DataRow(
                    cells: [
                      DataCell(Text(c.name)),
                      DataCell(Text(c.type)),
                      DataCell(Text(c.flags)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ColumnMeta {
  const _ColumnMeta(this.name, this.type, this.flags);

  final String name;
  final String type;
  final String flags;
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final minWidth = columns.length * 140.0 < 520
        ? 520.0
        : columns.length * 140.0;
    const headingRowHeight = 36.0;
    const dataRowHeight = 36.0;
    final visibleRows = rows.isEmpty ? 1 : rows.length;
    final tableHeight = headingRowHeight + (visibleRows * dataRowHeight) + 2;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralGrey.withOpacity(0.6)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          height: tableHeight,
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowHeight: headingRowHeight,
            dataRowHeight: dataRowHeight,
            columns: columns.map((c) => DataColumn2(label: Text(c))).toList(),
            rows: rows
                .map(
                  (r) =>
                      DataRow(cells: r.map((v) => DataCell(Text(v))).toList()),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ProductsPreview extends StatelessWidget {
  const _ProductsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductDb>>(
      future: (db.select(db.products)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ProductDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'server_id',
            'name',
            'description',
            'price',
            'stock',
            'category_id',
            'brand_id',
            'image_path',
            'image_data',
            'station_code',
            'is_active',
            'is_deleted',
            'deleted_at_server',
            'updated_at_server',
            'updated_at',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.serverId?.toString() ?? '-',
                  r.name,
                  r.description ?? '-',
                  r.price.toStringAsFixed(2),
                  r.stock.toString(),
                  r.categoryId?.toString() ?? '-',
                  r.brandId?.toString() ?? '-',
                  r.imagePath ?? '-',
                  r.imageData?.length.toString() ?? '-',
                  r.stationCode,
                  r.isActive ? 'true' : 'false',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.updatedAt?.toIso8601String() ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SettingDb>>(
      future: (db.select(db.settings)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SettingDb>[];
        return _PreviewTable(
          columns: const ['key', 'value'],
          rows: rows.map((r) => [r.key, r.value ?? '-']).toList(),
        );
      },
    );
  }
}

class _InvoiceTemplatesPreview extends StatelessWidget {
  const _InvoiceTemplatesPreview({required this.db});
  final AppDb db;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvoiceTemplateDb>>(
      future: (db.select(db.invoiceTemplates)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <InvoiceTemplateDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'name',
            'paper_size',
            'is_default',
            'header_title',
            'footer_text',
            'logo_path',
            'show_logo',
            'show_header_name',
            'show_branch_address',
            'show_phone',
            'show_vat',
            'show_cr',
            'show_invoice_no',
            'show_date',
            'show_customer',
            'show_items_count',
            'show_subtotal',
            'show_discount',
            'show_tax',
            'show_total',
            'show_amount_words',
            'show_payment_label',
            'show_paid',
            'show_remaining',
            'show_qr',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.name,
                  r.paperSize.toString(),
                  r.isDefault ? 'true' : 'false',
                  r.headerTitle,
                  r.footerText ?? '-',
                  r.logoPath ?? '-',
                  r.showLogo ? 'true' : 'false',
                  r.showHeaderName ? 'true' : 'false',
                  r.showBranchAddress ? 'true' : 'false',
                  r.showPhone ? 'true' : 'false',
                  r.showVat ? 'true' : 'false',
                  r.showCr ? 'true' : 'false',
                  r.showInvoiceNo ? 'true' : 'false',
                  r.showDate ? 'true' : 'false',
                  r.showCustomer ? 'true' : 'false',
                  r.showItemsCount ? 'true' : 'false',
                  r.showSubtotal ? 'true' : 'false',
                  r.showDiscount ? 'true' : 'false',
                  r.showTax ? 'true' : 'false',
                  r.showTotal ? 'true' : 'false',
                  r.showAmountWords ? 'true' : 'false',
                  r.showPaymentLabel ? 'true' : 'false',
                  r.showPaid ? 'true' : 'false',
                  r.showRemaining ? 'true' : 'false',
                  r.showQr ? 'true' : 'false',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _ApiMetaPreview extends StatelessWidget {
  const _ApiMetaPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApiMetaDb>>(
      future: (db.select(db.apiMeta)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ApiMetaDb>[];
        return _PreviewTable(
          columns: const ['key', 'value'],
          rows: rows.map((r) => [r.key, r.value ?? '-']).toList(),
        );
      },
    );
  }
}

class _ProductCategoriesPreview extends StatelessWidget {
  const _ProductCategoriesPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductCategoryDb>>(
      future: (db.select(db.productCategories)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ProductCategoryDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'name',
            'description',
            'station_code',
            'image_path',
            'is_active',
            'server_id',
            'updated_at_server',
            'is_deleted',
            'deleted_at_server',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.name,
                  r.description ?? '-',
                  r.stationCode ?? '-',
                  r.imagePath ?? '-',
                  r.isActive ? 'true' : 'false',
                  r.serverId?.toString() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PrintStationsPreview extends StatelessWidget {
  const _PrintStationsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PrintStationDb>>(
      future: (db.select(db.printStations)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PrintStationDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'code',
            'name',
            'server_id',
            'updated_at_server',
            'is_deleted',
            'deleted_at_server',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.code,
                  r.name,
                  r.serverId?.toString() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _WorkstationsPreview extends StatelessWidget {
  const _WorkstationsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkstationDb>>(
      future: (db.select(db.workstations)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <WorkstationDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'device_id',
            'name',
            'server_id',
            'branch_server_id',
            'last_seen_at',
            'created_at',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.deviceId,
                  r.name,
                  r.serverId?.toString() ?? '-',
                  r.branchServerId?.toString() ?? '-',
                  r.lastSeenAt?.toIso8601String() ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PrintersPreview extends StatelessWidget {
  const _PrintersPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PrinterDb>>(
      future: (db.select(db.printers)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PrinterDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'name',
            'type',
            'station_code',
            'branch_server_id',
            'workstation_id',
            'connection_type',
            'ip',
            'port',
            'windows_printer_name',
            'bt_mac',
            'usb_vendor_id',
            'usb_product_id',
            'usb_serial',
            'paper_size',
            'copies',
            'char_per_line',
            'code_page',
            'capability_profile',
            'cut_after_print',
            'open_cash_drawer',
            'enabled',
            'is_deleted',
            'deleted_at_server',
            'server_id',
            'updated_at_server',
            'last_test_at',
            'last_seen_at',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.name,
                  r.type,
                  r.stationCode,
                  r.branchServerId?.toString() ?? '-',
                  r.workstationId?.toString() ?? '-',
                  r.connectionType,
                  r.ip ?? '-',
                  r.port.toString(),
                  r.windowsPrinterName ?? '-',
                  r.btMac ?? '-',
                  r.usbVendorId?.toString() ?? '-',
                  r.usbProductId?.toString() ?? '-',
                  r.usbSerial ?? '-',
                  r.paperSize.toString(),
                  r.copies.toString(),
                  r.charPerLine?.toString() ?? '-',
                  r.codePage ?? '-',
                  r.capabilityProfile ?? '-',
                  r.cutAfterPrint ? 'true' : 'false',
                  r.openCashDrawer ? 'true' : 'false',
                  r.enabled ? 'true' : 'false',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.serverId?.toString() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.lastTestAt?.toIso8601String() ?? '-',
                  r.lastSeenAt?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PrinterStationMapPreview extends StatelessWidget {
  const _PrinterStationMapPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PrinterStationMapDb>>(
      future: (db.select(db.printerStationMap)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PrinterStationMapDb>[];
        return _PreviewTable(
          columns: const [
            'workstation_id',
            'printer_id',
            'station_code',
            'enabled',
          ],
          rows: rows
              .map(
                (r) => [
                  r.workstationId?.toString() ?? '-',
                  r.printerId.toString(),
                  r.stationCode,
                  r.enabled ? 'true' : 'false',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SalesPreview extends StatelessWidget {
  const _SalesPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaleDb>>(
      future: (db.select(db.sales)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SaleDb>[];
        return _PreviewTable(
          columns: const [
            'local_id',
            'uuid',
            'server_sale_id',
            'invoice_no',
            'daily_order_no',
            'branch_server_id',
            'cashier_server_id',
            'customer_id',
            'service_id',
            'service_name_snapshot',
            'service_cost',
            'table_id',
            'table_name_snapshot',
            'shift_local_id',
            'note',
            'items_count',
            'subtotal',
            'tax',
            'discount',
            'paid_total',
            'remaining',
            'total',
            'status',
            'sync_status',
            'sync_error',
            'synced_at',
            'zatca_status',
            'zatca_response',
            'created_at',
            'completed_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.localId.toString(),
                  r.uuid,
                  r.serverSaleId?.toString() ?? '-',
                  r.invoiceNo ?? '-',
                  r.dailyOrderNo.toString(),
                  r.branchServerId?.toString() ?? '-',
                  r.cashierServerId?.toString() ?? '-',
                  r.customerId?.toString() ?? '-',
                  r.serviceId?.toString() ?? '-',
                  r.serviceNameSnapshot ?? '-',
                  r.serviceCost.toStringAsFixed(2),
                  r.tableId?.toString() ?? '-',
                  r.tableNameSnapshot ?? '-',
                  r.shiftLocalId?.toString() ?? '-',
                  r.note ?? '-',
                  r.itemsCount.toString(),
                  r.subtotal.toStringAsFixed(2),
                  r.tax.toStringAsFixed(2),
                  r.discount.toStringAsFixed(2),
                  r.paidTotal.toStringAsFixed(2),
                  r.remaining.toStringAsFixed(2),
                  r.total.toStringAsFixed(2),
                  r.status,
                  r.syncStatus,
                  r.syncError ?? '-',
                  r.syncedAt?.toIso8601String() ?? '-',
                  r.zatcaStatus ?? '-',
                  r.zatcaResponse ?? '-',
                  r.createdAt.toIso8601String(),
                  r.completedAtLocal?.toIso8601String() ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SaleItemsPreview extends StatelessWidget {
  const _SaleItemsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaleItemDb>>(
      future: (db.select(db.saleItems)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SaleItemDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'sale_local_id',
            'product_id',
            'category_id',
            'category_name_snapshot',
            'server_product_id',
            'name_snapshot',
            'qty',
            'price',
            'total',
            'station_code',
            'note',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.saleLocalId.toString(),
                  r.productId.toString(),
                  r.categoryId?.toString() ?? '-',
                  r.categoryNameSnapshot ?? '-',
                  r.serverProductId?.toString() ?? '-',
                  r.nameSnapshot,
                  r.qty.toString(),
                  r.price.toStringAsFixed(2),
                  r.total.toStringAsFixed(2),
                  r.stationCode,
                  r.note ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SalePaymentsPreview extends StatelessWidget {
  const _SalePaymentsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SalePaymentDb>>(
      future: (db.select(db.salePayments)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SalePaymentDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'sale_local_id',
            'server_payment_id',
            'method_code',
            'amount',
            'reference',
            'note',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.saleLocalId.toString(),
                  r.serverPaymentId?.toString() ?? '-',
                  r.methodCode,
                  r.amount.toStringAsFixed(2),
                  r.reference ?? '-',
                  r.note ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _CustomersPreview extends StatelessWidget {
  const _CustomersPreview({required this.db});
  final AppDb db;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerDb>>(
      future: (db.select(db.customers)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <CustomerDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'code',
            'name',
            'activity',
            'mobile',
            'mobile_alt',
            'phone',
            'email',
            'created_at',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.code ?? '-',
                  r.name,
                  r.activity ?? '-',
                  r.mobile,
                  r.mobileAlt ?? '-',
                  r.phone ?? '-',
                  r.email ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PrintJobsPreview extends StatelessWidget {
  const _PrintJobsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PrintJobDb>>(
      future: (db.select(db.printJobs)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PrintJobDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'sale_local_id',
            'station_code',
            'printer_id',
            'job_type',
            'status',
            'tries',
            'last_error',
            'payload',
            'created_at',
            'updated_at_local',
            'printed_at',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.saleLocalId.toString(),
                  r.stationCode,
                  r.printerId?.toString() ?? '-',
                  r.jobType,
                  r.status,
                  r.tries.toString(),
                  r.lastError ?? '-',
                  r.payload ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                  r.printedAt?.toIso8601String() ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SyncQueuePreview extends StatelessWidget {
  const _SyncQueuePreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SyncQueueDb>>(
      future: (db.select(db.syncQueue)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SyncQueueDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'entity_type',
            'entity_local_id',
            'action',
            'status',
            'tries',
            'last_error',
            'next_retry_at',
            'created_at',
            'updated_at',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.entityType,
                  r.entityLocalId.toString(),
                  r.action,
                  r.status,
                  r.tries.toString(),
                  r.lastError ?? '-',
                  r.nextRetryAt?.toIso8601String() ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAt.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _ShiftsPreview extends StatelessWidget {
  const _ShiftsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShiftDb>>(
      future: (db.select(db.shifts)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ShiftDb>[];
        return _PreviewTable(
          columns: const [
            'local_id',
            'uuid',
            'server_shift_id',
            'shift_no',
            'branch_server_id',
            'cashier_server_id',
            'workstation_id',
            'opened_at',
            'opened_by',
            'opening_balance',
            'opening_note',
            'closed_at',
            'closed_by',
            'closing_note',
            'actual_cash',
            'status',
            'sync_status',
            'sync_error',
            'synced_at',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.localId.toString(),
                  r.uuid,
                  r.serverShiftId?.toString() ?? '-',
                  r.shiftNo ?? '-',
                  r.branchServerId?.toString() ?? '-',
                  r.cashierServerId?.toString() ?? '-',
                  r.workstationId?.toString() ?? '-',
                  r.openedAt.toIso8601String(),
                  r.openedBy ?? '-',
                  r.openingBalance.toStringAsFixed(2),
                  r.openingNote ?? '-',
                  r.closedAt?.toIso8601String() ?? '-',
                  r.closedBy ?? '-',
                  r.closingNote ?? '-',
                  r.actualCash.toStringAsFixed(2),
                  r.status,
                  r.syncStatus,
                  r.syncError ?? '-',
                  r.syncedAt?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _ServicesPreview extends StatelessWidget {
  const _ServicesPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceDb>>(
      future: (db.select(db.services)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ServiceDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'server_id',
            'name',
            'description',
            'cost',
            'is_active',
            'is_deleted',
            'deleted_at_server',
            'updated_at_server',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.serverId?.toString() ?? '-',
                  r.name,
                  r.description ?? '-',
                  r.cost.toStringAsFixed(2),
                  r.isActive ? 'true' : 'false',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PosTablesPreview extends StatelessWidget {
  const _PosTablesPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PosTableDb>>(
      future: (db.select(db.posTables)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PosTableDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'server_id',
            'name',
            'code',
            'capacity',
            'sort_order',
            'is_active',
            'is_deleted',
            'deleted_at_server',
            'updated_at_server',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.serverId?.toString() ?? '-',
                  r.name,
                  r.code ?? '-',
                  r.capacity.toString(),
                  r.sortOrder.toString(),
                  r.isActive ? 'true' : 'false',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _BrandsPreview extends StatelessWidget {
  const _BrandsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BrandDb>>(
      future: (db.select(db.brands)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <BrandDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'server_id',
            'name',
            'description',
            'image_path',
            'is_active',
            'is_deleted',
            'deleted_at_server',
            'updated_at_server',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.serverId?.toString() ?? '-',
                  r.name,
                  r.description ?? '-',
                  r.imagePath ?? '-',
                  r.isActive ? 'true' : 'false',
                  r.isDeleted ? 'true' : 'false',
                  r.deletedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtServer?.toIso8601String() ?? '-',
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _ReceiptVouchersPreview extends StatelessWidget {
  const _ReceiptVouchersPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReceiptVoucherDb>>(
      future: (db.select(db.receiptVouchers)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <ReceiptVoucherDb>[];
        return _PreviewTable(
          columns: const [
            'local_id',
            'uuid',
            'server_voucher_id',
            'voucher_no',
            'shift_local_id',
            'branch_server_id',
            'cashier_server_id',
            'customer_id',
            'amount',
            'payment_method_code',
            'reference',
            'note',
            'status',
            'sync_status',
            'sync_error',
            'synced_at',
            'created_at',
            'updated_at_local',
            'is_deleted',
          ],
          rows: rows
              .map(
                (r) => [
                  r.localId.toString(),
                  r.uuid,
                  r.serverVoucherId?.toString() ?? '-',
                  r.voucherNo ?? '-',
                  r.shiftLocalId?.toString() ?? '-',
                  r.branchServerId?.toString() ?? '-',
                  r.cashierServerId?.toString() ?? '-',
                  r.customerId?.toString() ?? '-',
                  r.amount.toStringAsFixed(2),
                  r.paymentMethodCode,
                  r.reference ?? '-',
                  r.note ?? '-',
                  r.status,
                  r.syncStatus,
                  r.syncError ?? '-',
                  r.syncedAt?.toIso8601String() ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                  r.isDeleted ? 'true' : 'false',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _PaymentVouchersPreview extends StatelessWidget {
  const _PaymentVouchersPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentVoucherDb>>(
      future: (db.select(db.paymentVouchers)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <PaymentVoucherDb>[];
        return _PreviewTable(
          columns: const [
            'local_id',
            'uuid',
            'server_voucher_id',
            'voucher_no',
            'shift_local_id',
            'branch_server_id',
            'cashier_server_id',
            'amount',
            'expense_type',
            'reference',
            'note',
            'status',
            'sync_status',
            'sync_error',
            'synced_at',
            'created_at',
            'updated_at_local',
            'is_deleted',
          ],
          rows: rows
              .map(
                (r) => [
                  r.localId.toString(),
                  r.uuid,
                  r.serverVoucherId?.toString() ?? '-',
                  r.voucherNo ?? '-',
                  r.shiftLocalId?.toString() ?? '-',
                  r.branchServerId?.toString() ?? '-',
                  r.cashierServerId?.toString() ?? '-',
                  r.amount.toStringAsFixed(2),
                  r.expenseType,
                  r.reference ?? '-',
                  r.note ?? '-',
                  r.status,
                  r.syncStatus,
                  r.syncError ?? '-',
                  r.syncedAt?.toIso8601String() ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                  r.isDeleted ? 'true' : 'false',
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SalesReturnsPreview extends StatelessWidget {
  const _SalesReturnsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SalesReturnDb>>(
      future: (db.select(db.salesReturns)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SalesReturnDb>[];
        return _PreviewTable(
          columns: const [
            'local_id',
            'uuid',
            'server_return_id',
            'return_no',
            'original_sale_local_id',
            'shift_local_id',
            'branch_server_id',
            'cashier_server_id',
            'subtotal',
            'tax',
            'discount',
            'total',
            'reason',
            'status',
            'sync_status',
            'sync_error',
            'synced_at',
            'created_at',
            'updated_at_local',
          ],
          rows: rows
              .map(
                (r) => [
                  r.localId.toString(),
                  r.uuid,
                  r.serverReturnId?.toString() ?? '-',
                  r.returnNo ?? '-',
                  r.originalSaleLocalId?.toString() ?? '-',
                  r.shiftLocalId?.toString() ?? '-',
                  r.branchServerId?.toString() ?? '-',
                  r.cashierServerId?.toString() ?? '-',
                  r.subtotal.toStringAsFixed(2),
                  r.tax.toStringAsFixed(2),
                  r.discount.toStringAsFixed(2),
                  r.total.toStringAsFixed(2),
                  r.reason ?? '-',
                  r.status,
                  r.syncStatus,
                  r.syncError ?? '-',
                  r.syncedAt?.toIso8601String() ?? '-',
                  r.createdAt.toIso8601String(),
                  r.updatedAtLocal.toIso8601String(),
                ],
              )
              .toList(),
        );
      },
    );
  }
}

class _SalesReturnItemsPreview extends StatelessWidget {
  const _SalesReturnItemsPreview({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SalesReturnItemDb>>(
      future: (db.select(db.salesReturnItems)..limit(8)).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const <SalesReturnItemDb>[];
        return _PreviewTable(
          columns: const [
            'id',
            'return_local_id',
            'product_id',
            'server_product_id',
            'name_snapshot',
            'qty',
            'price',
            'total',
            'note',
          ],
          rows: rows
              .map(
                (r) => [
                  r.id.toString(),
                  r.returnLocalId.toString(),
                  r.productId.toString(),
                  r.serverProductId?.toString() ?? '-',
                  r.nameSnapshot,
                  r.qty.toString(),
                  r.price.toStringAsFixed(2),
                  r.total.toStringAsFixed(2),
                  r.note ?? '-',
                ],
              )
              .toList(),
        );
      },
    );
  }
}
