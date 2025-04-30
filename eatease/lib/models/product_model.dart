import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String merchantId;
  final String name;
  final String description;
  final double price;
  final List<String> imageUrls;
  final String category;
  final bool isAvailable;
  final int preparationTimeMinutes;
  final List<String>? tags;
  final Map<String, dynamic>? nutritionInfo;
  final Map<String, dynamic>? customizations;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.category,
    this.isAvailable = true,
    required this.preparationTimeMinutes,
    this.tags,
    this.nutritionInfo,
    this.customizations,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      merchantId: map['merchantId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      category: map['category'] ?? 'Other',
      isAvailable: map['isAvailable'] ?? true,
      preparationTimeMinutes: map['preparationTimeMinutes'] ?? 30,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      nutritionInfo: map['nutritionInfo'],
      customizations: map['customizations'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'category': category,
      'isAvailable': isAvailable,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': tags,
      'nutritionInfo': nutritionInfo,
      'customizations': customizations,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  ProductModel copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? description,
    double? price,
    List<String>? imageUrls,
    String? category,
    bool? isAvailable,
    int? preparationTimeMinutes,
    List<String>? tags,
    Map<String, dynamic>? nutritionInfo,
    Map<String, dynamic>? customizations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTimeMinutes: preparationTimeMinutes ?? this.preparationTimeMinutes,
      tags: tags ?? this.tags,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
      customizations: customizations ?? this.customizations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 