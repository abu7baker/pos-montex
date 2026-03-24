import 'package:equatable/equatable.dart';
import 'dart:typed_data';

class ProductEntity extends Equatable {
  const ProductEntity({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.imagePath,
    this.imageData,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final String? imagePath;
  final Uint8List? imageData;
  final DateTime? updatedAt;

  ProductEntity copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    int? categoryId,
    String? categoryName,
    int? brandId,
    String? brandName,
    String? imagePath,
    Uint8List? imageData,
    DateTime? updatedAt,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      imagePath: imagePath ?? this.imagePath,
      imageData: imageData ?? this.imageData,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    price,
    stock,
    categoryId,
    categoryName,
    brandId,
    brandName,
    imagePath,
    imageData,
    updatedAt,
  ];
}

typedef Product = ProductEntity;
