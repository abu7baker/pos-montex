import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/domain/product_entity.dart';

class CartAddonSelection extends Equatable {
  const CartAddonSelection({
    required this.groupId,
    required this.groupName,
    required this.itemId,
    required this.itemName,
    required this.price,
  });

  final int groupId;
  final String groupName;
  final int itemId;
  final String itemName;
  final double price;

  String get displayLabel =>
      price > 0 ? '$itemName (${price.toStringAsFixed(2)} ريال)' : itemName;

  String get invoiceLabel => price > 0
      ? '+ $itemName (${price.toStringAsFixed(2)} ريال)'
      : '+ $itemName';

  @override
  List<Object?> get props => [groupId, groupName, itemId, itemName, price];
}

class CartItem extends Equatable {
  CartItem({
    required this.lineId,
    required this.product,
    required this.qty,
    double? unitPrice,
    List<CartAddonSelection> selectedAddons = const <CartAddonSelection>[],
  }) : selectedAddons = List.unmodifiable(selectedAddons),
       unitPrice = unitPrice ?? _calculateUnitPrice(product, selectedAddons);

  final int lineId;
  final Product product;
  final int qty;
  final double unitPrice;
  final List<CartAddonSelection> selectedAddons;

  double get addonsTotal =>
      selectedAddons.fold(0.0, (sum, addon) => sum + addon.price);

  bool get hasAddons => selectedAddons.isNotEmpty;

  String get addonsSummary =>
      selectedAddons.map((addon) => addon.invoiceLabel).join('\n');

  double get total => qty * unitPrice;

  static double _calculateUnitPrice(
    Product product,
    List<CartAddonSelection> selectedAddons,
  ) {
    final addonsPrice = selectedAddons.fold<double>(
      0,
      (sum, addon) => sum + addon.price,
    );
    return ((product.price + addonsPrice) * 100).roundToDouble() / 100;
  }

  CartItem copyWith({
    int? lineId,
    Product? product,
    int? qty,
    double? unitPrice,
    List<CartAddonSelection>? selectedAddons,
  }) {
    return CartItem(
      lineId: lineId ?? this.lineId,
      product: product ?? this.product,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      selectedAddons: selectedAddons ?? this.selectedAddons,
    );
  }

  @override
  List<Object?> get props => [lineId, product, qty, unitPrice, selectedAddons];
}

class CartState extends Equatable {
  const CartState({required this.items});

  final List<CartItem> items;

  double get total => items.fold(0, (sum, item) => sum + item.total);

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState(items: []));

  int _nextLineId = 1;

  void add(Product product) {
    final index = state.items.indexWhere(
      (e) =>
          e.product.id == product.id &&
          e.selectedAddons.isEmpty &&
          (e.unitPrice - product.price).abs() < 0.001,
    );
    if (index == -1) {
      state = CartState(
        items: [
          ...state.items,
          CartItem(lineId: _nextLineId++, product: product, qty: 1),
        ],
      );
      return;
    }
    final updated = [...state.items];
    final current = updated[index];
    updated[index] = current.copyWith(qty: current.qty + 1);
    state = CartState(items: updated);
  }

  void increment(int lineId) {
    final index = state.items.indexWhere((e) => e.lineId == lineId);
    if (index == -1) return;
    final updated = [...state.items];
    final current = updated[index];
    updated[index] = current.copyWith(qty: current.qty + 1);
    state = CartState(items: updated);
  }

  void decrement(int lineId) {
    final index = state.items.indexWhere((e) => e.lineId == lineId);
    if (index == -1) return;
    final updated = [...state.items];
    final current = updated[index];
    final nextQty = current.qty - 1;
    if (nextQty <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = current.copyWith(qty: nextQty);
    }
    state = CartState(items: updated);
  }

  void remove(int lineId) {
    state = CartState(
      items: state.items.where((e) => e.lineId != lineId).toList(),
    );
  }

  void updateUnitPrice(int lineId, double unitPrice) {
    final index = state.items.indexWhere((e) => e.lineId == lineId);
    if (index == -1) return;
    final updated = [...state.items];
    final current = updated[index];
    final normalized = unitPrice < 0 ? 0.0 : unitPrice;
    updated[index] = current.copyWith(unitPrice: normalized);
    state = CartState(items: updated);
  }

  void updateAddons(int lineId, List<CartAddonSelection> selectedAddons) {
    final index = state.items.indexWhere((e) => e.lineId == lineId);
    if (index == -1) return;
    final updated = [...state.items];
    final current = updated[index];
    final normalized = List<CartAddonSelection>.from(selectedAddons)
      ..sort((a, b) {
        final groupCompare = a.groupId.compareTo(b.groupId);
        if (groupCompare != 0) return groupCompare;
        return a.itemId.compareTo(b.itemId);
      });
    final unitPrice = CartItem._calculateUnitPrice(current.product, normalized);
    updated[index] = current.copyWith(
      selectedAddons: normalized,
      unitPrice: unitPrice,
    );
    state = CartState(items: updated);
  }

  void clear() {
    state = const CartState(items: []);
  }

  void setItems(List<CartItem> items) {
    state = CartState(items: items);
    final maxLineId = items.fold<int>(
      0,
      (maxValue, item) => item.lineId > maxValue ? item.lineId : maxValue,
    );
    _nextLineId = maxLineId + 1;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
