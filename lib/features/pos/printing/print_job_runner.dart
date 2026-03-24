import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../../core/printing/pdf_arabic_fonts.dart';
import '../presentation/cart_provider.dart';

final printJobRunnerProvider = Provider<PrintJobRunner>((ref) {
  final db = ref.watch(appDbProvider);
  final runner = PrintJobRunner(db);
  runner.start();
  ref.onDispose(runner.dispose);
  return runner;
});

class PrintJobRunner {
  PrintJobRunner(this._db);

  final AppDb _db;
  StreamSubscription<List<PrintJobDb>>? _subscription;
  final Set<int> _inFlight = <int>{};
  final Map<int, Future<void>> _printerChains = <int, Future<void>>{};
  bool _isProcessing = false;
  bool _needsRerun = false;

  static const int _maxTries = 3;
  static const int _paperSizeA4 = 210;
  static const double _fixedTaxRate = 0.15;
  static const double _thermalLogoSize = 90;
  static const double _a4LogoSize = 150;
  pw.Font? _currencySymbolFont;
  String _riyalSign = '\u20C1';

  void start() {
    _subscription ??= _db.watchPendingPrintJobs().listen((jobs) {
      _handleJobs(jobs);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleJobs(List<PrintJobDb> jobs) async {
    if (_isProcessing) {
      _needsRerun = true;
      return;
    }
    _isProcessing = true;
    try {
      final pending = jobs
          .where((job) => job.status != 'PRINTED')
          .where((job) => job.tries < _maxTries)
          .where((job) => !_inFlight.contains(job.id))
          .toList();
      if (pending.isEmpty) return;

      final futures = <Future<void>>[];
      for (final job in pending) {
        _inFlight.add(job.id);
        futures.add(
          _schedule(job).whenComplete(() => _inFlight.remove(job.id)),
        );
      }

      await Future.wait(futures);
    } finally {
      _isProcessing = false;
      if (_needsRerun) {
        _needsRerun = false;
        final latest = await _db.watchPendingPrintJobs().first;
        await _handleJobs(latest);
      }
    }
  }

  Future<void> _schedule(PrintJobDb job) {
    final key = job.printerId ?? -1;
    final previous = _printerChains[key] ?? Future<void>.value();
    final next = previous.then((_) => _processJob(job));
    _printerChains[key] = next.catchError((_) {});
    return next;
  }

  Future<void> _processJob(PrintJobDb job) async {
    final printerId = job.printerId;
    if (printerId == null) {
      await _db.markPrintJobFailed(job.id, 'لا توجد طابعة مرتبطة');
      return;
    }

    final printer = await (_db.select(
      _db.printers,
    )..where((t) => t.id.equals(printerId))).getSingleOrNull();
    if (printer == null || !printer.enabled || printer.isDeleted) {
      await _db.markPrintJobFailed(job.id, 'الطابعة غير متاحة');
      return;
    }

    final sale = await (_db.select(
      _db.sales,
    )..where((t) => t.localId.equals(job.saleLocalId))).getSingleOrNull();
    if (sale == null) {
      await _db.markPrintJobFailed(job.id, 'الفاتورة غير موجودة');
      return;
    }

    final customerId = sale.customerId;
    final customer = customerId == null
        ? null
        : await (_db.select(
            _db.customers,
          )..where((t) => t.id.equals(customerId))).getSingleOrNull();

    final allItems = await (_db.select(
      _db.saleItems,
    )..where((t) => t.saleLocalId.equals(sale.localId))).get();
    final payments = await (_db.select(
      _db.salePayments,
    )..where((t) => t.saleLocalId.equals(sale.localId))).get();
    final storeName = _stripBidiMarks(
      (await _db.getSetting('store_name'))?.trim() ?? '',
    );
    final branchName = _stripBidiMarks(
      (await _db.getSetting('branch_name'))?.trim() ?? '',
    );
    final branchAddress = _stripBidiMarks(
      (await _db.getSetting('branch_address'))?.trim() ?? '',
    );
    final phone = _stripBidiMarks(
      (await _db.getSetting('branch_phone'))?.trim() ?? '',
    );
    final vatNo = _stripBidiMarks(
      (await _db.getSetting('vat_no'))?.trim() ?? '',
    );
    final crNo = _stripBidiMarks((await _db.getSetting('cr_no'))?.trim() ?? '');
    final template = await _db.getDefaultInvoiceTemplate(printer.paperSize);
    final printServiceInInvoice = await _shouldPrintServiceInInvoice();
    final printTableInInvoice = await _shouldPrintTableInInvoice();
    final tableName = await _resolveSaleTableName(sale);

    final isCustomerReceipt =
        job.jobType.toUpperCase().trim() == 'CUSTOMER_RECEIPT';
    final isAggregateStationJob =
        job.stationCode.trim().toUpperCase() == AppDb.aggregateStationCode;
    final stationName = await _resolveStationName(job.stationCode);

    List<SaleItemDb> itemsToPrint = [];

    if (isCustomerReceipt) {
      itemsToPrint = allItems;
    } else if (isAggregateStationJob) {
      itemsToPrint = allItems;
    } else {
      final productIds = allItems.map((e) => e.productId).toList();
      final products = await (_db.select(
        _db.products,
      )..where((t) => t.id.isIn(productIds))).get();
      final productMap = {for (var p in products) p.id: p};

      itemsToPrint = allItems.where((item) {
        final product = productMap[item.productId];
        final itemStation =
            (item.stationCode.isNotEmpty
                    ? item.stationCode
                    : (product?.stationCode ?? ''))
                .trim()
                .toUpperCase();
        return itemStation == job.stationCode.trim().toUpperCase();
      }).toList();
    }

    if (itemsToPrint.isEmpty) {
      await _db.markPrintJobPrinted(job.id);
      return;
    }

    try {
      final addonsBySaleItemId = await _loadSaleItemAddonsMap(itemsToPrint);
      final deliveryMeta = _parseDeliveryMeta(job.payload);
      final model = _buildReceiptModel(
        jobType: job.jobType,
        sale: sale,
        items: itemsToPrint,
        addonsBySaleItemId: addonsBySaleItemId,
        stationName: stationName,
        payments: payments,
        storeName: storeName,
        branchName: branchName,
        branchAddress: branchAddress,
        phone: phone,
        vatNo: vatNo,
        crNo: crNo,
        template: template,
        deliveryMeta: deliveryMeta,
        customerName: _resolveCustomerName(customer),
        printServiceInInvoice: printServiceInInvoice,
        printTableInInvoice: printTableInInvoice,
        tableName: tableName,
      );

      final payload = await _buildPdfPayload(model, printer, template);
      await Printing.directPrintPdf(
        printer: Printer(url: printer.windowsPrinterName ?? printer.name),
        onLayout: (format) async => payload.bytes,
        name: '${model.title}_${model.invoiceNo}',
      );

      await _db.markPrintJobPrinted(job.id);
    } catch (e, st) {
      final traceHead = st.toString().split('\n').take(2).join(' | ');
      await _db.markPrintJobFailed(job.id, '$e | $traceHead');
    }
  }

  Future<void> printQuotation({
    required CartState cart,
    required double discount,
    int? serviceId,
    String? serviceName,
    double serviceCost = 0,
    int? tableId,
    String? tableName,
  }) async {
    final workstation = await _db.getCurrentWorkstation();
    final aggregatePrinter = workstation == null
        ? await _db.getAggregatePrinter()
        : await _db.getAggregatePrinter(workstationId: workstation.id);
    final resolvedCashierPrinter = workstation == null
        ? await _db.getPrinterForStation('CASHIER')
        : await _db.resolvePrinterForStation(
            'CASHIER',
            workstationId: workstation.id,
          );
    final printer = resolvedCashierPrinter ?? aggregatePrinter;

    if (printer == null || !printer.enabled || printer.isDeleted) {
      throw Exception('لا توجد طابعة للكاشير');
    }

    final storeName = _stripBidiMarks(
      (await _db.getSetting('store_name'))?.trim() ?? '',
    );
    final branchName = _stripBidiMarks(
      (await _db.getSetting('branch_name'))?.trim() ?? '',
    );
    final branchAddress = _stripBidiMarks(
      (await _db.getSetting('branch_address'))?.trim() ?? '',
    );
    final phone = _stripBidiMarks(
      (await _db.getSetting('branch_phone'))?.trim() ?? '',
    );
    final vatNo = _stripBidiMarks(
      (await _db.getSetting('vat_no'))?.trim() ?? '',
    );
    final crNo = _stripBidiMarks((await _db.getSetting('cr_no'))?.trim() ?? '');
    final template = await _db.getDefaultInvoiceTemplate(printer.paperSize);
    final printServiceInInvoice = await _shouldPrintServiceInInvoice();
    final printTableInInvoice = await _shouldPrintTableInInvoice();

    final subtotal = cart.items.fold(0.0, (sum, item) => sum + item.total);
    final normalizedServiceName = (serviceName ?? '').trim();
    final normalizedServiceCost = serviceCost < 0 ? 0.0 : serviceCost;
    final normalizedTableName = (tableName ?? '').trim();
    final taxBase = subtotal + normalizedServiceCost - discount;
    final tax = taxBase > 0 ? _round2(taxBase * _fixedTaxRate) : 0.0;
    final total = subtotal + tax + normalizedServiceCost - discount;
    final uuid = const Uuid().v4();
    final createdAt = DateTime.now();

    final quotationId = await _db
        .into(_db.sales)
        .insert(
          SalesCompanion.insert(
            uuid: uuid,
            subtotal: Value(subtotal),
            tax: Value(tax),
            discount: Value(discount),
            serviceId: Value(serviceId),
            serviceNameSnapshot: Value(
              normalizedServiceName.isEmpty ? null : normalizedServiceName,
            ),
            serviceCost: Value(normalizedServiceCost),
            tableId: Value(tableId),
            tableNameSnapshot: Value(
              normalizedTableName.isEmpty ? null : normalizedTableName,
            ),
            total: total,
            paidTotal: const Value(0),
            remaining: Value(total),
            status: const Value('QUOTATION'),
            createdAt: Value(createdAt),
            syncStatus: const Value('PENDING'),
          ),
        );

    if (cart.items.isNotEmpty) {
      await _db.batch((b) {
        b.insertAll(
          _db.saleItems,
          cart.items
              .map(
                (item) => SaleItemsCompanion.insert(
                  saleLocalId: quotationId,
                  productId: item.product.id,
                  qty: item.qty,
                  price: item.unitPrice,
                  total: Value(item.total),
                  nameSnapshot: Value(item.product.name),
                ),
              )
              .toList(),
        );
      });
    }

    final mockSale = SaleDb(
      localId: quotationId,
      uuid: uuid,
      invoiceNo: null,
      dailyOrderNo: 0,
      serverSaleId: null,
      branchServerId: null,
      cashierServerId: null,
      serviceId: serviceId,
      serviceNameSnapshot: normalizedServiceName.isEmpty
          ? null
          : normalizedServiceName,
      serviceCost: normalizedServiceCost,
      tableId: tableId,
      tableNameSnapshot: normalizedTableName.isEmpty
          ? null
          : normalizedTableName,
      itemsCount: cart.items.length,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      paidTotal: 0,
      remaining: total,
      status: 'QUOTATION',
      syncStatus: 'PENDING',
      syncError: null,
      syncedAt: null,
      zatcaStatus: null,
      zatcaResponse: null,
      createdAt: createdAt,
      completedAtLocal: null,
    );

    final mockItems = cart.items
        .map(
          (item) => SaleItemDb(
            id: 0,
            saleLocalId: quotationId,
            productId: item.product.id,
            serverProductId: null,
            nameSnapshot: item.product.name,
            qty: item.qty,
            price: item.unitPrice,
            total: item.total,
            stationCode: '',
            note: _buildCartItemNote(item),
          ),
        )
        .toList();

    final model = _buildReceiptModel(
      jobType: 'CUSTOMER_RECEIPT',
      sale: mockSale,
      items: mockItems,
      addonsBySaleItemId: const <int, List<SaleItemAddonDb>>{},
      stationName: 'CASHIER',
      payments: const [],
      storeName: storeName,
      branchName: branchName,
      branchAddress: branchAddress,
      phone: phone,
      vatNo: vatNo,
      crNo: crNo,
      template: template,
      customTitle: 'بيان سعر',
      deliveryMeta: null,
      customerName: 'عميل عام',
      printServiceInInvoice: printServiceInInvoice,
      printTableInInvoice: printTableInInvoice,
      tableName: normalizedTableName,
    );

    final payload = await _buildPdfPayload(model, printer, template);
    await Printing.directPrintPdf(
      printer: Printer(url: printer.windowsPrinterName ?? printer.name),
      onLayout: (format) async => payload.bytes,
      name: '${model.title}_Quotation',
    );
  }

  Future<void> printDirectly({
    required String jobType,
    required SaleDb sale,
    required List<SaleItemDb> items,
    required List<SalePaymentDb> payments,
  }) async {
    final workstation = await _db.getCurrentWorkstation();
    final aggregatePrinter = workstation == null
        ? await _db.getAggregatePrinter()
        : await _db.getAggregatePrinter(workstationId: workstation.id);
    final resolvedCashierPrinter = workstation == null
        ? await _db.getPrinterForStation('CASHIER')
        : await _db.resolvePrinterForStation(
            'CASHIER',
            workstationId: workstation.id,
          );
    final printer = resolvedCashierPrinter ?? aggregatePrinter;

    if (printer == null || !printer.enabled || printer.isDeleted) {
      throw Exception('لا توجد طابعة للكاشير');
    }

    final storeName = _stripBidiMarks(
      (await _db.getSetting('store_name'))?.trim() ?? '',
    );
    final branchName = _stripBidiMarks(
      (await _db.getSetting('branch_name'))?.trim() ?? '',
    );
    final branchAddress = _stripBidiMarks(
      (await _db.getSetting('branch_address'))?.trim() ?? '',
    );
    final phone = _stripBidiMarks(
      (await _db.getSetting('branch_phone'))?.trim() ?? '',
    );
    final vatNo = _stripBidiMarks(
      (await _db.getSetting('vat_no'))?.trim() ?? '',
    );
    final crNo = _stripBidiMarks((await _db.getSetting('cr_no'))?.trim() ?? '');
    final template = await _db.getDefaultInvoiceTemplate(printer.paperSize);
    final printServiceInInvoice = await _shouldPrintServiceInInvoice();
    final printTableInInvoice = await _shouldPrintTableInInvoice();
    final tableName = await _resolveSaleTableName(sale);
    final stationName = await _resolveStationName('CASHIER');
    final receiptJob =
        await ((_db.select(_db.printJobs)
              ..where(
                (t) =>
                    t.saleLocalId.equals(sale.localId) &
                    t.jobType.equals('CUSTOMER_RECEIPT'),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1)))
            .getSingleOrNull();
    final deliveryMeta = _parseDeliveryMeta(receiptJob?.payload);
    final customerId = sale.customerId;
    final customer = customerId == null
        ? null
        : await (_db.select(
            _db.customers,
          )..where((t) => t.id.equals(customerId))).getSingleOrNull();
    final addonsBySaleItemId = await _loadSaleItemAddonsMap(items);

    final model = _buildReceiptModel(
      jobType: jobType,
      sale: sale,
      items: items,
      addonsBySaleItemId: addonsBySaleItemId,
      stationName: stationName,
      payments: payments,
      storeName: storeName,
      branchName: branchName,
      branchAddress: branchAddress,
      phone: phone,
      vatNo: vatNo,
      crNo: crNo,
      template: template,
      deliveryMeta: deliveryMeta,
      customerName: _resolveCustomerName(customer),
      printServiceInInvoice: printServiceInInvoice,
      printTableInInvoice: printTableInInvoice,
      tableName: tableName,
    );

    final payload = await _buildPdfPayload(model, printer, template);
    await Printing.directPrintPdf(
      printer: Printer(url: printer.windowsPrinterName ?? printer.name),
      onLayout: (format) async => payload.bytes,
      name: '${model.title}_${sale.invoiceNo ?? sale.localId}',
    );
  }

  Future<String> _resolveStationName(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toUpperCase() == AppDb.aggregateStationCode) {
      return 'مجمع';
    }
    final station = await (_db.select(
      _db.printStations,
    )..where((t) => t.code.equals(trimmed))).getSingleOrNull();
    return station?.name ?? trimmed;
  }

  _DeliveryMeta? _parseDeliveryMeta(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final delivery = decoded['delivery'];
      if (delivery is! Map<String, dynamic>) return null;
      final enabled = delivery['enabled'] == true;
      final fee = (delivery['fee'] as num?)?.toDouble() ?? 0;
      final details = (delivery['details'] as String? ?? '').trim();
      final address = (delivery['address'] as String? ?? '').trim();
      final assignee = (delivery['assignee'] as String? ?? '').trim();
      final meta = _DeliveryMeta(
        enabled: enabled || fee > 0,
        fee: fee,
        details: details,
        address: address,
        assignee: assignee,
      );
      return meta.hasAnyValue ? meta : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _shouldPrintServiceInInvoice() async {
    final raw = (await _db.getSetting(
      'pos.print_service_in_invoice',
    ))?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    if (raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on') {
      return true;
    }
    if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'off') {
      return false;
    }
    return true;
  }

  Future<bool> _shouldPrintTableInInvoice() async {
    final raw = (await _db.getSetting(
      'pos.print_table_in_invoice',
    ))?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    if (raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on') {
      return true;
    }
    if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'off') {
      return false;
    }
    return true;
  }

  Future<String> _resolveSaleTableName(SaleDb sale) async {
    final snap = _stripBidiMarks((sale.tableNameSnapshot ?? '').trim());
    if (snap.isNotEmpty) return snap;
    final tableId = sale.tableId;
    if (tableId == null) return '';
    final table = await (_db.select(
      _db.posTables,
    )..where((t) => t.id.equals(tableId))).getSingleOrNull();
    return _stripBidiMarks((table?.name ?? '').trim());
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  Future<Map<int, List<SaleItemAddonDb>>> _loadSaleItemAddonsMap(
    List<SaleItemDb> items,
  ) async {
    final itemIds = items.map((item) => item.id).where((id) => id > 0).toList();
    if (itemIds.isEmpty) {
      return const <int, List<SaleItemAddonDb>>{};
    }
    final rows = await (_db.select(
      _db.saleItemAddons,
    )..where((t) => t.saleItemId.isIn(itemIds))).get();
    final addonsBySaleItemId = <int, List<SaleItemAddonDb>>{};
    for (final row in rows) {
      addonsBySaleItemId.putIfAbsent(row.saleItemId, () => []).add(row);
    }
    return addonsBySaleItemId;
  }

  String? _buildSaleItemNote(
    SaleItemDb item,
    Map<int, List<SaleItemAddonDb>> addonsBySaleItemId,
  ) {
    final addons = addonsBySaleItemId[item.id] ?? const <SaleItemAddonDb>[];
    if (addons.isNotEmpty) {
      return addons
          .map((addon) {
            final itemName = _stripBidiMarks(addon.itemNameSnapshot.trim());
            if (itemName.isEmpty) return null;
            return addon.price > 0
                ? '+ $itemName (${addon.price.toStringAsFixed(2)} ريال)'
                : '+ $itemName';
          })
          .whereType<String>()
          .join('\n');
    }
    final note = _stripBidiMarks((item.note ?? '').trim());
    return note.isEmpty ? null : note;
  }

  String? _buildCartItemNote(CartItem item) {
    if (item.selectedAddons.isEmpty) return null;
    return item.selectedAddons.map((addon) => addon.invoiceLabel).join('\n');
  }

  _ReceiptModel _buildReceiptModel({
    required String jobType,
    required SaleDb sale,
    required List<SaleItemDb> items,
    required Map<int, List<SaleItemAddonDb>> addonsBySaleItemId,
    required String stationName,
    required List<SalePaymentDb> payments,
    required String storeName,
    required String branchName,
    required String branchAddress,
    required String phone,
    required String vatNo,
    required String crNo,
    required InvoiceTemplateDb? template,
    required _DeliveryMeta? deliveryMeta,
    required String customerName,
    required bool printServiceInInvoice,
    required bool printTableInInvoice,
    required String tableName,
    String? customTitle,
  }) {
    final isCustomerReceipt =
        jobType.toUpperCase().trim() == 'CUSTOMER_RECEIPT';
    final normalizedStationName = stationName.trim();
    final headerTitle = (template?.headerTitle ?? '').trim();
    final title =
        customTitle ??
        (isCustomerReceipt
            ? (headerTitle.isNotEmpty ? headerTitle : 'فاتورة ضريبية مبسطة')
            : (normalizedStationName.isNotEmpty
                  ? 'تذكرة قسم $normalizedStationName'
                  : 'تذكرة قسم'));
    final headerName = branchName.isNotEmpty
        ? branchName
        : (storeName.isNotEmpty ? storeName : 'Montex Soft');
    final itemsCount = items.fold<double>(
      0,
      (sum, item) => sum + item.qty.toDouble(),
    );
    final paymentLabel = _resolvePaymentLabel(payments);
    final qrData = _buildQrData(
      storeName: headerName,
      vatNo: vatNo,
      date: sale.createdAt,
      total: sale.total,
      tax: sale.tax,
    );
    final normalizedTableName = _stripBidiMarks(tableName.trim());

    return _ReceiptModel(
      title: title,
      headerName: headerName,
      branchAddress: branchAddress,
      phone: phone,
      vatNo: vatNo,
      crNo: crNo,
      stationName: stationName,
      invoiceNo: sale.invoiceNo ?? sale.localId.toString(),
      orderNo: sale.dailyOrderNo,
      tableName: normalizedTableName,
      showTableLine: printTableInInvoice && normalizedTableName.isNotEmpty,
      date: _formatDate(sale.createdAt),
      isCustomerReceipt: isCustomerReceipt,
      customerName: customerName.trim().isEmpty ? 'عميل عام' : customerName,
      items: items
          .map(
            (i) => _ReceiptItem(
              name: i.nameSnapshot,
              qty: i.qty.toDouble(),
              subtotal: i.total,
              totalWithTax: _round2(i.total + _round2(i.total * _fixedTaxRate)),
              note: _buildSaleItemNote(i, addonsBySaleItemId),
            ),
          )
          .toList(),
      itemsCount: itemsCount,
      subtotal: sale.subtotal,
      total: sale.total,
      discount: sale.discount,
      tax: sale.tax,
      serviceName: _stripBidiMarks(sale.serviceNameSnapshot ?? ''),
      serviceCost: sale.serviceCost,
      showServiceLine: printServiceInInvoice,
      paid: sale.paidTotal,
      remaining: sale.remaining,
      paymentLabel: paymentLabel,
      qrData: qrData,
      template: template,
      hasDelivery: deliveryMeta?.enabled == true,
      deliveryFee: deliveryMeta?.fee ?? 0,
      deliveryDetails: deliveryMeta?.details ?? '',
      deliveryAddress: deliveryMeta?.address ?? '',
      deliveryAssignee: deliveryMeta?.assignee ?? '',
    );
  }

  String _resolveCustomerName(CustomerDb? customer) {
    final name = _stripBidiMarks(customer?.name.trim() ?? '');
    if (name.isEmpty) {
      return 'عميل عام';
    }
    return name;
  }

  String _formatDate(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<_PdfPayload> _buildPdfPayload(
    _ReceiptModel model,
    PrinterDb printer,
    InvoiceTemplateDb? template,
  ) async {
    final fonts = await PdfArabicFonts.load();
    final fontRegular = fonts.regular;
    final fontBold = fonts.bold;
    _currencySymbolFont = fonts.symbol;
    _riyalSign = fonts.riyalSign;

    pw.ImageProvider? logo;
    try {
      logo = await _loadLogo(template);
    } catch (_) {}

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    if (printer.paperSize == _paperSizeA4) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: _buildA4Layout(model, fontRegular, fontBold, logo),
            ),
          ],
        ),
      );
      return _PdfPayload(bytes: await doc.save(), format: PdfPageFormat.a4);
    }

    doc.addPage(
      pw.Page(
        pageFormat:
            (printer.paperSize == 58
                    ? PdfPageFormat.roll57
                    : PdfPageFormat.roll80)
                .copyWith(
                  marginBottom: 10,
                  marginTop: 10,
                  marginLeft: 10,
                  marginRight: 10,
                ),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (model.isCustomerReceipt &&
                    logo != null &&
                    (template?.showLogo ?? true))
                  pw.Center(
                    child: pw.Container(
                      width: _thermalLogoSize,
                      height: _thermalLogoSize,
                      child: pw.Image(logo),
                    ),
                  ),
                if (model.isCustomerReceipt)
                  _buildReceiptHeaderDetails(
                    model: model,
                    template: template,
                    fontRegular: fontRegular,
                    fontBold: fontBold,
                    headerNameFontSize: 13,
                    detailFontSize: 9.5,
                    maxWidth: 230,
                  ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    model.title,
                    style: pw.TextStyle(font: fontBold, fontSize: 15),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    _rtlLabelValue('رقم الطلب', _formatOrderNo(model.orderNo)),
                    style: pw.TextStyle(font: fontRegular, fontSize: 10),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (model.hasServiceName)
                  pw.Center(
                    child: pw.Text(
                      _bidiFix(model.serviceNameOnly),
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Column(
                  children: [
                    if (model.showTableLine)
                      _invoiceInfoLine(
                        'رقم الطاولة',
                        model.tableName,
                        fontRegular,
                        10,
                      ),
                    if (template?.showInvoiceNo ?? true)
                      _invoiceInfoLine(
                        'رقم الفاتورة',
                        model.invoiceNo,
                        fontRegular,
                        10,
                      ),
                    if (template?.showDate ?? true)
                      _invoiceInfoLine(
                        'التاريخ والوقت',
                        model.date,
                        fontRegular,
                        10,
                      ),
                    if (model.isCustomerReceipt && model.hasDelivery)
                      _deliveryInfoHeader(fontRegular, 10),
                    if (model.isCustomerReceipt && model.hasDelivery)
                      _invoiceInfoLine(
                        'تفاصيل',
                        model.deliveryDetailsOrDash,
                        fontRegular,
                        10,
                      ),
                    if (model.isCustomerReceipt && model.hasDelivery)
                      _invoiceInfoLine(
                        'عنوان التوصيل',
                        model.deliveryAddressOrDash,
                        fontRegular,
                        10,
                      ),
                    if (model.isCustomerReceipt && model.hasDelivery)
                      _invoiceInfoLine(
                        'المندوب',
                        model.deliveryAssigneeOrDash,
                        fontRegular,
                        10,
                      ),
                    if (model.isCustomerReceipt &&
                        (template?.showCustomer ?? true))
                      _invoiceInfoLine(
                        'اسم العميل',
                        model.customerName,
                        fontRegular,
                        10,
                      ),
                  ],
                ),
                pw.SizedBox(height: 8),

                pw.Table(
                  border: pw.TableBorder(
                    top: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 1.0,
                    ),
                    bottom: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 1.0,
                    ),
                    left: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 1.0,
                    ),
                    right: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 1.0,
                    ),
                    horizontalInside: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 0.5,
                      style: pw.BorderStyle.dashed,
                    ),
                    verticalInside: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 0.5,
                      style: pw.BorderStyle.dashed,
                    ),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.8),
                    1: const pw.FlexColumnWidth(1.6),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(3.4),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _tableHeader('المجموع', fontBold),
                        _tableHeader('سعر الوحدة', fontBold),
                        _tableHeader('العدد', fontBold),
                        _tableHeader('الصنف', fontBold),
                      ],
                    ),
                    ...model.items.map((item) {
                      final price = item.qty == 0
                          ? 0
                          : (item.subtotal / item.qty);
                      final lineTotal = model.isCustomerReceipt
                          ? item.totalWithTax
                          : item.subtotal;
                      final itemLabel = (item.note ?? '').trim().isEmpty
                          ? item.name
                          : '${item.name}\n${item.note!.trim()}';
                      return pw.TableRow(
                        children: [
                          _tableCell(
                            lineTotal.toStringAsFixed(2),
                            fontRegular,
                            align: pw.TextAlign.left,
                          ),
                          _tableCell(
                            price.toStringAsFixed(2),
                            fontRegular,
                            align: pw.TextAlign.left,
                          ),
                          _tableCell(
                            item.qty.toStringAsFixed(2),
                            fontRegular,
                            align: pw.TextAlign.left,
                          ),
                          _tableCell(
                            _bidiFix(itemLabel),
                            fontRegular,
                            align: pw.TextAlign.right,
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                if (model.isCustomerReceipt) ...[
                  pw.SizedBox(height: 6),
                  if (template?.showItemsCount ?? true)
                    _summaryRow(
                      'إجمالي العدد',
                      model.itemsCount.toStringAsFixed(2),
                      fontBold,
                    ),
                  if (template?.showSubtotal ?? true)
                    _summaryRow(
                      'الإجمالي قبل الضريبة',
                      _formatCurrency(model.subtotal),
                      fontRegular,
                    ),
                  if (model.isCustomerReceipt &&
                      model.hasDelivery &&
                      model.deliveryFee > 0)
                    _summaryRow(
                      'خدمة التوصيل',
                      _formatCurrency(model.deliveryFee),
                      fontRegular,
                    ),
                  if (model.isCustomerReceipt && model.hasServiceLine)
                    _summaryRow(
                      model.serviceName.trim().isEmpty
                          ? 'تكلفة الخدمة'
                          : 'الخدمة (${model.serviceName.trim()})',
                      _formatCurrency(model.serviceCost),
                      fontRegular,
                    ),
                  if (template?.showDiscount ?? true)
                    _summaryRow(
                      'الخصم',
                      _formatDiscountCurrency(model.discount),
                      fontRegular,
                    ),
                  if (model.tax > 0 || (template?.showTax ?? true))
                    _summaryRow(
                      'الضريبة',
                      _formatPositiveCurrency(model.tax),
                      fontRegular,
                    ),
                  if (template?.showTotal ?? true)
                    _summaryRow(
                      'الإجمالي شامل الضريبة',
                      _formatCurrency(model.total),
                      fontBold,
                      showDivider: false,
                    ),
                  if (template?.showPaymentLabel ?? true)
                    _summaryRow(
                      model.paymentLabel,
                      _formatCurrency(model.paid),
                      fontRegular,
                    ),
                  if (template?.showPaid ?? true)
                    _summaryRow(
                      'المبلغ المدفوع',
                      _formatCurrency(model.paid),
                      fontRegular,
                    ),
                  if (template?.showRemaining ?? true)
                    _summaryRow(
                      'إجمالي المستحق',
                      _formatCurrency(model.remaining),
                      fontRegular,
                      showDivider: false,
                    ),

                  if ((template?.showQr ?? true) &&
                      model.qrData.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: model.qrData,
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  if ((template?.footerText ?? '').trim().isNotEmpty)
                    pw.Center(
                      child: pw.Text(
                        (template?.footerText ?? '').trim(),
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    )
                  else
                    pw.Center(
                      child: pw.Text(
                        'شكراً لزيارتكم',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return _PdfPayload(bytes: await doc.save(), format: PdfPageFormat.roll80);
  }

  pw.Widget _buildA4Layout(
    _ReceiptModel model,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.ImageProvider? logo,
  ) {
    final template = model.template;
    final amountWords = _amountToWords(model.total);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header Block
        if (model.isCustomerReceipt &&
            logo != null &&
            (template?.showLogo ?? true))
          pw.Center(
            child: pw.Container(
              width: _a4LogoSize,
              height: _a4LogoSize,
              child: pw.Image(logo),
            ),
          ),
        if (model.isCustomerReceipt)
          _buildReceiptHeaderDetails(
            model: model,
            template: template,
            fontRegular: fontRegular,
            fontBold: fontBold,
            headerNameFontSize: 12.5,
            detailFontSize: 9.2,
            maxWidth: 340,
          ),
        pw.SizedBox(height: 4),

        // Title centered
        pw.Center(
          child: pw.Text(
            model.title,
            style: pw.TextStyle(font: fontBold, fontSize: 20),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            _rtlLabelValue('رقم الطلب', _formatOrderNo(model.orderNo)),
            style: pw.TextStyle(font: fontBold, fontSize: 11),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (model.hasServiceName)
          pw.Center(
            child: pw.Text(
              _bidiFix(model.serviceNameOnly),
              style: pw.TextStyle(font: fontBold, fontSize: 11),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
            ),
          ),
        pw.SizedBox(height: 4),

        // Invoice Info (Right aligned in RTL)
        pw.Column(
          children: [
            if (model.showTableLine)
              _invoiceInfoLine('رقم الطاولة', model.tableName, fontBold, 11),
            if (template?.showInvoiceNo ?? true)
              _invoiceInfoLine('رقم الفاتورة', model.invoiceNo, fontBold, 11),
            if (template?.showDate ?? true)
              _invoiceInfoLine('التاريخ والوقت', model.date, fontBold, 11),
            if (model.isCustomerReceipt && model.hasDelivery)
              _deliveryInfoHeader(fontBold, 11),
            if (model.isCustomerReceipt && model.hasDelivery)
              _invoiceInfoLine(
                'تفاصيل',
                model.deliveryDetailsOrDash,
                fontBold,
                11,
              ),
            if (model.isCustomerReceipt && model.hasDelivery)
              _invoiceInfoLine(
                'عنوان التوصيل',
                model.deliveryAddressOrDash,
                fontBold,
                11,
              ),
            if (model.isCustomerReceipt && model.hasDelivery)
              _invoiceInfoLine(
                'المندوب',
                model.deliveryAssigneeOrDash,
                fontBold,
                11,
              ),
            if (model.isCustomerReceipt && (template?.showCustomer ?? true))
              _invoiceInfoLine('اسم العميل', model.customerName, fontBold, 11),
          ],
        ),
        pw.SizedBox(height: 10),

        // Items Table
        _buildA4ItemsTable(model, fontRegular, fontBold),
        if (model.isCustomerReceipt) ...[
          pw.SizedBox(height: 8),

          // Summary & Totals
          _buildA4SummarySection(model, fontRegular, fontBold, amountWords),
          pw.SizedBox(height: 10),

          // QR Code
          if ((template?.showQr ?? true) && model.qrData.isNotEmpty)
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: model.qrData,
                width: 120,
                height: 120,
              ),
            ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'شكراً لزيارتكم',
              style: pw.TextStyle(font: fontRegular, fontSize: 10),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildA4ItemsTable(
    _ReceiptModel model,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    const solidSide = pw.BorderSide(color: PdfColors.black, width: 1.0);
    const dashedSide = pw.BorderSide(
      color: PdfColors.black,
      width: 0.5,
      style: pw.BorderStyle.dashed,
    );

    final List<pw.TableRow> rows = [];
    rows.add(
      pw.TableRow(
        children: [
          _a4TableHeader('المجموع', fontBold),
          _a4TableHeader('سعر الوحدة', fontBold),
          _a4TableHeader('العدد', fontBold),
          _a4TableHeader('الصنف', fontBold),
        ],
      ),
    );

    for (final item in model.items) {
      final price = item.qty == 0 ? 0 : (item.subtotal / item.qty);
      final lineTotal = model.isCustomerReceipt
          ? item.totalWithTax
          : item.subtotal;
      final itemLabel = (item.note ?? '').trim().isEmpty
          ? item.name
          : '${item.name}\n${item.note!.trim()}';
      rows.add(
        pw.TableRow(
          children: [
            _a4TableCell(
              lineTotal.toStringAsFixed(2),
              fontRegular,
              align: pw.TextAlign.left,
            ),
            _a4TableCell(
              price.toStringAsFixed(2),
              fontRegular,
              align: pw.TextAlign.left,
            ),
            _a4TableCell(
              item.qty.toStringAsFixed(2),
              fontRegular,
              align: pw.TextAlign.left,
            ),
            _a4TableCell(
              _bidiFix(itemLabel),
              fontRegular,
              align: pw.TextAlign.right,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        top: solidSide,
        bottom: solidSide,
        left: solidSide,
        right: solidSide,
        horizontalInside: dashedSide,
        verticalInside: dashedSide,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8), // Total (Left)
        1: const pw.FlexColumnWidth(1.6), // Price
        2: const pw.FlexColumnWidth(1.4), // Qty
        3: const pw.FlexColumnWidth(5.2), // Item Name (Right)
      },
      children: rows,
    );
  }

  pw.Widget _buildA4SummarySection(
    _ReceiptModel model,
    pw.Font fontRegular,
    pw.Font fontBold,
    String amountWords,
  ) {
    final template = model.template;
    return pw.Column(
      children: [
        if (template?.showItemsCount ?? true)
          _a4SummaryRow(
            'إجمالي العدد',
            model.itemsCount.toStringAsFixed(2),
            fontBold,
          ),
        if (template?.showSubtotal ?? true)
          _a4SummaryRow(
            'الإجمالي قبل الضريبة:',
            _formatCurrency(model.subtotal),
            fontBold,
          ),
        if (model.isCustomerReceipt &&
            model.hasDelivery &&
            model.deliveryFee > 0)
          _a4SummaryRow(
            'خدمة التوصيل:',
            _formatCurrency(model.deliveryFee),
            fontBold,
          ),
        if (model.isCustomerReceipt && model.hasServiceLine)
          _a4SummaryRow(
            model.serviceName.trim().isEmpty
                ? 'تكلفة الخدمة:'
                : 'الخدمة (${model.serviceName.trim()}):',
            _formatCurrency(model.serviceCost),
            fontBold,
          ),
        if (template?.showDiscount ?? true)
          _a4SummaryRow(
            'الخصم:',
            _formatDiscountCurrency(model.discount),
            fontBold,
          ),
        if (model.tax > 0 || (template?.showTax ?? true))
          _a4SummaryRow(
            'الضريبة:',
            _formatPositiveCurrency(model.tax),
            fontBold,
          ),
        if (template?.showTotal ?? true)
          _a4SummaryRow(
            'الإجمالي شامل الضريبة:',
            _formatCurrency(model.total),
            fontBold,
            showDivider: false,
          ),
        if ((template?.showAmountWords ?? true) && amountWords.isNotEmpty)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '($amountWords)',
              style: pw.TextStyle(font: fontRegular, fontSize: 10),
            ),
          ),
        pw.SizedBox(height: 8),
        if (template?.showPaymentLabel ?? true)
          _a4SummaryRow(
            model.paymentLabel,
            _formatCurrency(model.paid),
            fontBold,
          ),
        if (template?.showPaid ?? true)
          _a4SummaryRow(
            'المبلغ المدفوع',
            _formatCurrency(model.paid),
            fontBold,
          ),
        if (template?.showRemaining ?? true)
          _a4SummaryRow(
            'إجمالي المستحق',
            _formatCurrency(model.remaining),
            fontBold,
            showDivider: false,
          ),
      ],
    );
  }

  pw.Widget _a4SummaryRow(
    String label,
    String value,
    pw.Font font, {
    bool showDivider = true,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        children: [
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    child: _summaryValueWidget(value, font, 11),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(font: font, fontSize: 11),
                      textAlign: pw.TextAlign.right,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              height: 0.5,
              color: PdfColors.grey300,
            ),
        ],
      ),
    );
  }

  pw.Widget _a4TableHeader(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 11),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _a4TableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 11),
        textAlign: align,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _tableHeader(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _tableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: align,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font font, {
    bool showDivider = true,
  }) {
    return pw.Column(
      children: [
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: _summaryValueWidget(value, font, 11),
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(font: font, fontSize: 11),
                    textAlign: pw.TextAlign.right,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 2),
            height: 0.5,
            color: PdfColors.grey300,
          ),
      ],
    );
  }

  String _formatCurrency(double value) {
    // Keep order fixed as: Riyal sign then number.
    final number = value.toStringAsFixed(2);
    return _bidiFix('$_riyalSign\u00A0$number');
  }

  String _formatDiscountCurrency(double value) {
    final number = value.toStringAsFixed(2);
    return _bidiFix('$_riyalSign\u00A0$number\u00A0(-)');
  }

  String _formatPositiveCurrency(double value) {
    final number = value.toStringAsFixed(2);
    return _bidiFix('$_riyalSign\u00A0$number\u00A0(+)');
  }

  String _formatOrderNo(int value) {
    return value.toString().padLeft(4, '0');
  }

  pw.Widget _summaryValueWidget(String value, pw.Font font, double fontSize) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return pw.Text(
        '',
        style: pw.TextStyle(font: font, fontSize: fontSize),
      );
    }
    final hasDigit = RegExp(r'[0-9]').hasMatch(trimmed);
    final hasCurrencyGlyph =
        trimmed.contains('\uFDFC') || trimmed.contains('\u20C1');
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed);
    final symbolFont = _currencySymbolFont;
    final fallbackFonts =
        hasCurrencyGlyph && symbolFont != null && !identical(symbolFont, font)
        ? <pw.Font>[symbolFont]
        : const <pw.Font>[];
    return pw.Text(
      _bidiFix(trimmed),
      style: pw.TextStyle(
        font: font,
        fontSize: fontSize,
        fontFallback: fallbackFonts,
      ),
      textAlign: pw.TextAlign.left,
      textDirection: (hasDigit || hasCurrencyGlyph)
          ? pw.TextDirection.ltr
          : (hasArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
    );
  }

  String _rtlLabelValue(String label, String value) {
    final trimmed = _stripBidiMarks(value.trim());
    if (trimmed.isEmpty) return _bidiFix(label);
    return _bidiFix('$label: $trimmed');
  }

  pw.Widget _buildHeaderInfoLine(
    String label,
    String value,
    pw.Font font,
    double fontSize,
  ) {
    final trimmed = _stripBidiMarks(value.trim());
    if (trimmed.isEmpty) {
      return pw.Text(
        _bidiFix(label),
        style: pw.TextStyle(font: font, fontSize: fontSize),
        textDirection: pw.TextDirection.rtl,
      );
    }
    final valueDirection = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            _bidiFix('$label:'),
            style: pw.TextStyle(font: font, fontSize: fontSize),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            _bidiFix(trimmed),
            style: pw.TextStyle(font: font, fontSize: fontSize),
            textDirection: valueDirection,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptHeaderDetails({
    required _ReceiptModel model,
    required InvoiceTemplateDb? template,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required double headerNameFontSize,
    required double detailFontSize,
    required double maxWidth,
  }) {
    final widgets = <pw.Widget>[];

    if (template?.showHeaderName ?? true) {
      widgets.add(
        pw.Text(
          model.headerName,
          style: pw.TextStyle(font: fontBold, fontSize: headerNameFontSize),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
        ),
      );
    }
    if ((template?.showBranchAddress ?? true) &&
        model.branchAddress.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 2));
      widgets.add(
        pw.Text(
          model.branchAddress,
          style: pw.TextStyle(font: fontRegular, fontSize: detailFontSize),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
        ),
      );
    }
    if ((template?.showPhone ?? true) && model.phone.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 2));
      widgets.add(
        _buildHeaderInfoLine(
          'الموبايل',
          model.phone,
          fontRegular,
          detailFontSize,
        ),
      );
    }
    if ((template?.showVat ?? true) && model.vatNo.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 2));
      widgets.add(
        _buildHeaderInfoLine(
          'الرقم الضريبي',
          model.vatNo,
          fontRegular,
          detailFontSize,
        ),
      );
    }
    if ((template?.showCr ?? true) && model.crNo.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 2));
      widgets.add(
        _buildHeaderInfoLine(
          'السجل التجاري',
          model.crNo,
          fontRegular,
          detailFontSize,
        ),
      );
    }

    if (widgets.isEmpty) return pw.SizedBox(height: 4);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Center(
        child: pw.Container(
          width: maxWidth,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Column(children: widgets),
        ),
      ),
    );
  }

  pw.Widget _invoiceInfoLine(
    String label,
    String value,
    pw.Font font,
    double fontSize,
  ) {
    final trimmed = _stripBidiMarks(value.trim());
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          _rtlLabelValue(label, trimmed),
          style: pw.TextStyle(font: font, fontSize: fontSize),
          textAlign: pw.TextAlign.right,
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  pw.Widget _deliveryInfoHeader(pw.Font font, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3, bottom: 1),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          _bidiFix('معلومات التوصيل'),
          style: pw.TextStyle(font: font, fontSize: fontSize + 0.5),
          textAlign: pw.TextAlign.right,
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  String _bidiFix(String text) {
    return text;
  }

  String _stripBidiMarks(String value) {
    return value.replaceAll('\u200E', '').replaceAll('\u200F', '');
  }

  String _resolvePaymentLabel(List<SalePaymentDb> payments) {
    if (payments.isEmpty) {
      return 'كاش';
    }
    final methods = payments
        .map((p) => p.methodCode.toUpperCase())
        .toSet()
        .toList();
    if (methods.length > 1) {
      return 'مدفوعات متعددة';
    }
    switch (methods.first) {
      case 'CASH':
        return 'كاش';
      case 'CARD':
        return 'بطاقة';
      case 'TRANSFER':
        return 'تحويل';
      default:
        return 'دفع';
    }
  }

  String _buildQrData({
    required String storeName,
    required String vatNo,
    required DateTime date,
    required double total,
    required double tax,
  }) {
    if (storeName.isEmpty || vatNo.isEmpty) return '';
    final bytes = BytesBuilder();
    void addTlv(int tag, String value) {
      final valueBytes = utf8.encode(value);
      bytes.add([tag, valueBytes.length]);
      bytes.add(valueBytes);
    }

    addTlv(1, storeName);
    addTlv(2, vatNo);
    addTlv(3, date.toIso8601String());
    addTlv(4, total.toStringAsFixed(2));
    addTlv(5, tax.toStringAsFixed(2));
    return base64.encode(bytes.toBytes());
  }

  Future<pw.ImageProvider?> _loadLogo(InvoiceTemplateDb? template) async {
    final logoPath = template?.logoPath?.trim() ?? '';
    if (logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return pw.MemoryImage(bytes);
      }
    }
    try {
      return await imageFromAssetBundle('assets/images/logo.jpg');
    } catch (_) {
      return null;
    }
  }

  String _amountToWords(double value) {
    final intPart = value.floor();
    var frac = ((value - intPart) * 100).round();
    if (frac < 0) frac = 0;
    final intWords = _arabicNumber(intPart);
    if (frac == 0) return intWords;
    if (frac % 10 == 0) frac = frac ~/ 10;
    final fracWords = _arabicNumber(frac);
    return '$intWords فاصل $fracWords';
  }

  String _arabicNumber(int number) {
    if (number == 0) {
      return 'صفر';
    }
    if (number < 0) {
      return 'سالب ${_arabicNumber(number.abs())}';
    }
    final parts = <String>[];
    final thousands = number ~/ 1000;
    final remainder = number % 1000;
    if (thousands > 0) {
      if (thousands == 1) {
        parts.add('ألف');
      } else if (thousands == 2) {
        parts.add('ألفان');
      } else if (thousands <= 10) {
        parts.add('${_arabicNumberBelow100(thousands)} آلاف');
      } else {
        parts.add('${_arabicNumber(thousands)} ألف');
      }
    }
    if (remainder > 0) parts.add(_arabicNumberBelow1000(remainder));
    return parts.join(' و ');
  }

  String _arabicNumberBelow1000(int number) {
    if (number < 100) return _arabicNumberBelow100(number);
    final hundredsMap = {
      1: 'مائة',
      2: 'مائتان',
      3: 'ثلاثمائة',
      4: 'أربعمائة',
      5: 'خمسمائة',
      6: 'ستمائة',
      7: 'سبعمائة',
      8: 'ثمانمائة',
      9: 'تسعمائة',
    };
    final hundreds = number ~/ 100;
    final remainder = number % 100;
    final hundredText = hundredsMap[hundreds] ?? '';
    if (remainder == 0) return hundredText;
    return '$hundredText و ${_arabicNumberBelow100(remainder)}';
  }

  String _arabicNumberBelow100(int number) {
    if (number == 0) return '';
    final units = {
      1: 'واحد',
      2: 'اثنان',
      3: 'ثلاثة',
      4: 'أربعة',
      5: 'خمسة',
      6: 'ستة',
      7: 'سبعة',
      8: 'ثمانية',
      9: 'تسعة',
    };
    final tens = {
      10: 'عشرة',
      11: 'أحد عشر',
      12: 'اثنا عشر',
      13: 'ثلاثة عشر',
      14: 'أربعة عشر',
      15: 'خمسة عشر',
      16: 'ستة عشر',
      17: 'سبعة عشر',
      18: 'ثمانية عشر',
      19: 'تسعة عشر',
      20: 'عشرون',
      30: 'ثلاثون',
      40: 'أربعون',
      50: 'خمسون',
      60: 'ستون',
      70: 'سبعون',
      80: 'ثمانون',
      90: 'تسعون',
    };
    if (number <= 19) return tens[number] ?? units[number] ?? '';
    final ten = (number ~/ 10) * 10;
    final unit = number % 10;
    if (unit == 0) return tens[ten] ?? '';
    return '${units[unit]} و ${tens[ten]}';
  }
}

