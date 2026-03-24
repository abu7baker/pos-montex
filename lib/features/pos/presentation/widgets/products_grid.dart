import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import '../../../products/domain/product_entity.dart';
import 'pos_select.dart';
import 'product_card.dart';

const int _otherCategoryId = -1;
const int _allBrandId = -1;

class ProductsGrid extends ConsumerStatefulWidget {
  const ProductsGrid({
    super.key,
    required this.productsAsync,
    required this.categories,
    required this.onAddToCart,
    this.showBrandFilter = true,
  });

  final AsyncValue<List<Product>> productsAsync;
  final List<ProductCategoryDb> categories;
  final void Function(Product product) onAddToCart;
  final bool showBrandFilter;

  @override
  ConsumerState<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends ConsumerState<ProductsGrid> {
  int _selectedBrandId = _allBrandId;
  int _selectedCategoryIndex = 0;
  String? _fallbackLogoPath;

  @override
  void initState() {
    super.initState();
    _loadFallbackLogoPath();
  }

  Future<void> _loadFallbackLogoPath() async {
    final db = ref.read(appDbProvider);
    final mm80 = await db.getDefaultInvoiceTemplate(80);
    final a4 = await db.getDefaultInvoiceTemplate(210);
    String? resolved;
    for (final candidate in [mm80?.logoPath, a4?.logoPath]) {
      final path = candidate?.trim() ?? '';
      if (path.isNotEmpty) {
        resolved = path;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _fallbackLogoPath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    final products = widget.productsAsync.valueOrNull ?? const <Product>[];
    final categories = _buildCategories(products, widget.categories);
    final safeCategoryIndex = _selectedCategoryIndex < categories.length
        ? _selectedCategoryIndex
        : 0;
    final selectedCategory = categories[safeCategoryIndex];

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neutralGrey.withOpacity(0.5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalCategories = constraints.maxWidth >= 560;
            final categoryRailWidth = constraints.maxWidth < 720
                ? 96.0
                : (constraints.maxWidth < 1200 ? 106.0 : 120.0);
            final gridAreaWidth = !useVerticalCategories
                ? constraints.maxWidth
                : (constraints.maxWidth - categoryRailWidth - 24).clamp(
                    320.0,
                    5000.0,
                  );
            const crossAxisCount = 5;
            final childAspectRatio = (gridAreaWidth / crossAxisCount) / 150;

            Widget buildGrid(int selectedBrandId) {
              return widget.productsAsync.when(
                data: (loadedProducts) {
                  final filteredByCategory = _filterByCategory(
                    loadedProducts,
                    selectedCategory,
                    widget.categories,
                  );
                  final filtered = _filterByBrand(
                    filteredByCategory,
                    selectedBrandId,
                  );
                  if (filtered.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات'));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      return ProductCard(
                        product: filtered[index],
                        fallbackLogoPath: _fallbackLogoPath,
                        onTap: () => widget.onAddToCart(filtered[index]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('خطأ: $e')),
              );
            }

            Widget buildBody(int selectedBrandId) {
              return Expanded(
                child: useVerticalCategories
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          Container(
                            width: categoryRailWidth,
                            margin: const EdgeInsets.only(
                              right: 8,
                              left: 8,
                              top: 8,
                              bottom: 8,
                            ),
                            child: ListView.separated(
                              itemCount: categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _CategoryItem(
                                  label: categories[index].label,
                                  isActive: index == safeCategoryIndex,
                                  onTap: () => setState(
                                    () => _selectedCategoryIndex = index,
                                  ),
                                  width: double.infinity,
                                  height: 54,
                                );
                              },
                            ),
                          ),
                          Expanded(child: buildGrid(selectedBrandId)),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return _CategoryItem(
                                  label: categories[index].label,
                                  isActive: index == safeCategoryIndex,
                                  onTap: () => setState(
                                    () => _selectedCategoryIndex = index,
                                  ),
                                  width: 112,
                                  height: 48,
                                );
                              },
                            ),
                          ),
                          Expanded(child: buildGrid(selectedBrandId)),
                        ],
                      ),
              );
            }

            if (!widget.showBrandFilter) {
              return Column(children: [buildBody(_allBrandId)]);
            }

            return StreamBuilder<List<BrandDb>>(
              stream: db.watchBrands(activeOnly: true),
              builder: (context, snapshot) {
                final brands = snapshot.data ?? const <BrandDb>[];
                final brandOptions = <PosSelectOption<int>>[
                  const PosSelectOption(
                    value: _allBrandId,
                    label: 'جميع العلامات التجارية',
                  ),
                  ...brands.map(
                    (b) => PosSelectOption<int>(value: b.id, label: b.name),
                  ),
                ];
                final effectiveBrandId =
                    brandOptions.any((o) => o.value == _selectedBrandId)
                    ? _selectedBrandId
                    : _allBrandId;

                return Column(
                  children: [
                    _ProductsHeader(
                      maxWidth: constraints.maxWidth,
                      options: brandOptions,
                      value: effectiveBrandId,
                      onChanged: (value) => setState(
                        () => _selectedBrandId = value ?? _allBrandId,
                      ),
                    ),
                    buildBody(effectiveBrandId),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.id, required this.label});

  final int? id;
  final String label;
}

List<_CategoryOption> _buildCategories(
  List<Product> products,
  List<ProductCategoryDb> categories,
) {
  final options = <_CategoryOption>[
    const _CategoryOption(id: null, label: 'جميع الأقسام'),
  ];

  final categoryIds = <int>{};
  for (final category in categories) {
    final name = category.name.trim();
    if (name.isEmpty) continue;
    options.add(_CategoryOption(id: category.id, label: name));
    categoryIds.add(category.id);
  }

  final hasOther = products.any(
    (p) => p.categoryId == null || !categoryIds.contains(p.categoryId),
  );
  if (hasOther) {
    options.add(const _CategoryOption(id: _otherCategoryId, label: 'أخرى'));
  }

  return options;
}

List<Product> _filterByCategory(
  List<Product> products,
  _CategoryOption selected,
  List<ProductCategoryDb> categories,
) {
  if (selected.id == null) return products;
  if (selected.id == _otherCategoryId) {
    final knownIds = categories.map((c) => c.id).toSet();
    return products
        .where((p) => p.categoryId == null || !knownIds.contains(p.categoryId))
        .toList();
  }
  return products.where((p) => p.categoryId == selected.id).toList();
}

List<Product> _filterByBrand(List<Product> products, int selectedBrandId) {
  if (selectedBrandId == _allBrandId) return products;
  return products.where((p) => p.brandId == selectedBrandId).toList();
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00B5E2) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF00B5E2).withOpacity(isActive ? 1 : 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF00B5E2),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({
    required this.maxWidth,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final double maxWidth;
  final List<PosSelectOption<int>> options;
  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectorWidth = maxWidth < 560
        ? (maxWidth * 0.72).clamp(170.0, 240.0)
        : 240.0;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          textDirection: ui.TextDirection.rtl,
          children: [
            PosSelect<int>(
              options: options,
              value: value,
              hintText: 'جميع العلامات التجارية',
              width: selectorWidth,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
