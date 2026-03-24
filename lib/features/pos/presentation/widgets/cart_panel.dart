import 'package:flutter/material.dart';
import '../../../../app/theme/app_spacing.dart';
import '../cart_provider.dart';
import 'cart_table.dart';
import 'pos_filters_panel.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.cart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onUpdatePrice,
    required this.onEditAddons,
    required this.hasAddonsForProduct,
    this.compact = false,
    this.showServices = true,
    this.showTables = true,
    this.onCustomerChanged,
    this.onServiceChanged,
    this.onTableChanged,
  });

  final CartState cart;
  final void Function(int lineId) onIncrement;
  final void Function(int lineId) onDecrement;
  final void Function(int lineId) onRemove;
  final void Function(int lineId, double unitPrice) onUpdatePrice;
  final Future<void> Function(CartItem item) onEditAddons;
  final bool Function(int productId) hasAddonsForProduct;
  final bool compact;
  final bool showServices;
  final bool showTables;
  final void Function(int? customerId, String customerName)? onCustomerChanged;
  final void Function(int? serviceId, String serviceName, double serviceCost)?
  onServiceChanged;
  final void Function(int? tableId, String tableName)? onTableChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PosFiltersPanel(
          compact: compact,
          showServices: showServices,
          showTables: showTables,
          onCustomerChanged: onCustomerChanged,
          onServiceChanged: onServiceChanged,
          onTableChanged: onTableChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: CartTable(
            cart: cart,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            onRemove: onRemove,
            onUpdatePrice: onUpdatePrice,
            onEditAddons: onEditAddons,
            hasAddonsForProduct: hasAddonsForProduct,
          ),
        ),
      ],
    );
  }
}
