import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/ui/app_feedback.dart';
import 'cart_provider.dart';
import 'pos_models.dart';

final posControllerProvider = StateNotifierProvider<PosController, PosState>((
  ref,
) {
  return PosController(ref);
});

class PosController extends StateNotifier<PosState> {
  PosController(this._ref) : super(PosState.fromCart(_ref.read(cartProvider))) {
    _ref.listen<CartState>(cartProvider, (previous, next) {
      _syncWithCart(next);
    });
  }

  final Ref _ref;

  void _syncWithCart(CartState cart) {
    if (cart.items.isEmpty) {
      state = PosState.fromCart(cart).copyWith(
        selectedCustomerId: state.selectedCustomerId,
        selectedCustomerName: state.selectedCustomerName,
        selectedServiceId: state.selectedServiceId,
        selectedServiceName: state.selectedServiceName,
        selectedServiceCost: state.selectedServiceCost,
        selectedTableId: state.selectedTableId,
        selectedTableName: state.selectedTableName,
      );
      return;
    }
    final base = state.copyWith(items: cart.items, total: cart.total);
    state = _recalculate(base);
  }

  Future<bool?> onTapMultiPayment(BuildContext context) {
    if (state.items.isEmpty) {
      AppFeedback.warning(context, 'توجد منتجات ناقصة، أضف بعض المنتجات أولا');
      return Future.value(false);
    }

    return AppDialogs.showMultiPayment<bool>(
      context,
      state: state,
      callbacks: MultiPaymentCallbacks(
        onAddLine: addPaymentLine,
        onRemoveLine: removePaymentLine,
        onFinish: finishSale,
      ),
    );
  }

  Future<DiscountInput?> onTapDiscount(BuildContext context) {
    if (state.items.isEmpty) {
      AppFeedback.warning(context, 'أضف منتجات أولاً قبل تطبيق الخصم');
      return Future.value(null);
    }

    return AppDialogs.showDiscount<DiscountInput>(
      context,
      initial: DiscountInput(
        type: state.discountType,
        value: state.discountValue,
      ),
    ).then((value) {
      if (value != null) {
        setDiscount(value.type, value.value);
      }
      return value;
    });
  }

  Future<DeliveryInput?> onTapDelivery(BuildContext context) {
    if (state.items.isEmpty) {
      AppFeedback.warning(context, 'أضف منتجات أولاً قبل إضافة التوصيل');
      return Future.value(null);
    }

    return AppDialogs.showDelivery<DeliveryInput>(
      context,
      initial: DeliveryInput(
        status: state.deliveryStatus,
        fee: state.deliveryFee,
        address: state.deliveryAddress,
        details: state.deliveryDetails,
        assignee: state.deliveryAssignee,
      ),
    ).then((value) {
      if (value != null) {
        setDelivery(value);
      }
      return value;
    });
  }

  void addPaymentLine(PaymentLine line) {
    final updated = [...state.payments, line];
    state = _recalculate(state.copyWith(payments: updated));
  }

  void removePaymentLine(int index) {
    if (index < 0 || index >= state.payments.length) return;
    final updated = [...state.payments]..removeAt(index);
    state = _recalculate(state.copyWith(payments: updated));
  }

  void finishSale(BuildContext context) {
    Navigator.of(context).maybePop(true);
  }

  void clearPayments() {
    state = _recalculate(state.copyWith(payments: const []));
  }

  void setDiscount(DiscountType type, double value) {
    state = _recalculate(
      state.copyWith(discountType: type, discountValue: value),
    );
  }

  void setDelivery(DeliveryInput input) {
    state = _recalculate(
      state.copyWith(
        deliveryStatus: input.status,
        deliveryFee: input.fee,
        deliveryAddress: input.address,
        deliveryDetails: input.details,
        deliveryAssignee: input.assignee,
      ),
    );
  }

  void setSelectedCustomer({
    required int? customerId,
    required String customerName,
  }) {
    state = _recalculate(
      state.copyWith(
        resetSelectedCustomer: customerId == null,
        selectedCustomerId: customerId,
        selectedCustomerName: customerName.trim().isEmpty
            ? 'عميل عام'
            : customerName.trim(),
      ),
    );
  }

  void setSelectedService({
    required int? serviceId,
    required String serviceName,
    required double serviceCost,
  }) {
    state = _recalculate(
      state.copyWith(
        resetSelectedService: serviceId == null,
        selectedServiceId: serviceId,
        selectedServiceName: serviceName.trim(),
        selectedServiceCost: serviceCost < 0 ? 0 : serviceCost,
      ),
    );
  }

  void setSelectedTable({required int? tableId, required String tableName}) {
    final normalized = tableName.trim();
    state = _recalculate(
      state.copyWith(
        resetSelectedTable: tableId == null,
        selectedTableId: tableId,
        selectedTableName: tableId == null ? '' : normalized,
      ),
    );
  }

  PosState _recalculate(PosState base) {
    final paid = base.payments.fold(0.0, (sum, line) => sum + line.amount);
    final remaining = base.totalAfterDiscountWithDelivery - paid;
    return base.copyWith(
      paid: _round2(paid),
      remaining: _round2(remaining < 0 ? 0 : remaining),
    );
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
