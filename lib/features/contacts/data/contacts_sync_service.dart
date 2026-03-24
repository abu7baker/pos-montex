import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import 'contacts_api_service.dart';

final contactsSyncServiceProvider = Provider<ContactsSyncService>((ref) {
  return ContactsSyncService(
    ref.watch(appDbProvider),
    ref.watch(contactsApiServiceProvider),
  );
});

class ContactsSyncService {
  ContactsSyncService(this._db, this._api);

  final AppDb _db;
  final ContactsApiService _api;

  /// يجلب الـ contacts من السيرفر ويقوم بعمل upsert إلى جدول Customers محلياً.
  /// بدون تغيير schema: نخزن serverId داخل حقل code بشكل آمن: `SRV:<id>`.
  Future<int> syncContactsToCustomers() async {
    final items = await _api.fetchContacts();
    if (items.isEmpty) return 0;

    final existing = await (_db.select(_db.customers)).get();
    final byServerCode = <String, CustomerDb>{};
    final byMobile = <String, CustomerDb>{};

    for (final row in existing) {
      final code = (row.code ?? '').trim();
      if (code.isNotEmpty) byServerCode[code] = row;
      final mobile = row.mobile.trim();
      if (mobile.isNotEmpty) byMobile[_normalizePhone(mobile)] = row;
    }

    var changed = 0;

    await _db.transaction(() async {
      for (final raw in items) {
        final serverId = _readInt(raw['id']);
        if (serverId == null || serverId <= 0) continue;
        final serverCode = 'SRV:$serverId';

        final name =
            _readString(raw['name']) ??
            _readString(raw['first_name']) ??
            _readString(raw['business_name']) ??
            '';
        if (name.trim().isEmpty) continue;

        final mobile =
            _readString(raw['contact_no']) ??
            _readString(raw['mobile']) ??
            _readString(raw['phone']) ??
            '';
        final normalizedMobile = _normalizePhone(mobile);

        final email = _readString(raw['email']);
        final phoneAlt = _readString(raw['alt_number']) ?? _readString(raw['alternate_number']);

        final existingByCode = byServerCode[serverCode];
        final existingByMobile =
            normalizedMobile.isEmpty ? null : byMobile[normalizedMobile];
        final target = existingByCode ?? existingByMobile;

        if (target == null) {
          await _db.into(_db.customers).insert(
                CustomersCompanion.insert(
                  code: drift.Value(serverCode),
                  name: name.trim(),
                  mobile: normalizedMobile,
                  email: drift.Value(email),
                  phone: drift.Value(_nullIfEmpty(phoneAlt)),
                  updatedAtLocal: drift.Value(DateTime.now()),
                ),
              );
          changed++;
          continue;
        }

        final nextName = name.trim();
        final nextMobile = normalizedMobile;
        final nextEmail = _nullIfEmpty(email);
        final nextPhoneAlt = _nullIfEmpty(phoneAlt);

        final mustUpdate =
            (target.code ?? '').trim() != serverCode ||
            target.name.trim() != nextName ||
            _normalizePhone(target.mobile) != nextMobile ||
            (target.email ?? '').trim() != (nextEmail ?? '') ||
            (target.phone ?? '').trim() != (nextPhoneAlt ?? '');

        if (!mustUpdate) continue;

        await (_db.update(_db.customers)..where((t) => t.id.equals(target.id)))
            .write(
          CustomersCompanion(
            code: drift.Value(serverCode),
            name: drift.Value(nextName),
            mobile: drift.Value(nextMobile),
            email: drift.Value(nextEmail),
            phone: drift.Value(nextPhoneAlt),
            updatedAtLocal: drift.Value(DateTime.now()),
          ),
        );
        changed++;
      }
    });

    return changed;
  }
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().trim());
}

String? _readString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

String? _nullIfEmpty(String? value) {
  final v = (value ?? '').trim();
  return v.isEmpty ? null : v;
}

String _normalizePhone(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  return v.replaceAll(RegExp(r'[^0-9+]'), '');
}

