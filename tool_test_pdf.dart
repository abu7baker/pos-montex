import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final regular = pw.Font.ttf(File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync().buffer.asByteData());
  final bold = pw.Font.ttf(File('assets/fonts/Amiri-Bold.ttf').readAsBytesSync().buffer.asByteData());
  final symbol = pw.Font.ttf(File('assets/fonts/SaudiRiyal-Regular.ttf').readAsBytesSync().buffer.asByteData());

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (_) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(children: [
          pw.Text('اختبار'),
          pw.Text('30.00 \u20C1', style: pw.TextStyle(font: regular, fontFallback: [symbol])),
          pw.Text('30.00 ﷼', style: pw.TextStyle(font: regular, fontFallback: [symbol])),
        ]),
      ),
    ),
  );

  final out = File('tmp_test_receipt.pdf');
  await out.writeAsBytes(await doc.save());
  print('ok ${out.path} ${await out.length()}');
}
