import 'dart:io';

import 'package:drift/drift.dart';
import '../../../../core/database/app_db.dart';

class PrinterRepository {
  const PrinterRepository(this._db);

  final AppDb _db;

  Future<List<String>> listInstalledPrinters() async {
    if (!Platform.isWindows) return const <String>[];
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', 'Get-Printer | Select-Object -ExpandProperty Name'],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      return const <String>[];
    }
    final stdoutText = result.stdout?.toString() ?? '';
    final printers = stdoutText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return printers;
  }

  Future<int> savePrinter({
    int? id,
    required String name,
    required String type,
    required String connectionType,
    String? stationCode,
    String? ip,
    int? port,
    String? windowsPrinterName,
    String? btMac,
    int? paperSize,
    int? copies,
    int? workstationId,
    int? branchServerId,
  }) async {
    final companion = PrintersCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name),
      type: Value(type),
      stationCode: Value(stationCode ?? ''),
      connectionType: Value(connectionType),
      ip: Value(ip),
      port: port == null ? const Value.absent() : Value(port),
      windowsPrinterName: Value(windowsPrinterName),
      btMac: Value(btMac),
      paperSize: paperSize == null ? const Value.absent() : Value(paperSize),
      copies: copies == null ? const Value.absent() : Value(copies),
      workstationId: Value(workstationId),
      branchServerId: Value(branchServerId),
    );

    return _db.into(_db.printers).insertOnConflictUpdate(companion);
  }

  Future<void> mapPrinterToStation({
    required int workstationId,
    required String stationCode,
    required int printerId,
  }) {
    return _db.setPrinterForStation(
      workstationId: workstationId,
      stationCode: stationCode,
      printerId: printerId,
    );
  }
}
