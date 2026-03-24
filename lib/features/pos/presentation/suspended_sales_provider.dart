import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_provider.dart';
import 'pos_models.dart';

class SuspendedSale {
  const SuspendedSale({
    required this.id,
    required this.items,
    required this.note,
    required this.createdAt,
    required this.discountType,
    required this.discountValue,
  });

  final String id;
  final List<CartItem> items;
  final String note;
  final DateTime createdAt;
  final DiscountType discountType;
  final double discountValue;

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.qty);

  double get total => items.fold<double>(0.0, (sum, item) => sum + item.total);

  double get discountAmount {
    if (discountValue <= 0) return 0;
    final raw = discountType == DiscountType.percent ? total * (discountValue / 100) : discountValue;
    final capped = raw > total ? total : raw;
    return capped < 0 ? 0 : capped;
  }

  double get totalAfterDiscount {
    final value = total - discountAmount;
    return value < 0 ? 0 : value;
  }
}

class SuspendedSalesNotifier extends StateNotifier<List<SuspendedSale>> {
  SuspendedSalesNotifier() : super(const []);

  void addSale(SuspendedSale sale) {
    state = [...state, sale];
  }

  void removeSale(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

final suspendedSalesProvider = StateNotifierProvider<SuspendedSalesNotifier, List<SuspendedSale>>((ref) {
  return SuspendedSalesNotifier();
});
