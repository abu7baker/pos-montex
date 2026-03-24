import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../products/domain/product_entity.dart';
import '../pos_models.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.fallbackLogoPath,
  });

  final Product product;
  final VoidCallback onTap;
  final String? fallbackLogoPath;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHover = false;

  double get _priceWithTax =>
      (widget.product.price * (1 + PosState.fixedTaxRate) * 100).round() / 100;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00B5E2).withOpacity(_isHover ? 0.8 : 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(_isHover ? 0.08 : 0.03),
              blurRadius: _isHover ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRect(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 90,
                    height: 122,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        children: [
                          Text(
                            _priceWithTax.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: _ProductImage(
                                path: widget.product.imagePath,
                                bytes: widget.product.imageData,
                                fallbackLogoPath: widget.fallbackLogoPath,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(
                                top: 4,
                                left: 2,
                                right: 2,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFEEEEEE),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Tooltip(
                                message: widget.product.name,
                                child: Text(
                                  widget.product.name,
                                  maxLines: 3,
                                  softWrap: true,
                                  overflow: TextOverflow.fade,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                    height: 1.15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.path,
    required this.bytes,
    required this.fallbackLogoPath,
  });

  final String? path;
  final Uint8List? bytes;
  final String? fallbackLogoPath;

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    final value = path?.trim();
    if (value != null && value.isNotEmpty) {
      final file = File(value);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(file, width: 64, height: 64, fit: BoxFit.cover),
        );
      }
    }

    final fallback = fallbackLogoPath?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      final file = File(fallback);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(file, width: 64, height: 64, fit: BoxFit.contain),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/images/logo.jpg',
        width: 64,
        height: 64,
        fit: BoxFit.contain,
      ),
    );
  }
}
