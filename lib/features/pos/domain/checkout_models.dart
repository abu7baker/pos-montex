import 'package:equatable/equatable.dart';

class PaymentInput extends Equatable {
  const PaymentInput({
    required this.methodCode,
    required this.amount,
    this.reference,
    this.note,
  });

  final String methodCode;
  final double amount;
  final String? reference;
  final String? note;

  @override
  List<Object?> get props => [methodCode, amount, reference, note];
}

class DeliveryPrintInput extends Equatable {
  const DeliveryPrintInput({
    required this.enabled,
    required this.fee,
    required this.details,
    required this.address,
    required this.assignee,
  });

  final bool enabled;
  final double fee;
  final String details;
  final String address;
  final String assignee;

  bool get hasPrintableDetails =>
      enabled ||
      fee > 0 ||
      details.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      assignee.trim().isNotEmpty;

  @override
  List<Object?> get props => [enabled, fee, details, address, assignee];
}

class ServiceInput extends Equatable {
  const ServiceInput({
    required this.id,
    required this.name,
    required this.cost,
  });

  final int? id;
  final String name;
  final double cost;

  bool get hasValue => id != null && cost > 0;

  @override
  List<Object?> get props => [id, name, cost];
}

class TableInput extends Equatable {
  const TableInput({required this.id, required this.name});

  final int? id;
  final String name;

  bool get hasValue => id != null && name.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, name];
}

class CheckoutResult extends Equatable {
  const CheckoutResult({
    required this.saleLocalId,
    required this.total,
    required this.paidTotal,
    required this.remaining,
    required this.change,
    required this.status,
  });

  final int saleLocalId;
  final double total;
  final double paidTotal;
  final double remaining;
  final double change;
  final String status;

  @override
  List<Object?> get props => [
    saleLocalId,
    total,
    paidTotal,
    remaining,
    change,
    status,
  ];
}
