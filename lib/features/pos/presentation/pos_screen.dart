import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../../core/settings/pos_feature_settings.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/ui/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
import '../../products/presentation/products_provider.dart';
import '../data/checkout_service.dart';
import '../domain/checkout_models.dart';
import '../printing/print_job_runner.dart';
import 'cart_provider.dart';
import 'pos_controller.dart';
import 'pos_models.dart';
import 'suspended_sales_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/invoice_summary_bar.dart';
import 'widgets/pos_bottom_actions.dart';
import 'widgets/product_addons_dialog.dart';
import 'widgets/pos_topbar.dart';
import 'widgets/products_grid.dart';
import 'widgets/receipt_preview_modal.dart';
import 'widgets/recent_sales_dialog.dart';
import '../../../app/router/app_routes.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  Future<void> _handleCheckout({
    required CartState cart,
    required Future<CheckoutResult> Function() action,
  }) async {
    if (cart.items.isEmpty) return;
    try {
      final result = await action();
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      final changeText = result.change > 0
          ? ' - الباقي: ${result.change.toStringAsFixed(2)}'
          : '';
      AppFeedback.success(
        context,
        'تم حفظ البيع #${result.saleLocalId}$changeText',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  void _openReceiptPreview() {
    ReceiptPreviewModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final disableDesktopTooltips = !kIsWeb && Platform.isWindows;
    final productsAsync = ref.watch(productsStreamProvider);
    final categoriesAsync = ref.watch(productCategoriesStreamProvider);
    final featureSettings =
        ref.watch(posFeatureSettingsProvider).valueOrNull ??
        PosFeatureSettings.defaults();
    final db = ref.watch(appDbProvider);
    final categories =
        categoriesAsync.valueOrNull ?? const <ProductCategoryDb>[];
    final cart = ref.watch(cartProvider);
    final posState = ref.watch(posControllerProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final posController = ref.read(posControllerProvider.notifier);
    final checkout = ref.read(checkoutServiceProvider);
    final suspendedNotifier = ref.read(suspendedSalesProvider.notifier);
    final printRunner = ref.read(printJobRunnerProvider);
    final deliveryInput = DeliveryPrintInput(
      enabled:
          posState.deliveryFee > 0 ||
          posState.deliveryAddress.trim().isNotEmpty ||
          posState.deliveryDetails.trim().isNotEmpty ||
          posState.deliveryAssignee.trim().isNotEmpty ||
          posState.deliveryStatus != DeliveryStatus.pending,
      fee: posState.deliveryFee,
      details: posState.deliveryDetails,
      address: posState.deliveryAddress,
      assignee: posState.deliveryAssignee,
    );
    final serviceInput = ServiceInput(
      id: posState.selectedServiceId,
      name: posState.selectedServiceName,
      cost: posState.selectedServiceCost,
    );
    final tableInput = TableInput(
      id: posState.selectedTableId,
      name: posState.selectedTableName,
    );
    void warnEmptyCart() =>
        AppFeedback.warning(context, 'يجب اضافة منتجات اولا');

    List<ProductAddonGroupView> groupsForProduct(
      int productId, {
      required Map<int, AddonGroupDb> activeGroupsById,
      required Map<int, List<AddonItemDb>> itemsByGroupId,
      required Map<int, Set<int>> groupIdsByProductId,
    }) {
      final groupIds = groupIdsByProductId[productId] ?? const <int>{};
      return [
          for (final groupId in groupIds)
            if (activeGroupsById[groupId] case final group?)
              ProductAddonGroupView(
                group: group,
                items: itemsByGroupId[groupId] ?? const <AddonItemDb>[],
              ),
        ].where((view) => view.items.isNotEmpty).toList()
        ..sort((a, b) => a.group.name.compareTo(b.group.name));
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: TooltipVisibility(
        visible: !disableDesktopTooltips,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
              final layout = _PosLayoutConfig.fromConstraints(constraints);
              Widget buildCartPanel() {
                return StreamBuilder<List<AddonGroupDb>>(
                  stream: db.watchAddonGroups(activeOnly: true),
                  builder: (context, groupsSnapshot) {
                    return StreamBuilder<List<AddonItemDb>>(
                      stream: db.watchAddonItems(),
                      builder: (context, itemsSnapshot) {
                        return StreamBuilder<List<ProductAddonLinkDb>>(
                          stream: db.watchProductAddonLinks(),
                          builder: (context, linksSnapshot) {
                            final activeGroups =
                                groupsSnapshot.data ?? const <AddonGroupDb>[];
                            final addonItems =
                                itemsSnapshot.data ?? const <AddonItemDb>[];
                            final addonLinks =
                                linksSnapshot.data ??
                                const <ProductAddonLinkDb>[];

                            final activeGroupsById = <int, AddonGroupDb>{
                              for (final group in activeGroups) group.id: group,
                            };
                            final itemsByGroupId = <int, List<AddonItemDb>>{};
                            for (final item in addonItems) {
                              itemsByGroupId
                                  .putIfAbsent(item.groupId, () => [])
                                  .add(item);
                            }
                            final groupIdsByProductId = <int, Set<int>>{};
                            for (final link in addonLinks) {
                              if (!activeGroupsById.containsKey(link.groupId)) {
                                continue;
                              }
                              groupIdsByProductId
                                  .putIfAbsent(link.productId, () => <int>{})
                                  .add(link.groupId);
                            }

                            Future<void> openAddons(CartItem item) async {
                              final productGroups = groupsForProduct(
                                item.product.id,
                                activeGroupsById: activeGroupsById,
                                itemsByGroupId: itemsByGroupId,
                                groupIdsByProductId: groupIdsByProductId,
                              );
                              if (productGroups.isEmpty) return;
                              final selected = await ProductAddonsDialog.show(
                                context,
                                productName: item.product.name,
                                groups: productGroups,
                                initialSelected: item.selectedAddons,
                              );
                              if (selected == null) return;
                              cartNotifier.updateAddons(item.lineId, selected);
                            }

                            return CartPanel(
                              cart: cart,
                              onIncrement: cartNotifier.increment,
                              onDecrement: cartNotifier.decrement,
                              onRemove: cartNotifier.remove,
                              onUpdatePrice: cartNotifier.updateUnitPrice,
                              onEditAddons: openAddons,
                              hasAddonsForProduct: (productId) =>
                                  groupsForProduct(
                                    productId,
                                    activeGroupsById: activeGroupsById,
                                    itemsByGroupId: itemsByGroupId,
                                    groupIdsByProductId: groupIdsByProductId,
                                  ).isNotEmpty,
                              compact: layout.compact,
                              showServices: featureSettings.showServices,
                              showTables: featureSettings.showTables,
                              onCustomerChanged: (customerId, customerName) {
                                posController.setSelectedCustomer(
                                  customerId: customerId,
                                  customerName: customerName,
                                );
                              },
                              onServiceChanged:
                                  (serviceId, serviceName, serviceCost) {
                                    posController.setSelectedService(
                                      serviceId: serviceId,
                                      serviceName: serviceName,
                                      serviceCost: serviceCost,
                                    );
                                  },
                              onTableChanged: (tableId, tableName) {
                                posController.setSelectedTable(
                                  tableId: tableId,
                                  tableName: tableName,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }

              return Column(
                children: [
                  PosTopBar(compact: layout.compact),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: layout.cartFlex,
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(layout.panelPadding),
                            child: buildCartPanel(),
                          ),
                        ),
                        Expanded(
                          flex: layout.productsFlex,
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(layout.panelPadding),
                            child: ProductsGrid(
                              productsAsync: productsAsync,
                              categories: categories,
                              onAddToCart: cartNotifier.add,
                              showBrandFilter: featureSettings.showBrands,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InvoiceSummaryBar(
                    cart: cart,
                    discount: posState.discountAmount,
                    onDiscountTap: () => posController.onTapDiscount(context),
                    delivery: posState.deliveryFee,
                    onDeliveryTap: () => posController.onTapDelivery(context),
                    service: posState.selectedServiceCost,
                    showServiceCost: featureSettings.showServices,
                    compact: layout.compact,
                  ),
                  PosBottomActions(
                    total: posState.totalAfterDiscountWithDelivery,
                    compact: layout.compact,
                    onCancel: cart.isEmpty ? null : cartNotifier.clear,
                    onQuotation: () async {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      try {
                        await printRunner.printQuotation(
                          cart: cart,
                          discount: posState.discountAmount,
                          serviceId: posState.selectedServiceId,
                          serviceName: posState.selectedServiceName,
                          serviceCost: posState.selectedServiceCost,
                          tableId: posState.selectedTableId,
                          tableName: posState.selectedTableName,
                        );
                        if (!mounted) return;
                        AppFeedback.success(context, 'تمت طباعة بيان السعر');
                      } catch (e) {
                        if (!mounted) return;
                        AppFeedback.error(context, e.toString());
                      }
                    },
                    onComment: () async {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      final note = await AppDialogs.showSaleComment(context);
                      if (note == null) return;
                      final trimmed = note.trim();
                      final sale = SuspendedSale(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        items: cart.items,
                        note: trimmed,
                        createdAt: DateTime.now(),
                        discountType: posState.discountType,
                        discountValue: posState.discountValue,
                      );
                      suspendedNotifier.addSale(sale);
                      cartNotifier.clear();
                      posController.clearPayments();
                      posController.setDiscount(DiscountType.percent, 0);
                    },
                    onCash: () {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      _handleCheckout(
                        cart: cart,
                        action: () => checkout.checkoutCash(
                          cart,
                          posState.discountAmount,
                          customerId: posState.selectedCustomerId,
                          delivery: deliveryInput,
                          service: serviceInput,
                          table: tableInput,
                        ),
                      );
                    },
                    onCard: () {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      AppDialogs.showCardPaymentConfirm(context).then((
                        confirmed,
                      ) {
                        if (confirmed != true) return;
                        _handleCheckout(
                          cart: cart,
                          action: () => checkout.checkoutCard(
                            cart,
                            discount: posState.discountAmount,
                            customerId: posState.selectedCustomerId,
                            delivery: deliveryInput,
                            service: serviceInput,
                            table: tableInput,
                          ),
                        );
                      });
                    },
                    onDeferred: () {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      _handleCheckout(
                        cart: cart,
                        action: () => checkout.checkoutCredit(
                          cart,
                          discount: posState.discountAmount,
                          customerId: posState.selectedCustomerId,
                          delivery: deliveryInput,
                          service: serviceInput,
                          table: tableInput,
                        ),
                      );
                    },
                    onMulti: () async {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      final result = await posController.onTapMultiPayment(
                        context,
                      );
                      if (result != true) {
                        posController.clearPayments();
                        return;
                      }
                      final state = ref.read(posControllerProvider);
                      final payments = state.payments
                          .map(
                            (line) => PaymentInput(
                              methodCode: line.methodCode,
                              amount: line.amount,
                              reference: line.account,
                              note: line.note,
                            ),
                          )
                          .toList();
                      await _handleCheckout(
                        cart: cart,
                        action: () => checkout.checkoutMulti(
                          cart,
                          payments,
                          discount: posState.discountAmount,
                          customerId: posState.selectedCustomerId,
                          delivery: deliveryInput,
                          service: serviceInput,
                          table: tableInput,
                        ),
                      );
                      posController.clearPayments();
                    },
                    onReceipt: () {
                      if (cart.isEmpty) {
                        warnEmptyCart();
                        return;
                      }
                      _openReceiptPreview();
                    },
                    onRecentSales: () => showDialog(
                      context: context,
                      builder: (context) => const RecentSalesDialog(),
                    ),
                    onLogout: () async {
                      await ref.read(authRepositoryProvider).clearToken();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                  ),
                ],
              );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PosLayoutConfig {
  const _PosLayoutConfig({
    required this.compact,
    required this.panelPadding,
    required this.productsFlex,
    required this.cartFlex,
  });

  final bool compact;
  final double panelPadding;
  final int productsFlex;
  final int cartFlex;

  static _PosLayoutConfig fromConstraints(BoxConstraints constraints) {
    const baseWidth = 1024.0;
    const baseHeight = 768.0;
    final compact =
        constraints.maxWidth < baseWidth || constraints.maxHeight < baseHeight;

    return _PosLayoutConfig(
      compact: compact,
      panelPadding: compact ? 6 : AppSpacing.sm.toDouble(),
      productsFlex: 3,
      cartFlex: 2,
    );
  }
}
