import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/database/app_db.dart';
import '../../../../core/printing/pdf_arabic_fonts.dart';
import '../data/cash_voucher_service.dart';

class CashVoucherPrinting {
  CashVoucherPrinting._();

  static Future<void> printReceiptVoucher({
    required ReceiptVoucherDb voucher,
    required String customerName,
    required String paymentMethod,
    required String accountName,
  }) async {
    await Printing.layoutPdf(
      name: 'receipt_voucher_${voucher.voucherNo ?? voucher.localId}',
      onLayout: (format) => _buildVoucherPdf(
        pageFormat: format,
        title: 'سند قبض',
        voucherNo: voucher.voucherNo?.trim().isNotEmpty == true
            ? voucher.voucherNo!.trim()
            : '#${voucher.localId}',
        date: voucher.createdAt,
        amount: voucher.amount,
        partyLabel: 'العميل',
        partyValue: customerName,
        methodLabel: 'طريقة الدفع',
        methodValue: paymentMethod,
        accountName: accountName,
        note: voucher.note,
        status: voucher.status,
      ),
    );
  }

  static Future<void> printPaymentVoucher({
    required PaymentVoucherDb voucher,
    required String supplierName,
    required String paymentMethod,
    required String accountName,
  }) async {
    await Printing.layoutPdf(
      name: 'payment_voucher_${voucher.voucherNo ?? voucher.localId}',
      onLayout: (format) => _buildVoucherPdf(
        pageFormat: format,
        title: 'سند صرف',
        voucherNo: voucher.voucherNo?.trim().isNotEmpty == true
            ? voucher.voucherNo!.trim()
            : '#${voucher.localId}',
        date: voucher.createdAt,
        amount: voucher.amount,
        partyLabel: 'المورد/الجهة',
        partyValue: supplierName,
        methodLabel: 'طريقة الدفع',
        methodValue: paymentMethod,
        accountName: accountName,
        note: voucher.note,
        status: voucher.status,
      ),
    );
  }

  static Future<void> printCashMovementReport({
    required DateTime? fromDate,
    required DateTime? toDate,
    required List<CashMovementEntry> entries,
    required CashMovementSummary summary,
  }) async {
    await Printing.layoutPdf(
      name: 'cash_movement_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      onLayout: (format) => _buildMovementReportPdf(
        pageFormat: format,
        fromDate: fromDate,
        toDate: toDate,
        entries: entries,
        summary: summary,
      ),
    );
  }

  static Future<Uint8List> _buildVoucherPdf({
    required PdfPageFormat pageFormat,
    required String title,
    required String voucherNo,
    required DateTime date,
    required double amount,
    required String partyLabel,
    required String partyValue,
    required String methodLabel,
    required String methodValue,
    required String accountName,
    required String? note,
    required String status,
  }) async {
    final fonts = await PdfArabicFonts.load();
    final regular = fonts.regular;
    final bold = fonts.bold;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final statusLabel = _statusLabel(status);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 0.7),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(font: bold, fontSize: 18),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _pdfInfoRow('رقم السند', voucherNo, regular, bold),
                  _pdfInfoRow(
                    'التاريخ',
                    DateFormat('yyyy-MM-dd hh:mm a').format(date),
                    regular,
                    bold,
                  ),
                  _pdfInfoRow('الحالة', statusLabel, regular, bold),
                  _pdfInfoRow(partyLabel, partyValue, regular, bold),
                  _pdfInfoRow(methodLabel, methodValue, regular, bold),
                  _pdfInfoRow('الحساب', accountName, regular, bold),
                  _pdfInfoRow('المبلغ', _money(amount), regular, bold),
                  if ((note ?? '').trim().isNotEmpty)
                    _pdfInfoRow('الملاحظة', note!.trim(), regular, bold),
                  pw.Spacer(),
                  pw.Divider(),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'تمت طباعة هذا السند من نظام Montex POS',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> _buildMovementReportPdf({
    required PdfPageFormat pageFormat,
    required DateTime? fromDate,
    required DateTime? toDate,
    required List<CashMovementEntry> entries,
    required CashMovementSummary summary,
  }) async {
    final fonts = await PdfArabicFonts.load();
    final regular = fonts.regular;
    final bold = fonts.bold;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final rows = entries.map((e) {
      final incoming = e.direction == CashMovementDirection.incoming
          ? _money(e.amount)
          : '-';
      final outgoing = e.direction == CashMovementDirection.outgoing
          ? _money(e.amount)
          : '-';
      return [
        DateFormat('yyyy-MM-dd HH:mm').format(e.createdAt),
        e.source,
        e.voucherNo,
        e.description,
        incoming,
        outgoing,
        e.isHidden ? 'مخفي' : _statusLabel(e.status),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(16),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    'تقرير الحركة النقدية',
                    style: pw.TextStyle(font: bold, fontSize: 17),
                  ),
                ),
                pw.SizedBox(height: 8),
                _pdfInfoRow(
                  'الفترة',
                  '${fromDate == null ? 'بداية البيانات' : DateFormat('yyyy-MM-dd').format(fromDate)} - '
                      '${toDate == null ? 'آخر البيانات' : DateFormat('yyyy-MM-dd').format(toDate)}',
                  regular,
                  bold,
                ),
                _pdfInfoRow('إجمالي الداخل', _money(summary.totalIncoming), regular, bold),
                _pdfInfoRow('إجمالي الخارج', _money(summary.totalOutgoing), regular, bold),
                _pdfInfoRow('الصافي', _money(summary.net), regular, bold),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: ['التاريخ', 'النوع', 'رقم السند', 'البيان', 'داخل', 'خارج', 'الحالة']
                          .reversed
                          .map(
                            (h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                h,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(font: bold, fontSize: 8.5),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...rows.map(
                      (r) => pw.TableRow(
                        children: r.reversed
                            .map(
                              (c) => pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  c,
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(font: regular, fontSize: 8),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfInfoRow(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: regular, fontSize: 11),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '$label:',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    final value = status.trim().toUpperCase();
    if (value == CashVoucherService.statusVoid) return 'مبطل';
    if (value.isEmpty) return 'نشط';
    return value;
  }

  static String _money(double value) {
    return '${NumberFormat('#,##0.00').format(value)} ريال';
  }
}
