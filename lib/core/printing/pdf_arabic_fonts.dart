import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads embedded Arabic PDF fonts from app assets and caches them.
class PdfArabicFonts {
  PdfArabicFonts._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _symbol;

  // Use the new Saudi Riyal sign (U+20C1) after amount.
  static const String _defaultRiyalSign = '\u20C1';
  static String _riyalSign = _defaultRiyalSign;

  static Future<
    ({pw.Font regular, pw.Font bold, pw.Font symbol, String riyalSign})
  >
  load() async {
    if (_regular != null && _bold != null && _symbol != null) {
      return (
        regular: _regular!,
        bold: _bold!,
        symbol: _symbol!,
        riyalSign: _riyalSign,
      );
    }

    try {
      // User preference: invoices should use Amiri.
      final regularData = await _loadAsset('assets/fonts/Amiri-Regular.ttf');
      final boldData = await _loadAsset('assets/fonts/Amiri-Bold.ttf');
      _regular = pw.Font.ttf(regularData);
      _bold = pw.Font.ttf(boldData);
    } catch (_) {
      try {
        final regularData = await _loadAsset('assets/fonts/Tajawal-Regular.ttf');
        final boldData = await _loadAsset('assets/fonts/Tajawal-Bold.ttf');
        _regular = pw.Font.ttf(regularData);
        _bold = pw.Font.ttf(boldData);
      } catch (_) {
        _regular = pw.Font.helvetica();
        _bold = pw.Font.helveticaBold();
      }
    }

    // Dedicated symbol font supports the new Saudi Riyal sign (U+20C1) when needed.
    if (_symbol == null) {
      try {
        final symbolData = await _loadAsset(
          'assets/fonts/SaudiRiyal-Regular.ttf',
        );
        _symbol = pw.Font.ttf(symbolData);
      } catch (_) {
        _symbol = _regular;
      }
    }
    _riyalSign = _defaultRiyalSign;

    final regular = _regular ?? pw.Font.helvetica();
    final bold = _bold ?? pw.Font.helveticaBold();
    final symbol = _symbol ?? regular;

    _regular = regular;
    _bold = bold;
    _symbol = symbol;

    return (
      regular: regular,
      bold: bold,
      symbol: symbol,
      riyalSign: _riyalSign,
    );
  }

  static Future<ByteData> _loadAsset(String path) => rootBundle.load(path);
}
