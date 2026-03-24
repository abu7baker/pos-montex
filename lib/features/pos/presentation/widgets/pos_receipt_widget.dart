import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InvoiceItem {
  const InvoiceItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  final String name;
  final double qty;
  final double price;
  final double total;
}

class InvoiceData {
  const InvoiceData({
    required this.companyName,
    required this.branch,
    required this.mobile,
    required this.taxNumber,
    required this.crNumber,
    required this.invoiceNumber,
    required this.dateTime,
    required this.customerName,
    required this.items,
    required this.totalQty,
    required this.subTotal,
    required this.discount,
    required this.grandTotal,
    required this.grandTotalInWords,
    required this.paymentMethod,
    required this.paidAmount,
    required this.dueAmount,
    required this.qrCodeData,
  });

  final String companyName;
  final String branch;
  final String mobile;
  final String taxNumber;
  final String crNumber;

  final String invoiceNumber;
  final String dateTime;
  final String customerName;

  final List<InvoiceItem> items;

  final double totalQty;
  final double subTotal;
  final double discount;
  final double grandTotal;
  final String grandTotalInWords;

  final String paymentMethod;
  final double paidAmount;
  final double dueAmount;

  final String qrCodeData;
}

class PosReceiptWidget extends StatelessWidget {
  const PosReceiptWidget({
    super.key,
    required this.invoiceData,
    this.width = 400,
  });

  final InvoiceData invoiceData;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 10),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildInvoiceMeta(),
              const SizedBox(height: 10),
              _buildItemsTable(),
              const SizedBox(height: 10),
              _buildSummarySection(),
              const SizedBox(height: 8),
              _buildPaymentSection(),
              const SizedBox(height: 18),
              _buildQrSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.image_outlined, size: 40, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          invoiceData.companyName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          invoiceData.branch,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'الموبايل: ${invoiceData.mobile}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'الرقم الضريبي: ${invoiceData.taxNumber}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'السجل التجاري: ${invoiceData.crNumber}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return const Text(
      'فاتورة ضريبية مبسطة',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInvoiceMeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _metaLine('رقم الفاتورة', invoiceData.invoiceNumber),
        _metaLine('التاريخ والوقت', invoiceData.dateTime),
        _metaLine('اسم العميل', invoiceData.customerName),
      ],
    );
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$label : $value',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }





  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const DottedLine(dashColor: Colors.black),
          ..._buildTableRows(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _tableCell('الصنف', flex: 4, align: TextAlign.right, bold: true),
            _verticalDotted(),
            _tableCell('العدد', flex: 1, align: TextAlign.center, bold: true),
            _verticalDotted(),
            _tableCell('السعر', flex: 1, align: TextAlign.center, bold: true),
            _verticalDotted(),
            _tableCell('المجموع', flex: 1, align: TextAlign.center, bold: true),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTableRows() {
    final rows = <Widget>[];
    for (var i = 0; i < invoiceData.items.length; i++) {
      final item = invoiceData.items[i];
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _tableCell(item.name, flex: 4, align: TextAlign.right),
                _verticalDotted(),
                _tableCell(_formatNumber(item.qty), flex: 1, align: TextAlign.left),
                _verticalDotted(),
                _tableCell(_formatNumber(item.price), flex: 1, align: TextAlign.left),
                _verticalDotted(),
                _tableCell(_formatNumber(item.total), flex: 1, align: TextAlign.left),
              ],
            ),
          ),
        ),
      );
      if (i != invoiceData.items.length - 1) {
        rows.add(const DottedLine(dashColor: Colors.black));
      }
    }
    return rows;
  }

  Widget _tableCell(String text, {required int flex, required TextAlign align, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

    Widget _verticalDotted() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 18.0;
        return SizedBox(
          width: 1,
          height: height,
          child: DottedLine(
            direction: Axis.vertical,
            dashColor: Colors.black,
            lineThickness: 1,
            dashLength: 3,
            dashGapLength: 3,
            lineLength: height,
          ),
        );
      },
    );
  }


  Widget _buildSummarySection() {
    return Column(
      children: [
        _summaryRow('إجمالي العدد', _formatNumber(invoiceData.totalQty)),
        _summaryRow('الإجمالي قبل الضريبة:', _formatCurrency(invoiceData.subTotal)),
        _summaryRow('الخصم:', _formatDiscount(invoiceData.discount)),
        _summaryRow('الإجمالي شامل الضريبة:', _formatCurrency(invoiceData.grandTotal), showDivider: false),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '(${invoiceData.grandTotalInWords})',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }




  Widget _buildPaymentSection() {
    return Column(
      children: [
        _summaryRow(invoiceData.paymentMethod, _formatCurrency(invoiceData.grandTotal)),
        _summaryRow('المبلغ المدفوع', _formatCurrency(invoiceData.paidAmount)),
        _summaryRow('إجمالي المستحق', _formatCurrency(invoiceData.dueAmount), showDivider: false),
      ],
    );
  }




  Widget _summaryRow(String label, String value, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 10, thickness: 0.6, color: Colors.black12),
      ],
    );
  }





      Widget _buildQrSection() {
    return Center(
      child: QrImageView(
        data: invoiceData.qrCodeData,
        size: 120,
        backgroundColor: Colors.white,
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double value) {
    return '${_formatNumber(value)} ريال';
  }

  String _formatDiscount(double value) {
    return '${_formatNumber(value)} ريال (-)';
  }
}

