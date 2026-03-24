import 'dart:ui' as ui;

import 'package:data_table_2/data_table_2.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_db.dart';

class ProductsTableScreen extends StatefulWidget {
  const ProductsTableScreen({super.key, required this.db});

  final AppDb db;

  @override
  State<ProductsTableScreen> createState() => _ProductsTableScreenState();
}

class _ProductsTableScreenState extends State<ProductsTableScreen> {
  late final AppDb db;

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    db = widget.db;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  int _newId() => DateTime.now().microsecondsSinceEpoch;

  Future<void> _addProduct() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    if (name.isEmpty) return;

    await db.into(db.products).insertOnConflictUpdate(
      ProductsCompanion(
        id: drift.Value(_newId()),
        name: drift.Value(name),
        price: drift.Value(price),
        stock: drift.Value(stock),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    _nameCtrl.clear();
    _priceCtrl.text = '0';
    _stockCtrl.text = '0';
  }

  Future<void> _deleteProduct(int id) async {
    await (db.delete(db.products)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _clearProducts() async {
    await db.delete(db.products).go();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          title: const Text('جدول المنتجات (قاعدة البيانات المحلية)'),
          actions: [
            IconButton(
              tooltip: 'مسح كل المنتجات',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    alignment: Alignment.topCenter,
                    insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
                    title: const Text('تأكيد'),
                    content: const Text('هل تريد حذف كل المنتجات؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) await _clearProducts();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ====== Database header ======
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('الجدول: Products', style: AppTextStyles.topbarTitle),
                    SizedBox(height: 6),
                    Text(
                      'الأعمدة: id (int) • name (text) • price (real) • stock (int) • updated_at (datetime)',
                      style: AppTextStyles.topbarInfo,
                    ),
                  ],
                ),
              ),
            ),

            // ====== Add form ======
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المنتج',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'السعر',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المخزون',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ====== Table ======
            Expanded(
              child: StreamBuilder<List<ProductDb>>(
                stream: db.watchProducts(),
                builder: (context, snap) {
                  final rows = snap.data ?? const <ProductDb>[];

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عدد السجلات: ${rows.length}', style: AppTextStyles.topbarInfo),
                        const SizedBox(height: 8),
                        Expanded(
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 700,
                            headingRowHeight: 44,
                            dataRowHeight: 44,
                            columns: const [
                              DataColumn2(label: Text('ID'), fixedWidth: 100),
                              DataColumn2(label: Text('الاسم'), size: ColumnSize.L),
                              DataColumn2(label: Text('السعر'), fixedWidth: 120),
                              DataColumn2(label: Text('المخزون'), fixedWidth: 120),
                              DataColumn2(label: Text('إجراء'), fixedWidth: 120),
                            ],
                            rows: rows.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(Text('${p.id}')),
                                  DataCell(Text(p.name)),
                                  DataCell(Text('${p.price}')),
                                  DataCell(Text('${p.stock}')),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => _deleteProduct(p.id),
                                      child: const Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
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
      ),
    );
  }
}