class _ReceiptModel {
  _ReceiptModel({
    required this.title,
    required this.headerName,
    required this.branchAddress,
    required this.phone,
    required this.vatNo,
    required this.crNo,
    required this.stationName,
    required this.invoiceNo,
    required this.orderNo,
    required this.tableName,
    required this.showTableLine,
    required this.date,
    required this.isCustomerReceipt,
    required this.customerName,
    required this.items,
    required this.itemsCount,
    required this.subtotal,
    required this.total,
    required this.discount,
    required this.tax,
    required this.serviceName,
    required this.serviceCost,
    required this.showServiceLine,
    required this.paid,
    required this.remaining,
    required this.paymentLabel,
    required this.qrData,
    required this.template,
    required this.hasDelivery,
    required this.deliveryFee,
    required this.deliveryDetails,
    required this.deliveryAddress,
    required this.deliveryAssignee,
  });
  final String title,
      headerName,
      branchAddress,
      phone,
      vatNo,
      crNo,
      stationName,
      invoiceNo,
      tableName,
      date,
      customerName,
      paymentLabel,
      qrData;
  final int orderNo;
  final bool showTableLine;
  final bool isCustomerReceipt;
  final List<_ReceiptItem> items;
  final double itemsCount,
      subtotal,
      total,
      discount,
      tax,
      serviceCost,
      paid,
      remaining;
  final String serviceName;
  final bool showServiceLine;
  final InvoiceTemplateDb? template;
  final bool hasDelivery;
  final double deliveryFee;
  final String deliveryDetails;
  final String deliveryAddress;
  final String deliveryAssignee;

