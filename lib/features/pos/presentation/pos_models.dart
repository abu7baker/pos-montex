import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_icons.dart';
import 'cart_provider.dart';

enum PaymentMethod { cash, card, deferred, transfer }

enum DiscountType { percent, fixed }

extension DiscountTypeX on DiscountType {
  String get label {
    switch (this) {
      case DiscountType.percent:
        return 'النسبة المئوية';
      case DiscountType.fixed:
        return 'ثابت';
    }
  }
}

enum DeliveryStatus { pending, ordered, returned, shipped, delivered, canceled }

extension DeliveryStatusX on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'يرجى الاختيار';
      case DeliveryStatus.ordered:
        return 'تم الطلب';
      case DeliveryStatus.returned:
        return 'معاده';
      case DeliveryStatus.shipped:
        return 'شحنت';
      case DeliveryStatus.delivered:
        return 'تم التوصيل';
      case DeliveryStatus.canceled:
        return 'ألغيت';
    }
  }
}

class DiscountInput extends Equatable {
  const DiscountInput({required this.type, required this.value});

  final DiscountType type;
  final double value;

  @override
  List<Object?> get props => [type, value];
}

class DeliveryInput extends Equatable {
  const DeliveryInput({
    required this.status,
    required this.fee,
    required this.address,
    required this.details,
    required this.assignee,
  });

  final DeliveryStatus status;
  final double fee;
  final String address;
  final String details;
  final String assignee;

  @override
  List<Object?> get props => [status, fee, address, details, assignee];
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'كاش';
      case PaymentMethod.card:
        return 'بطاقة';
      case PaymentMethod.deferred:
        return 'آجل';
      case PaymentMethod.transfer:
        return 'تحويل';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return AppIcons.cash;
      case PaymentMethod.card:
        return AppIcons.card;
      case PaymentMethod.deferred:
        return AppIcons.deferred;
      case PaymentMethod.transfer:
        return AppIcons.transfer;
    }
  }

  String get code {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.deferred:
        return 'CREDIT';
      case PaymentMethod.transfer:
        return 'TRANSFER';
    }
  }
}

class PaymentLine extends Equatable {
  const PaymentLine({
    required this.amount,
    required this.methodCode,
    this.account,
    this.note,
    this.cardNumber,
    this.cardHolderName,
    this.cardTransactionId,
  });

  final double amount;
  /// كود طريقة الدفع من القائمة الموحدة (مثل CASH, CARD، ...).
  final String methodCode;
  final String? account;
  final String? note;
  final String? cardNumber;
  final String? cardHolderName;
  final String? cardTransactionId;

  @override
  List<Object?> get props => [
    amount,
    methodCode,
    account,
    note,
    cardNumber,
    cardHolderName,
    cardTransactionId,
  ];
}

class PosState extends Equatable {
  static const double fixedTaxRate = 0.15;

  const PosState({
    required this.items,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.payments,
    required this.discountType,
    required this.discountValue,
    required this.deliveryStatus,
    required this.deliveryFee,
    required this.deliveryAddress,
    required this.deliveryDetails,
    required this.deliveryAssignee,
    required this.selectedCustomerId,
    required this.selectedCustomerName,
    required this.selectedServiceId,
    required this.selectedServiceName,
    required this.selectedServiceCost,
    required this.selectedTableId,
    required this.selectedTableName,
  });

  final List<CartItem> items;
  final double total;
  final double paid;
  final double remaining;
  final List<PaymentLine> payments;
  final DiscountType discountType;
  final double discountValue;
  final DeliveryStatus deliveryStatus;
  final double deliveryFee;
  final String deliveryAddress;
  final String deliveryDetails;
  final String deliveryAssignee;
  final int? selectedCustomerId;
  final String selectedCustomerName;
  final int? selectedServiceId;
  final String selectedServiceName;
  final double selectedServiceCost;
  final int? selectedTableId;
  final String selectedTableName;

