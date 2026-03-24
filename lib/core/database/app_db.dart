import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

@DataClassName('ProductDb')
class Products extends Table {
  IntColumn get id => integer()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0))();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get categoryId =>
      integer().nullable().references(ProductCategories, #id)();
  IntColumn get brandId => integer().nullable().references(Brands, #id)();
  TextColumn get imagePath => text().nullable()();
  BlobColumn get imageData => blob().nullable()();
  TextColumn get stationCode => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingDb')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('InvoiceTemplateDb')
class InvoiceTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get paperSize => integer()(); // 80mm or 210 (A4)
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  TextColumn get headerTitle =>
      text().withDefault(const Constant('فاتورة ضريبية مبسطة'))();
  TextColumn get footerText => text().nullable()();
  TextColumn get logoPath => text().nullable()();

  BoolColumn get showLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get showHeaderName =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showBranchAddress =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPhone => boolean().withDefault(const Constant(true))();
  BoolColumn get showVat => boolean().withDefault(const Constant(true))();
  BoolColumn get showCr => boolean().withDefault(const Constant(true))();
  BoolColumn get showInvoiceNo => boolean().withDefault(const Constant(true))();
  BoolColumn get showDate => boolean().withDefault(const Constant(true))();
  BoolColumn get showCustomer => boolean().withDefault(const Constant(true))();
  BoolColumn get showItemsCount =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showSubtotal => boolean().withDefault(const Constant(true))();
  BoolColumn get showDiscount => boolean().withDefault(const Constant(true))();
  BoolColumn get showTax => boolean().withDefault(const Constant(true))();
  BoolColumn get showTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get showAmountWords =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPaymentLabel =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPaid => boolean().withDefault(const Constant(true))();
  BoolColumn get showRemaining => boolean().withDefault(const Constant(true))();
  BoolColumn get showQr => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ApiMetaDb')
class ApiMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ProductCategoryDb')
class ProductCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get stationCode => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PrintStationDb')
class PrintStations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
}

/// الجهاز/الكمبيوتر (الكاشير) اللي عليه البرنامج.
/// مهم لأن كل جهاز بيكون عنده طابعاته (USB/Windows/BT) وقد تختلف عن جهاز ثاني.
@DataClassName('WorkstationDb')
class Workstations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().unique()(); // UUID ثابت للجهاز
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get serverId => integer().nullable()();
  IntColumn get branchServerId => integer().nullable()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

/// ربط طابعة مع أكثر من قسم/Station (مثل multi-select في النظام اللي وريتنا)
@DataClassName('PrinterStationMapDb')
class PrinterStationMap extends Table {
  IntColumn get workstationId =>
      integer().nullable().references(Workstations, #id)();
  IntColumn get printerId => integer().references(Printers, #id)();
  TextColumn get stationCode => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {printerId, stationCode};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {workstationId, stationCode},
  ];
}

@DataClassName('PrinterDb')
class Printers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// اسم داخلي تظهره في النظام (مثلاً: طابعة المطبخ)
  TextColumn get name => text()();

  /// نوع الطابعة في نظامك (مثل: مجمعة / طابعة أقسام) أو Thermal/Ink...
  /// خليتها كما هي عندك حتى ما نكسر شيء.
  TextColumn get type => text()();

  /// محطة/قسم أساسي (Legacy) - نخليه موجود للتوافق
  TextColumn get stationCode => text()();

  /// ===== ربطها بالفرع والجهاز =====
  /// لو الفرع موجود (مطعم/فرع) خزن رقم الفرع من السيرفر
  IntColumn get branchServerId => integer().nullable()();

  /// لو الطابعة محلية على هذا الجهاز (Windows/USB/BT) نخزن workstationId
  IntColumn get workstationId =>
      integer().nullable().references(Workstations, #id)();

  /// ===== الاتصال =====
  /// NETWORK / WINDOWS / USB / BLUETOOTH
  TextColumn get connectionType =>
      text().withDefault(const Constant('WINDOWS'))();

  /// Network
  TextColumn get ip => text().nullable()();
  IntColumn get port => integer().withDefault(const Constant(9100))();

  /// Windows installed printer name
  TextColumn get windowsPrinterName => text().nullable()();

  /// Bluetooth
  TextColumn get btMac => text().nullable()();

  /// USB (اختياري لو بتستخدمه لاحقاً)
  IntColumn get usbVendorId => integer().nullable()();
  IntColumn get usbProductId => integer().nullable()();
  TextColumn get usbSerial => text().nullable()();

  /// ===== إعدادات الطباعة =====
  /// مقاس الورق 58/80 .. أنت تستخدم 80
  IntColumn get paperSize => integer().withDefault(const Constant(80))();
  IntColumn get copies => integer().withDefault(const Constant(1))();

  /// أحرف لكل سطر (حراري 80mm عادة 48 أو 42 حسب الخط)
  IntColumn get charPerLine => integer().nullable()();

  /// كودبيج/ترميز (مهم للعربي مع ESC/POS)
  TextColumn get codePage =>
      text().nullable()(); // مثال: CP864 / CP1256 / UTF-8

  /// بروفايل قدرات الطابعة (مثل default/simple..)
  TextColumn get capabilityProfile => text().nullable()();

  /// أوامر إضافية شائعة للحراري
  BoolColumn get cutAfterPrint => boolean().withDefault(const Constant(true))();
  BoolColumn get openCashDrawer =>
      boolean().withDefault(const Constant(false))();

  /// ===== حالة الطابعة =====
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();

  DateTimeColumn get lastTestAt => dateTime().nullable()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SaleDb')
class Sales extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get serverSaleId => integer().nullable()();
  TextColumn get invoiceNo => text().nullable()();
  IntColumn get dailyOrderNo => integer().withDefault(const Constant(0))();
  IntColumn get branchServerId => integer().nullable()();
  IntColumn get cashierServerId => integer().nullable()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get serviceId => integer().nullable().references(Services, #id)();
  TextColumn get serviceNameSnapshot => text().nullable()();
  RealColumn get serviceCost => real().withDefault(const Constant(0))();
  IntColumn get tableId => integer().nullable().references(PosTables, #id)();
  TextColumn get tableNameSnapshot => text().nullable()();
  IntColumn get shiftLocalId =>
      integer().nullable().references(Shifts, #localId)();
  TextColumn get note => text().nullable()();
  IntColumn get itemsCount => integer().withDefault(const Constant(0))();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get paidTotal => real().withDefault(const Constant(0))();
  RealColumn get remaining => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get zatcaStatus => text().nullable()();
  TextColumn get zatcaResponse => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAtLocal => dateTime().nullable()();
}

@DataClassName('SaleItemDb')
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleLocalId => integer().references(Sales, #localId)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(ProductCategories, #id)();
  TextColumn get categoryNameSnapshot => text().nullable()();
  IntColumn get serverProductId => integer().nullable()();
  TextColumn get nameSnapshot => text().withDefault(const Constant(''))();
  IntColumn get qty => integer()();
  RealColumn get price => real()();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get stationCode => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
}

@DataClassName('SaleItemAddonDb')
class SaleItemAddons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleItemId => integer().references(SaleItems, #id)();
  IntColumn get groupId => integer().nullable()();
  IntColumn get itemId => integer().nullable()();
  TextColumn get groupNameSnapshot => text().withDefault(const Constant(''))();
  TextColumn get itemNameSnapshot => text().withDefault(const Constant(''))();
  RealColumn get price => real().withDefault(const Constant(0))();
}

@DataClassName('SalePaymentDb')
class SalePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleLocalId => integer().references(Sales, #localId)();
  IntColumn get serverPaymentId => integer().nullable()();
  TextColumn get methodCode => text()();
  RealColumn get amount => real()();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('CustomerDb')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get activity => text().nullable()();
  TextColumn get mobile => text()();
  TextColumn get mobileAlt => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PrintJobDb')
class PrintJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleLocalId => integer().references(Sales, #localId)();
  TextColumn get stationCode => text()();
  IntColumn get printerId => integer().nullable().references(Printers, #id)();
  TextColumn get jobType => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get tries => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get printedAt => dateTime().nullable()();
}

@DataClassName('SyncQueueDb')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  IntColumn get entityLocalId => integer()();
  TextColumn get action => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get tries => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ShiftDb')
class Shifts extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get serverShiftId => integer().nullable()();
  TextColumn get shiftNo => text().nullable()();
  IntColumn get branchServerId => integer().nullable()();
  IntColumn get cashierServerId => integer().nullable()();
  IntColumn get workstationId =>
      integer().nullable().references(Workstations, #id)();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get openedBy => text().nullable()();
  RealColumn get openingBalance => real().withDefault(const Constant(0))();
  TextColumn get openingNote => text().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closedBy => text().nullable()();
  TextColumn get closingNote => text().nullable()();
  RealColumn get actualCash => real().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ServiceDb')
class Services extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get cost => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PosTableDb')
class PosTables extends Table {
  @override
  String get tableName => 'tables';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable().unique()();
  IntColumn get capacity => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BrandDb')
class Brands extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AddonGroupDb')
class AddonGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AddonItemDb')
class AddonItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(AddonGroups, #id)();
  TextColumn get name => text()();
  RealColumn get price => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('ProductAddonLinkDb')
class ProductAddonLinks extends Table {
  IntColumn get groupId => integer().references(AddonGroups, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, productId};
}

@DataClassName('ReceiptVoucherDb')
class ReceiptVouchers extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get serverVoucherId => integer().nullable()();
  TextColumn get voucherNo => text().nullable()();
  IntColumn get shiftLocalId =>
      integer().nullable().references(Shifts, #localId)();
  IntColumn get branchServerId => integer().nullable()();
  IntColumn get cashierServerId => integer().nullable()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get customerName => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get paymentMethodCode => text().withDefault(const Constant(''))();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('PaymentVoucherDb')
class PaymentVouchers extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get serverVoucherId => integer().nullable()();
  TextColumn get voucherNo => text().nullable()();
  IntColumn get shiftLocalId =>
      integer().nullable().references(Shifts, #localId)();
  IntColumn get branchServerId => integer().nullable()();
  IntColumn get cashierServerId => integer().nullable()();
  RealColumn get amount => real()();
  TextColumn get expenseType => text().withDefault(const Constant(''))();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('SalesReturnDb')
class SalesReturns extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get serverReturnId => integer().nullable()();
  TextColumn get returnNo => text().nullable()();
  IntColumn get originalSaleLocalId =>
      integer().nullable().references(Sales, #localId)();
  IntColumn get shiftLocalId =>
      integer().nullable().references(Shifts, #localId)();
  IntColumn get branchServerId => integer().nullable()();
  IntColumn get cashierServerId => integer().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get reason => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtLocal =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SalesReturnItemDb')
class SalesReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnLocalId => integer().references(SalesReturns, #localId)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get serverProductId => integer().nullable()();
  TextColumn get nameSnapshot => text().withDefault(const Constant(''))();
  IntColumn get qty => integer()();
  RealColumn get price => real()();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

@DriftDatabase(
  tables: [
    Products,
    Settings,
    InvoiceTemplates,
    ApiMeta,
    ProductCategories,
    PrintStations,
    Workstations,
    Printers,
    PrinterStationMap,
    Sales,
    SaleItems,
    SaleItemAddons,
    SalePayments,
    Customers,
    PrintJobs,
    SyncQueue,
    Shifts,
    Services,
    PosTables,
    Brands,
    AddonGroups,
    AddonItems,
    ProductAddonLinks,
    ReceiptVouchers,
    PaymentVouchers,
    SalesReturns,
    SalesReturnItems,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  static const String aggregateStationCode = '__ALL_STATIONS__';
  static const Map<String, String> _defaultPosFeatureSettings = {
    'pos.show_services': '1',
    'pos.show_tables': '1',
    'pos.show_brands': '1',
    'pos.show_receipt_voucher': '1',
    'pos.show_payment_voucher': '1',
    'pos.show_sales_return': '1',
    'pos.print_service_in_invoice': '1',
    'pos.print_table_in_invoice': '1',
    'pos.print_category_in_invoice': '1',
  };

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _ensurePosFeatureSettings();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(sales);
        await m.createTable(saleItems);
      }

      if (from < 3) {
        await m.createTable(printStations);
        await m.createTable(printers);
        await m.createTable(salePayments);
        await m.createTable(printJobs);

        if (from >= 2) {
          await m.addColumn(sales, sales.serverSaleId);
          await m.addColumn(sales, sales.invoiceNo);
          await m.addColumn(sales, sales.branchServerId);
          await m.addColumn(sales, sales.cashierServerId);
          await m.addColumn(sales, sales.subtotal);
          await m.addColumn(sales, sales.tax);
          await m.addColumn(sales, sales.discount);
          await m.addColumn(sales, sales.paidTotal);
          await m.addColumn(sales, sales.remaining);
          await m.addColumn(sales, sales.syncStatus);
          await m.addColumn(sales, sales.syncError);
          await m.addColumn(sales, sales.completedAtLocal);

          await m.addColumn(saleItems, saleItems.nameSnapshot);
          await m.addColumn(saleItems, saleItems.total);
          await m.addColumn(saleItems, saleItems.stationCode);
          await m.addColumn(saleItems, saleItems.note);
        }
      }

      if (from < 4) {
        await m.createTable(syncQueue);
        await m.createTable(apiMeta);

        await m.addColumn(products, products.serverId);
        await m.addColumn(products, products.stationCode);
        await m.addColumn(products, products.isActive);
        await m.addColumn(products, products.isDeleted);
        await m.addColumn(products, products.deletedAtServer);
        await m.addColumn(products, products.updatedAtServer);

        if (from >= 2) {
          await m.addColumn(sales, sales.syncedAt);
          await m.addColumn(sales, sales.zatcaStatus);
          await m.addColumn(sales, sales.zatcaResponse);
          await m.addColumn(saleItems, saleItems.serverProductId);
        }

        if (from >= 3) {
          await m.addColumn(printStations, printStations.deletedAtServer);
          await m.addColumn(printers, printers.updatedAtLocal);
          await m.addColumn(salePayments, salePayments.serverPaymentId);
          await m.addColumn(printJobs, printJobs.payload);
          await m.addColumn(printJobs, printJobs.updatedAtLocal);
        }
      }

      if (from >= 3 && from < 6) {
        await m.alterTable(TableMigration(printers));
      }

      // ======= NEW (schema v7): workstations + printer mapping + printer extra columns =======
      if (from < 7) {
        await m.createTable(workstations);
        await m.createTable(printerStationMap);

        // إضافة أعمدة جديدة للطابعات
        await m.addColumn(printers, printers.branchServerId);
        await m.addColumn(printers, printers.workstationId);
        await m.addColumn(printers, printers.connectionType);

        await m.addColumn(printers, printers.usbVendorId);
        await m.addColumn(printers, printers.usbProductId);
        await m.addColumn(printers, printers.usbSerial);

        await m.addColumn(printers, printers.charPerLine);
        await m.addColumn(printers, printers.codePage);
        await m.addColumn(printers, printers.capabilityProfile);
        await m.addColumn(printers, printers.cutAfterPrint);
        await m.addColumn(printers, printers.openCashDrawer);

        await m.addColumn(printers, printers.isDeleted);
        await m.addColumn(printers, printers.deletedAtServer);
        await m.addColumn(printers, printers.serverId);
        await m.addColumn(printers, printers.updatedAtServer);

        await m.addColumn(printers, printers.lastSeenAt);

        // لو عندك تغييرات في شكل جدول printers، هذا يضمن تطبيقها
        await m.alterTable(TableMigration(printers));
      }

      // ======= NEW (schema v8): workstation serverId + mapping by workstation =======
      if (from < 8) {
        await m.addColumn(workstations, workstations.serverId);
        await m.addColumn(printerStationMap, printerStationMap.workstationId);
        await m.alterTable(TableMigration(printerStationMap));
      }

      // ======= NEW (schema v9): product categories + product image/category =======
      if (from < 9) {
        await m.createTable(productCategories);
        await m.addColumn(products, products.categoryId);
        await m.addColumn(products, products.imagePath);
      }

      // ======= NEW (schema v10): product category description =======
      if (from < 10) {
        await m.addColumn(productCategories, productCategories.description);
      }

      // ======= NEW (schema v11): product image bytes =======
      if (from < 11) {
        await m.addColumn(products, products.imageData);
      }

      // ======= NEW (schema v12): category station code =======
      if (from < 12) {
        await m.addColumn(
          productCategories,
          productCategories.stationCode as GeneratedColumn<Object>,
        );
      }

      // ======= NEW (schema v13): invoice templates =======
      if (from < 13) {
        await m.createTable(invoiceTemplates);
      }
      if (from < 14) {
        await m.createTable(customers);
      }
      if (from < 15) {
        await m.addColumn(sales, sales.dailyOrderNo);
      }

      if (from < 16) {
        await _createTableIfMissing(m, shifts, 'shifts');
        await _createTableIfMissing(m, services, 'services');
        await _createTableIfMissing(m, posTables, 'tables');
        await _createTableIfMissing(m, brands, 'brands');
        await _createTableIfMissing(m, receiptVouchers, 'receipt_vouchers');
        await _createTableIfMissing(m, paymentVouchers, 'payment_vouchers');
        await _createTableIfMissing(m, salesReturns, 'sales_returns');
        await _createTableIfMissing(m, salesReturnItems, 'sales_return_items');

        await _addColumnIfMissing(
          m,
          products,
          products.brandId,
          tableName: 'products',
          columnName: 'brand_id',
        );

        await _addColumnIfMissing(
          m,
          sales,
          sales.customerId,
          tableName: 'sales',
          columnName: 'customer_id',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.serviceId,
          tableName: 'sales',
          columnName: 'service_id',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.serviceNameSnapshot,
          tableName: 'sales',
          columnName: 'service_name_snapshot',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.serviceCost,
          tableName: 'sales',
          columnName: 'service_cost',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.tableId,
          tableName: 'sales',
          columnName: 'table_id',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.tableNameSnapshot,
          tableName: 'sales',
          columnName: 'table_name_snapshot',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.shiftLocalId,
          tableName: 'sales',
          columnName: 'shift_local_id',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.note,
          tableName: 'sales',
          columnName: 'note',
        );
        await _addColumnIfMissing(
          m,
          sales,
          sales.itemsCount,
          tableName: 'sales',
          columnName: 'items_count',
        );

        await _addColumnIfMissing(
          m,
          saleItems,
          saleItems.categoryId,
          tableName: 'sale_items',
          columnName: 'category_id',
        );
        await _addColumnIfMissing(
          m,
          saleItems,
          saleItems.categoryNameSnapshot,
          tableName: 'sale_items',
          columnName: 'category_name_snapshot',
        );

        await _ensurePosFeatureSettings();
      }

      if (from < 17) {
        await _addColumnIfMissing(
          m,
          products,
          products.description,
          tableName: 'products',
          columnName: 'description',
        );
      }

      if (from < 18) {
        await _createTableIfMissing(m, addonGroups, 'addon_groups');
        await _createTableIfMissing(m, addonItems, 'addon_items');
        await _createTableIfMissing(
          m,
          productAddonLinks,
          'product_addon_links',
        );
      }

      if (from < 19) {
        await _createTableIfMissing(m, saleItemAddons, 'sale_item_addons');
      }

      if (from < 20) {
        await _addColumnIfMissing(
          m,
          receiptVouchers,
          receiptVouchers.customerName,
          tableName: 'receipt_vouchers',
          columnName: 'customer_name',
        );
      }
    },
    beforeOpen: (details) async {
      await _normalizePrintJobDateColumns();
    },
  );

  Future<void> _createTableIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    String tableName,
  ) async {
    if (!await _tableExists(tableName)) {
      await m.createTable(table);
    }
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn column, {
    required String tableName,
    required String columnName,
  }) async {
    if (!await _columnExists(tableName, columnName)) {
      await m.addColumn(table, column);
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final row = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: [Variable.withString('table'), Variable.withString(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info("$tableName")').get();
    for (final row in rows) {
      final current = row.read<String>('name');
      if (current.toLowerCase() == columnName.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensurePosFeatureSettings() async {
    for (final entry in _defaultPosFeatureSettings.entries) {
      final exists =
          await (select(settings)
                ..where((t) => t.key.equals(entry.key))
                ..limit(1))
              .getSingleOrNull();
      if (exists != null) continue;
      await into(settings).insertOnConflictUpdate(
        SettingsCompanion(key: Value(entry.key), value: Value(entry.value)),
      );
    }
  }

  Future<void> _normalizePrintJobDateColumns() async {
    if (!await _tableExists('print_jobs')) return;

    Future<void> normalizeColumn(String columnName) async {
      await customStatement('''
        UPDATE print_jobs
        SET $columnName = CAST(strftime('%s', $columnName) AS INTEGER)
        WHERE typeof($columnName) = 'text'
          AND $columnName IS NOT NULL
          AND trim($columnName) <> '';
        ''');
    }

    await normalizeColumn('created_at');
    await normalizeColumn('updated_at_local');
    await normalizeColumn('printed_at');
  }

  // ===== Products =====
  Future<List<ProductDb>> getAllProducts() => select(products).get();

  Stream<List<ProductDb>> watchProducts() {
    return (select(products)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> upsertProducts(List<ProductsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(products, items);
    });
  }

  Future<void> archiveProductsByIds(Iterable<int> ids) async {
    final targetIds = ids.where((id) => id > 0).toSet().toList();
    if (targetIds.isEmpty) return;

    await (update(products)..where((t) => t.id.isIn(targetIds))).write(
      ProductsCompanion(
        isDeleted: const Value(true),
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<ProductDb>> getProductsChangedSince(DateTime since) {
    return (select(products)..where(
          (t) =>
              (t.updatedAtServer.isNotNull() &
                  t.updatedAtServer.isBiggerThanValue(since)) |
              (t.deletedAtServer.isNotNull() &
                  t.deletedAtServer.isBiggerThanValue(since)) |
              (t.updatedAt.isNotNull() & t.updatedAt.isBiggerThanValue(since)),
        ))
        .get();
  }

  Future<void> clearProducts() => delete(products).go();

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(printJobs).go();
      await delete(salePayments).go();
      await delete(saleItemAddons).go();
      await delete(saleItems).go();
      await delete(salesReturnItems).go();
      await delete(salesReturns).go();
      await delete(receiptVouchers).go();
      await delete(paymentVouchers).go();
      await delete(sales).go();
      await delete(shifts).go();
      await delete(customers).go();
      await delete(services).go();
      await delete(posTables).go();
      await delete(brands).go();
      await delete(productAddonLinks).go();
      await delete(addonItems).go();
      await delete(addonGroups).go();

      await delete(printerStationMap).go();
      await delete(printers).go();
      await delete(workstations).go();
      await delete(printStations).go();

      await delete(products).go();
      await delete(productCategories).go();

      await delete(invoiceTemplates).go();
      await delete(apiMeta).go();
      await delete(settings).go();
      await delete(syncQueue).go();
    });
  }

  Future<int> getNextProductId() async {
    final latest =
        await (select(products)
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    return (latest?.id ?? 0) + 1;
  }

  // ===== Settings =====
  Future<String?> getSetting(String k) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(k))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String k) {
    return (select(
      settings,
    )..where((t) => t.key.equals(k))).watchSingleOrNull().map((row) {
      return row?.value;
    });
  }

  Future<void> setSetting(String k, String? v) async {
    await into(
      settings,
    ).insertOnConflictUpdate(SettingsCompanion(key: Value(k), value: Value(v)));
  }

  // ===== Invoice Templates =====
  Stream<List<InvoiceTemplateDb>> watchInvoiceTemplates(int paperSize) {
    return (select(invoiceTemplates)
          ..where((t) => t.paperSize.equals(paperSize))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isDefault, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .watch();
  }

  Future<InvoiceTemplateDb?> getDefaultInvoiceTemplate(int paperSize) {
    return (select(invoiceTemplates)
          ..where((t) => t.paperSize.equals(paperSize))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isDefault, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> upsertInvoiceTemplate(InvoiceTemplatesCompanion template) {
    return into(invoiceTemplates).insertOnConflictUpdate(template);
  }

  Future<void> setDefaultInvoiceTemplate(int templateId) async {
    final template = await (select(
      invoiceTemplates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    if (template == null) return;
    await transaction(() async {
      await (update(invoiceTemplates)
            ..where((t) => t.paperSize.equals(template.paperSize)))
          .write(const InvoiceTemplatesCompanion(isDefault: Value(false)));
      await (update(invoiceTemplates)..where((t) => t.id.equals(templateId)))
          .write(const InvoiceTemplatesCompanion(isDefault: Value(true)));
    });
  }

  Future<void> deleteInvoiceTemplate(int templateId) async {
    await (delete(
      invoiceTemplates,
    )..where((t) => t.id.equals(templateId))).go();
  }

  Future<void> ensureDefaultInvoiceTemplates() async {
    final existing = await (select(
      invoiceTemplates,
    )..limit(1)).getSingleOrNull();
    if (existing != null) return;
    await batch((b) {
      b.insertAll(invoiceTemplates, [
        InvoiceTemplatesCompanion.insert(
          name: 'قالب 80mm',
          paperSize: 80,
          isDefault: const Value(true),
          headerTitle: const Value('فاتورة ضريبية مبسطة'),
        ),
        InvoiceTemplatesCompanion.insert(
          name: 'قالب A4',
          paperSize: 210,
          isDefault: const Value(true),
          headerTitle: const Value('فاتورة ضريبية مبسطة'),
        ),
      ]);
    });
  }

  // ===== Api Meta =====
  Future<String?> getApiMeta(String k) async {
    final row = await (select(
      apiMeta,
    )..where((t) => t.key.equals(k))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setApiMeta(String k, String? v) async {
    await into(
      apiMeta,
    ).insertOnConflictUpdate(ApiMetaCompanion(key: Value(k), value: Value(v)));
  }

  // ===== Product Categories =====
  Stream<List<ProductCategoryDb>> watchProductCategories() {
    return (select(productCategories)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<ProductCategoryDb>> getProductCategories() {
    return (select(productCategories)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<int> upsertProductCategory(ProductCategoriesCompanion category) {
    return into(productCategories).insertOnConflictUpdate(category);
  }

  Future<void> assignCategoriesToStation({
    required List<int> categoryIds,
    required String stationCode,
  }) async {
    final cleaned = categoryIds.where((id) => id > 0).toSet().toList();
    if (cleaned.isEmpty) return;
    await (update(productCategories)..where((t) => t.id.isIn(cleaned))).write(
      ProductCategoriesCompanion(
        stationCode: Value(
          stationCode.trim().isEmpty ? null : stationCode.trim(),
        ),
      ),
    );
  }

  // ===== Services =====
  Stream<List<ServiceDb>> watchServices({bool activeOnly = false}) {
    final query = select(services)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch();
  }

  Future<List<ServiceDb>> getServices({bool activeOnly = false}) {
    final query = select(services)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.get();
  }

  Future<int> upsertService(ServicesCompanion service) {
    return into(services).insertOnConflictUpdate(service);
  }

  Future<void> softDeleteService(int id) {
    return (update(services)..where((t) => t.id.equals(id))).write(
      ServicesCompanion(
        isDeleted: const Value(true),
        isActive: const Value(false),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
  }

  // ===== POS Tables =====
  Stream<List<PosTableDb>> watchPosTables({bool activeOnly = false}) {
    final query = select(posTables)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.sortOrder),
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch();
  }

  Future<List<PosTableDb>> getPosTables({bool activeOnly = false}) {
    final query = select(posTables)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.sortOrder),
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.get();
  }

  Future<int> upsertPosTable(PosTablesCompanion table) {
    return into(posTables).insertOnConflictUpdate(table);
  }

  Future<int> getNextTableSortOrder() async {
    final lastRow =
        await (select(posTables)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.sortOrder,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    return (lastRow?.sortOrder ?? 0) + 1;
  }

  Future<void> softDeletePosTable(int id) {
    return (update(posTables)..where((t) => t.id.equals(id))).write(
      PosTablesCompanion(
        isDeleted: const Value(true),
        isActive: const Value(false),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
  }

  // ===== Brands =====
  Stream<List<BrandDb>> watchBrands({bool activeOnly = false}) {
    final query = select(brands)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch();
  }

  Future<List<BrandDb>> getBrands({bool activeOnly = false}) {
    final query = select(brands)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.get();
  }

  Future<int> upsertBrand(BrandsCompanion brand) {
    return into(brands).insertOnConflictUpdate(brand);
  }

  Future<void> softDeleteBrand(int id) {
    return (update(brands)..where((t) => t.id.equals(id))).write(
      BrandsCompanion(
        isDeleted: const Value(true),
        isActive: const Value(false),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
  }

  // ===== Product Add-ons =====
  Stream<List<AddonGroupDb>> watchAddonGroups({bool activeOnly = false}) {
    final query = select(addonGroups)..where((t) => t.isDeleted.equals(false));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch();
  }

  Stream<List<AddonItemDb>> watchAddonItems() {
    return (select(addonItems)..orderBy([
          (t) => OrderingTerm(expression: t.groupId),
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  Stream<List<ProductAddonLinkDb>> watchProductAddonLinks() {
    return (select(productAddonLinks)..orderBy([
          (t) => OrderingTerm(expression: t.groupId),
          (t) => OrderingTerm(expression: t.productId),
        ]))
        .watch();
  }

  Future<int> upsertAddonGroup(AddonGroupsCompanion group) {
    return into(addonGroups).insertOnConflictUpdate(group);
  }

  Future<void> replaceAddonItems(
    int groupId,
    List<AddonItemsCompanion> items,
  ) async {
    await transaction(() async {
      await (delete(addonItems)..where((t) => t.groupId.equals(groupId))).go();
      if (items.isNotEmpty) {
        await batch((b) {
          b.insertAll(addonItems, items);
        });
      }
    });
  }

  Future<void> replaceGroupProductAddonLinks(
    int groupId,
    List<int> productIds,
  ) async {
    await transaction(() async {
      await (delete(
        productAddonLinks,
      )..where((t) => t.groupId.equals(groupId))).go();
      if (productIds.isNotEmpty) {
        await batch((b) {
          b.insertAll(productAddonLinks, [
            for (final productId in productIds)
              ProductAddonLinksCompanion.insert(
                groupId: groupId,
                productId: productId,
              ),
          ]);
        });
      }
    });
  }

  Future<void> softDeleteAddonGroup(int groupId) async {
    await transaction(() async {
      await (update(addonGroups)..where((t) => t.id.equals(groupId))).write(
        AddonGroupsCompanion(
          isDeleted: const Value(true),
          isActive: const Value(false),
          updatedAtLocal: Value(DateTime.now()),
        ),
      );
      await (delete(addonItems)..where((t) => t.groupId.equals(groupId))).go();
      await (delete(
        productAddonLinks,
      )..where((t) => t.groupId.equals(groupId))).go();
    });
  }

  // ===== Print Stations =====
  Stream<List<PrintStationDb>> watchPrintStations() {
    return (select(printStations)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<PrintStationDb>> getPrintStations() {
    return (select(printStations)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<int> upsertPrintStation({
    int? id,
    required String code,
    required String name,
    int? serverId,
  }) {
    return into(printStations).insertOnConflictUpdate(
      PrintStationsCompanion(
        id: id == null ? const Value.absent() : Value(id),
        code: Value(code),
        name: Value(name),
        serverId: Value(serverId),
      ),
    );
  }

  Future<void> upsertStations(List<PrintStationsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(printStations, items);
    });
  }

  // ===== Workstations =====
  Future<int> upsertWorkstation({
    required String deviceId,
    String name = '',
    int? serverId,
    int? branchServerId,
  }) async {
    final existing =
        await (select(workstations)
              ..where((t) => t.deviceId.equals(deviceId))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      return into(workstations).insert(
        WorkstationsCompanion.insert(
          deviceId: deviceId,
          name: Value(name),
          serverId: Value(serverId),
          branchServerId: Value(branchServerId),
          lastSeenAt: Value(DateTime.now()),
        ),
      );
    } else {
      await (update(
        workstations,
      )..where((t) => t.id.equals(existing.id))).write(
        WorkstationsCompanion(
          name: Value(name),
          serverId: Value(serverId),
          branchServerId: Value(branchServerId),
          lastSeenAt: Value(DateTime.now()),
          updatedAtLocal: Value(DateTime.now()),
        ),
      );
      return existing.id;
    }
  }

  Future<WorkstationDb?> getCurrentWorkstation() {
    return (select(workstations)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.lastSeenAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(
              expression: t.updatedAtLocal,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  // ===== Printers =====
  Future<void> upsertPrinters(List<PrintersCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(printers, items);
    });
  }

  Stream<List<PrinterDb>> watchPrintersForWorkstation(int workstationId) {
    return (select(
      printers,
    )..where((t) => t.workstationId.equals(workstationId))).watch();
  }

  /// ربط طابعة مع عدة أقسام
  Future<void> setPrinterStations({
    required int printerId,
    required List<String> stationCodes,
  }) async {
    final cleaned = stationCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    await transaction(() async {
      // نحذف القديم ثم نضيف الجديد (سهل وبسيط)
      await (delete(
        printerStationMap,
      )..where((t) => t.printerId.equals(printerId))).go();

      if (cleaned.isEmpty) return;

      final rows = cleaned
          .map(
            (code) => PrinterStationMapCompanion.insert(
              printerId: printerId,
              stationCode: code,
            ),
          )
          .toList();

      await batch((b) => b.insertAll(printerStationMap, rows));
    });
  }

  Future<void> setPrinterStationsForWorkstation({
    required int workstationId,
    required int printerId,
    required List<String> stationCodes,
  }) async {
    final cleanedSet = stationCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final cleaned = cleanedSet.toList();

    await transaction(() async {
      await (delete(printerStationMap)..where(
            (t) =>
                t.printerId.equals(printerId) &
                t.workstationId.equals(workstationId),
          ))
          .go();

      if (cleaned.isEmpty) return;

      await (delete(printerStationMap)..where(
            (t) =>
                t.workstationId.equals(workstationId) &
                t.stationCode.isIn(cleaned),
          ))
          .go();

      final rows = cleaned
          .map(
            (code) => PrinterStationMapCompanion.insert(
              printerId: printerId,
              stationCode: code,
              workstationId: Value(workstationId),
            ),
          )
          .toList();

      await batch((b) => b.insertAll(printerStationMap, rows));
    });
  }

  /// اختيار طابعة للقسم:
  /// 1) يفضّل طابعة مرتبطة عبر PrinterStationMap
  /// 2) لو ما في، يرجع للطريقة القديمة (printers.stationCode)
  Future<PrinterDb?> getPrinterForStation(String stationCode) async {
    final code = stationCode.trim();
    if (code.isEmpty) return null;

    // أولاً: عبر mapping
    final mapped =
        await (select(printerStationMap).join([
                innerJoin(
                  printers,
                  printers.id.equalsExp(printerStationMap.printerId),
                ),
              ])
              ..where(
                printerStationMap.stationCode.equals(code) &
                    printerStationMap.workstationId.isNull() &
                    printerStationMap.enabled.equals(true) &
                    printers.enabled.equals(true) &
                    printers.isDeleted.equals(false),
              )
              ..orderBy([
                OrderingTerm(
                  expression: printers.lastTestAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(expression: printers.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (mapped != null) {
      return mapped.readTable(printers);
    }

    // ثانياً: fallback legacy
    return (select(printers)
          ..where(
            (t) =>
                t.stationCode.equals(code) &
                t.enabled.equals(true) &
                t.isDeleted.equals(false),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.lastTestAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PrinterDb?> resolvePrinterForStation(
    String stationCode, {
    required int workstationId,
  }) async {
    final code = stationCode.trim();
    if (code.isEmpty) return null;

    final mapped =
        await (select(printerStationMap).join([
                innerJoin(
                  printers,
                  printers.id.equalsExp(printerStationMap.printerId),
                ),
              ])
              ..where(
                printerStationMap.stationCode.equals(code) &
                    printerStationMap.workstationId.equals(workstationId) &
                    printerStationMap.enabled.equals(true) &
                    printers.enabled.equals(true) &
                    printers.isDeleted.equals(false),
              )
              ..orderBy([
                OrderingTerm(
                  expression: printers.lastTestAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(expression: printers.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (mapped != null) {
      return mapped.readTable(printers);
    }

    return getPrinterForStation(code);
  }

  static bool isAggregatePrinterType(String type) {
    final normalized = type.trim().replaceAll(' ', '');
    if (normalized.isEmpty) return false;
    if (normalized == 'مجمعه' || normalized == 'مجمعة') return true;

    final upper = normalized.toUpperCase();
    return upper == 'AGGREGATE' || upper == 'AGGREGATED' || upper == 'GROUPED';
  }

  Future<PrinterDb?> getAggregatePrinter({int? workstationId}) async {
    final query = select(printers)
      ..where((t) => t.enabled.equals(true) & t.isDeleted.equals(false));

    if (workstationId != null) {
      query.where(
        (t) => t.workstationId.equals(workstationId) | t.workstationId.isNull(),
      );
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.lastTestAt, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();
    for (final printer in rows) {
      if (isAggregatePrinterType(printer.type)) {
        return printer;
      }
    }
    return null;
  }

  Future<void> setPrinterForStation({
    required int workstationId,
    required String stationCode,
    required int printerId,
    bool enabled = true,
  }) async {
    final code = stationCode.trim();
    if (code.isEmpty) return;

    await into(printerStationMap).insertOnConflictUpdate(
      PrinterStationMapCompanion.insert(
        workstationId: Value(workstationId),
        printerId: printerId,
        stationCode: code,
        enabled: Value(enabled),
      ),
    );
  }

  // ===== Sales =====
  Future<int> insertSale(SalesCompanion sale) => into(sales).insert(sale);

  Future<int> nextDailyOrderNo({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final countExpr = sales.localId.count();

    final row =
        await (selectOnly(sales)
              ..addColumns([countExpr])
              ..where(
                sales.createdAt.isBiggerOrEqualValue(dayStart) &
                    sales.createdAt.isSmallerThanValue(dayEnd) &
                    sales.status.equals('QUOTATION').not(),
              ))
            .getSingle();

    return (row.read(countExpr) ?? 0) + 1;
  }

  Future<void> insertSaleItems(List<SaleItemsCompanion> items) async {
    await batch((b) {
      b.insertAll(saleItems, items);
    });
  }

  Future<int> insertSaleWithItemsAndPayments({
    required SalesCompanion sale,
    required List<SaleItemsCompanion> items,
    List<SalePaymentsCompanion> payments = const [],
  }) async {
    return transaction(() async {
      final saleId = await into(sales).insert(sale);

      if (items.isNotEmpty) {
        final normalizedItems = items
            .map(
              (item) => item.copyWith(
                saleLocalId: item.saleLocalId.present
                    ? item.saleLocalId
                    : Value(saleId),
              ),
            )
            .toList();
        await batch((b) => b.insertAll(saleItems, normalizedItems));
      }

      if (payments.isNotEmpty) {
        final normalizedPayments = payments
            .map(
              (payment) => payment.copyWith(
                saleLocalId: payment.saleLocalId.present
                    ? payment.saleLocalId
                    : Value(saleId),
              ),
            )
            .toList();
        await batch((b) => b.insertAll(salePayments, normalizedPayments));
      }

      return saleId;
    });
  }

  // ===== Customers =====
  Stream<List<CustomerDb>> watchCustomers() {
    return (select(
      customers,
    )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<int> insertCustomer(CustomersCompanion customer) {
    return into(customers).insert(customer);
  }

  Future<void> enqueueSaleForSync(int saleLocalId) async {
    final existing =
        await (select(syncQueue)
              ..where(
                (t) =>
                    t.entityType.equals('sale') &
                    t.entityLocalId.equals(saleLocalId) &
                    t.action.equals('UPSERT') &
                    t.status.isNotIn(['DONE']),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) return;

    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: 'sale',
        entityLocalId: saleLocalId,
        action: 'UPSERT',
      ),
    );
  }

  Stream<List<SyncQueueDb>> watchPendingSyncQueue() {
    return (select(syncQueue)
          ..where((t) => t.status.isIn(['PENDING', 'FAILED']))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<void> markSyncQueueDone(int id) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('DONE'),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSyncQueueFailed(int id, String error) async {
    final row = await (select(
      syncQueue,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('FAILED'),
        tries: Value(row.tries + 1),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> createPrintJobsForSale(
    int saleLocalId, {
    String? payload,
  }) async {
    await transaction(() async {
      final items = await (select(
        saleItems,
      )..where((t) => t.saleLocalId.equals(saleLocalId))).get();

      final stationCodes = items
          .map((item) => item.stationCode.trim())
          .where((code) => code.isNotEmpty)
          .toSet();

      final existingJobs = await (select(
        printJobs,
      )..where((t) => t.saleLocalId.equals(saleLocalId))).get();

      final existingCodes = existingJobs
          .map((job) => job.stationCode.trim())
          .where((code) => code.isNotEmpty)
          .toSet();

      final jobs = <PrintJobsCompanion>[];

      final workstation = await getCurrentWorkstation();

      for (final code in stationCodes) {
        if (existingCodes.contains(code)) continue;
        final resolvedPrinter = workstation == null
            ? await getPrinterForStation(code)
            : await resolvePrinterForStation(
                code,
                workstationId: workstation.id,
              );

        jobs.add(
          PrintJobsCompanion.insert(
            saleLocalId: saleLocalId,
            stationCode: code,
            printerId: Value(resolvedPrinter?.id),
            jobType: 'STATION_TICKET',
            payload: Value(payload),
          ),
        );
      }

      if (!existingCodes.contains('CASHIER')) {
        final aggregatePrinter = workstation == null
            ? await getAggregatePrinter()
            : await getAggregatePrinter(workstationId: workstation.id);
        final resolvedCashierPrinter = workstation == null
            ? await getPrinterForStation('CASHIER')
            : await resolvePrinterForStation(
                'CASHIER',
                workstationId: workstation.id,
              );
        final cashierPrinter = resolvedCashierPrinter ?? aggregatePrinter;
        jobs.add(
          PrintJobsCompanion.insert(
            saleLocalId: saleLocalId,
            stationCode: 'CASHIER',
            printerId: Value(cashierPrinter?.id),
            jobType: 'CUSTOMER_RECEIPT',
            payload: Value(payload),
          ),
        );
      }

      if (jobs.isNotEmpty) {
        await batch((b) {
          b.insertAll(printJobs, jobs);
        });
      }
    });
  }

  Stream<List<PrintJobDb>> watchPendingPrintJobs() {
    return (select(
      printJobs,
    )..where((t) => t.status.isIn(['PENDING', 'FAILED']))).watch();
  }

  Future<void> markPrintJobPrinted(int jobId) async {
    await (update(printJobs)..where((t) => t.id.equals(jobId))).write(
      PrintJobsCompanion(
        status: const Value('PRINTED'),
        printedAt: Value(DateTime.now()),
        lastError: const Value(null),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markPrintJobFailed(int jobId, String error) async {
    final job = await (select(
      printJobs,
    )..where((t) => t.id.equals(jobId))).getSingleOrNull();
    if (job == null) return;

    await (update(printJobs)..where((t) => t.id.equals(jobId))).write(
      PrintJobsCompanion(
        status: const Value('FAILED'),
        tries: Value(job.tries + 1),
        lastError: Value(error),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'montex_pos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
