import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../cart_provider.dart';
import '../pos_controller.dart';
import '../suspended_sales_provider.dart';

class SuspendedSalesDialog extends ConsumerWidget {
  const SuspendedSalesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(suspendedSalesProvider);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    const Expanded(
                      child: Text(
                        'مبيعات معلقة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: sales.isEmpty
                    ? const Center(child: Text('لا توجد مبيعات معلقة'))
                    : Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
                          child: Wrap(
                            spacing: 30,
                            runSpacing: 24,
                            alignment: WrapAlignment.center,
                            children: sales
                                .map(
                                  (sale) => _SuspendedSaleCard(sale: sale),
                                )
                                .toList(),
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuspendedSaleCard extends ConsumerWidget {
  const _SuspendedSaleCard({required this.sale});

  final SuspendedSale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateText = DateFormat('dd-MM-yyyy').format(sale.createdAt);
    final shortId = sale.id.length > 6 ? sale.id.substring(sale.id.length - 6) : sale.id;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFA43B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  sale.note.isEmpty ? 'بدون تعليق' : sale.note,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  shortId,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'عدد العناصر: ${sale.itemCount}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'المجموع: ${sale.totalAfterDiscount.toStringAsFixed(2)} ريال',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(cartProvider.notifier).setItems(sale.items);
                ref.read(posControllerProvider.notifier).setDiscount(sale.discountType, sale.discountValue);
                ref.read(posControllerProvider.notifier).clearPayments();
                ref.read(suspendedSalesProvider.notifier).removeSale(sale.id);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0067B8),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              icon: const Icon(AppIcons.edit, size: 16, color: Colors.white),
              label: const Text('تعديل البيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(suspendedSalesProvider.notifier).removeSale(sale.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF1744),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              icon: const Icon(Icons.delete, size: 16, color: Colors.white),
              label: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

