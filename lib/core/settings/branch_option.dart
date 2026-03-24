import 'dart:convert';

class BranchOption {
  const BranchOption({
    required this.selectionKey,
    required this.name,
    this.serverId,
    this.code = '',
    this.address = '',
    this.phone = '',
  });

  final String selectionKey;
  final int? serverId;
  final String name;
  final String code;
  final String address;
  final String phone;

  String get displayLabel => code.isNotEmpty ? '($code) $name' : name;

  Map<String, dynamic> toJson() => {
    'selection_key': selectionKey,
    'server_id': serverId,
    'name': name,
    'code': code,
    'address': address,
    'phone': phone,
  };

  factory BranchOption.fromJson(Map<String, dynamic> json) {
    final rawKey = (json['selection_key'] ?? '').toString().trim();
    final rawCode = (json['code'] ?? '').toString().trim();
    final rawName = (json['name'] ?? '').toString().trim();
    final rawServerId = json['server_id'];
    final parsedServerId = rawServerId is int
        ? rawServerId
        : int.tryParse((rawServerId ?? '').toString().trim());
    return BranchOption(
      selectionKey: rawKey.isNotEmpty
          ? rawKey
          : BranchOption.makeSelectionKey(
              serverId: parsedServerId,
              code: rawCode,
              name: rawName,
            ),
      serverId: parsedServerId,
      name: rawName,
      code: rawCode,
      address: (json['address'] ?? '').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
    );
  }

  static String makeSelectionKey({
    required int? serverId,
    required String code,
    required String name,
  }) {
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    if (serverId != null && serverId > 0) {
      return 'id:$serverId';
    }
    if (normalizedCode.isNotEmpty) {
      return 'code:$normalizedCode';
    }
    return 'name:$normalizedName';
  }

  static List<BranchOption> listFromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => BranchOption.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => item.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(Iterable<BranchOption> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }
}
