import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/db_provider.dart';
import 'printer_repository.dart';

final printerRepositoryProvider = Provider<PrinterRepository>((ref) {
  final db = ref.read(appDbProvider);
  return PrinterRepository(db);
});