  factory PosState.fromCart(CartState cart) {
    return PosState(
      items: cart.items,
      total: cart.total,
      paid: 0,
      remaining: cart.total,
      payments: const [],
      discountType: DiscountType.percent,
      discountValue: 0,
      deliveryStatus: DeliveryStatus.pending,
      deliveryFee: 0,
      deliveryAddress: '',
      deliveryDetails: '',
      deliveryAssignee: '',
      selectedCustomerId: null,
      selectedCustomerName: 'عميل عام',
      selectedServiceId: null,
      selectedServiceName: '',
      selectedServiceCost: 0,
      selectedTableId: null,
      selectedTableName: '',
    );
  }

  double get discountAmount {
    if (discountValue <= 0) return 0;
    final raw = discountType == DiscountType.percent
        ? total * (discountValue / 100)
        : discountValue;
    if (raw.isNaN || raw.isInfinite) return 0;
    final capped = raw > total ? total : raw;
    return capped < 0 ? 0 : capped;
  }

  double get totalAfterDiscount {
    final value = total - discountAmount;
    return value < 0 ? 0 : value;
  }

  double get totalAfterDiscountWithDelivery {
    final value =
        totalAfterDiscount + deliveryFee + selectedServiceCost + taxAmount;
    return value < 0 ? 0 : value;
  }

  double get taxAmount {
    final taxableBase = totalAfterDiscount + deliveryFee + selectedServiceCost;
    if (taxableBase <= 0) return 0;
    return taxableBase * fixedTaxRate;
  }

  PosState copyWith({
    List<CartItem>? items,
    double? total,
    double? paid,
    double? remaining,
    List<PaymentLine>? payments,
    DiscountType? discountType,
    double? discountValue,
    DeliveryStatus? deliveryStatus,
    double? deliveryFee,
    String? deliveryAddress,
    String? deliveryDetails,
    String? deliveryAssignee,
    bool resetSelectedCustomer = false,
    int? selectedCustomerId,
    String? selectedCustomerName,
    bool resetSelectedService = false,
    int? selectedServiceId,
    String? selectedServiceName,
    double? selectedServiceCost,
    bool resetSelectedTable = false,
    int? selectedTableId,
    String? selectedTableName,
  }) {
    return PosState(
      items: items ?? this.items,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      remaining: remaining ?? this.remaining,
      payments: payments ?? this.payments,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryDetails: deliveryDetails ?? this.deliveryDetails,
      deliveryAssignee: deliveryAssignee ?? this.deliveryAssignee,
      selectedCustomerId: resetSelectedCustomer
          ? null
          : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: selectedCustomerName ?? this.selectedCustomerName,
      selectedServiceId: resetSelectedService
          ? null
          : (selectedServiceId ?? this.selectedServiceId),
      selectedServiceName: resetSelectedService
          ? ''
          : (selectedServiceName ?? this.selectedServiceName),
      selectedServiceCost: resetSelectedService
          ? 0
          : (selectedServiceCost ?? this.selectedServiceCost),
      selectedTableId: resetSelectedTable
          ? null
          : (selectedTableId ?? this.selectedTableId),
      selectedTableName: resetSelectedTable
          ? ''
          : (selectedTableName ?? this.selectedTableName),
    );
  }

  @override
  List<Object?> get props => [
    items,
    total,
    paid,
    remaining,
    payments,
    discountType,
    discountValue,
    deliveryStatus,
    deliveryFee,
    deliveryAddress,
    deliveryDetails,
    deliveryAssignee,
    selectedCustomerId,
    selectedCustomerName,
    selectedServiceId,
    selectedServiceName,
    selectedServiceCost,
    selectedTableId,
    selectedTableName,
  ];
}

class MultiPaymentCallbacks {
  const MultiPaymentCallbacks({
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onFinish,
  });

  final void Function(PaymentLine line) onAddLine;
  final void Function(int index) onRemoveLine;
  final void Function(BuildContext context) onFinish;
}
