import 'dart:convert';

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.code,
    required this.label,
    this.accountId,
  });

  final String code;
  final String label;
  final int? accountId;

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'account_id': accountId,
  };

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    final rawCode = (json['code'] ?? json['name'] ?? '').toString().trim();
    final rawLabel = (json['label'] ?? json['name'] ?? '').toString().trim();
    final rawAccountId = json['account_id'];
    final parsedAccountId = rawAccountId is int
        ? rawAccountId
        : int.tryParse((rawAccountId ?? '').toString().trim());

    final normalizedCode = PaymentMethods.normalizeCode(rawCode);
    return PaymentMethodOption(
      code: normalizedCode,
      label: rawLabel.isNotEmpty
          ? rawLabel
          : PaymentMethods.defaultLabelForCode(normalizedCode),
      accountId: parsedAccountId,
    );
  }
}

class PaymentMethods {
  PaymentMethods._();

  static const String cash = 'CASH';
  static const String card = 'CARD';
  static const String cheque = 'CHEQUE';
  static const String bankTransfer = 'BANK_TRANSFER';
  static const String other = 'OTHER';
  static const String customPay1 = 'CUSTOM_PAY_1';
  static const String customPay2 = 'CUSTOM_PAY_2';
  static const String customPay3 = 'CUSTOM_PAY_3';
  static const String customPay4 = 'CUSTOM_PAY_4';
  static const String customPay5 = 'CUSTOM_PAY_5';
  static const String customPay6 = 'CUSTOM_PAY_6';
  static const String customPay7 = 'CUSTOM_PAY_7';
  static const String credit = 'CREDIT';

  static const List<PaymentMethodOption> _options = [
    PaymentMethodOption(code: cash, label: 'كاش'),
    PaymentMethodOption(code: card, label: 'بطاقة'),
    PaymentMethodOption(code: cheque, label: 'شيك مصرفي'),
    PaymentMethodOption(code: bankTransfer, label: 'تحويل مصرفي'),
    PaymentMethodOption(code: other, label: 'آخر'),
    PaymentMethodOption(code: customPay1, label: 'نينجا'),
    PaymentMethodOption(code: customPay2, label: 'هنقرستيشن'),
    PaymentMethodOption(code: customPay3, label: 'كيتا'),
    PaymentMethodOption(code: customPay4, label: 'جاهز'),
    PaymentMethodOption(code: customPay5, label: 'تويو'),
    PaymentMethodOption(code: customPay6, label: 'توصيل'),
    PaymentMethodOption(code: customPay7, label: 'متجر'),
  ];

  static const String defaultCode = cash;

  static List<PaymentMethodOption> get options => List.unmodifiable(_options);

  static String normalizeCode(String code) {
    final normalized = code.trim().replaceAll('-', '_').toUpperCase();
    switch (normalized) {
      case 'CASH':
        return cash;
      case 'CARD':
        return card;
      case 'CHEQUE':
      case 'CHECK':
      case 'BANK_CHECK':
        return cheque;
      case 'BANK_TRANSFER':
      case 'TRANSFER':
        return bankTransfer;
      case 'OTHER':
        return other;
      case 'CUSTOM_PAY_1':
      case 'NINJA':
        return customPay1;
      case 'CUSTOM_PAY_2':
      case 'HUNGERSTATION':
        return customPay2;
      case 'CUSTOM_PAY_3':
      case 'KEETA':
        return customPay3;
      case 'CUSTOM_PAY_4':
      case 'JAHIZ':
        return customPay4;
      case 'CUSTOM_PAY_5':
      case 'TOPPO':
      case 'TOYO':
        return customPay5;
      case 'CUSTOM_PAY_6':
      case 'DELIVERY':
        return customPay6;
      case 'CUSTOM_PAY_7':
      case 'STORE':
        return customPay7;
      case 'CREDIT':
      case 'DEFERRED':
        return credit;
      default:
        return normalized;
    }
  }

  static String defaultLabelForCode(String code) {
    switch (normalizeCode(code)) {
      case cash:
        return 'كاش';
      case card:
        return 'بطاقة';
      case cheque:
        return 'شيك مصرفي';
      case bankTransfer:
        return 'تحويل مصرفي';
      case other:
        return 'آخر';
      case customPay1:
        return 'نينجا';
      case customPay2:
        return 'هنقرستيشن';
      case customPay3:
        return 'كيتا';
      case customPay4:
        return 'جاهز';
      case customPay5:
        return 'تويو';
      case customPay6:
        return 'توصيل';
      case customPay7:
        return 'متجر';
      case credit:
        return 'آجل';
      default:
        return code.trim().isEmpty ? '-' : code;
    }
  }

  static String labelForCode(String code) => defaultLabelForCode(code);
}

Map<String, List<PaymentMethodOption>> decodeBranchPaymentMethodsMap(
  String? raw,
) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};

    final output = <String, List<PaymentMethodOption>>{};
    decoded.forEach((key, value) {
      if (value is! List) return;
      final methods = value
          .whereType<Map>()
          .map(
            (item) => PaymentMethodOption.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.code.trim().isNotEmpty)
          .toList(growable: false);
      if (methods.isNotEmpty) {
        output[key.toString()] = methods;
      }
    });
    return output;
  } catch (_) {
    return const {};
  }
}

String encodeBranchPaymentMethodsMap(
  Map<String, List<PaymentMethodOption>> items,
) {
  return jsonEncode({
    for (final entry in items.entries)
      entry.key: entry.value.map((item) => item.toJson()).toList(),
  });
}