  String get deliveryDetailsOrDash =>
      deliveryDetails.trim().isEmpty ? '-' : deliveryDetails.trim();
  String get deliveryAddressOrDash =>
      deliveryAddress.trim().isEmpty ? '-' : deliveryAddress.trim();
  String get deliveryAssigneeOrDash =>
      deliveryAssignee.trim().isEmpty ? '-' : deliveryAssignee.trim();
  String get serviceNameOnly => serviceName.trim();
  bool get hasServiceName => serviceNameOnly.isNotEmpty;
  bool get hasServiceLine =>
      showServiceLine && (serviceName.trim().isNotEmpty || serviceCost > 0);
}

class _ReceiptItem {
  _ReceiptItem({
    required this.name,
    required this.qty,
    required this.subtotal,
    required this.totalWithTax,
    this.note,
  });
  final String name;
  final double qty;
  final double subtotal;
  final double totalWithTax;
  final String? note;
}

class _PdfPayload {
  _PdfPayload({required this.bytes, required this.format});
  final Uint8List bytes;
  final PdfPageFormat format;
}

class _DeliveryMeta {
  const _DeliveryMeta({
    required this.enabled,
    required this.fee,
    required this.details,
    required this.address,
    required this.assignee,
  });

  final bool enabled;
  final double fee;
  final String details;
  final String address;
  final String assignee;

  bool get hasAnyValue =>
      enabled ||
      fee > 0 ||
      details.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      assignee.trim().isNotEmpty;
}
