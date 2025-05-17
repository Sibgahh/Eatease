import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final List<String>? options;
  final String? specialInstructions;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.options,
    this.specialInstructions,
    this.imageUrl,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'options': options,
      'specialInstructions': specialInstructions,
      'imageUrl': imageUrl,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      specialInstructions: map['specialInstructions'],
      imageUrl: map['imageUrl'],
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String merchantId;
  final String merchantName;
  final List<OrderItem> items;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String deliveryAddress;
  final String customerPhone;
  final String customerNote;
  final String deliveryOption;
  final String? promoCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? merchantNote;
  final double? rating;
  final String? review;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.merchantId,
    required this.merchantName,
    required this.items,
    required this.totalAmount,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.customerPhone,
    required this.customerNote,
    required this.deliveryOption,
    this.promoCode,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.merchantNote,
    this.rating,
    this.review,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'customerNote': customerNote,
      'deliveryOption': deliveryOption,
      'promoCode': promoCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'merchantNote': merchantNote,
      'rating': rating,
      'review': review,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      merchantId: map['merchantId'] ?? '',
      merchantName: map['merchantName'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item))
          .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerNote: map['customerNote'] ?? '',
      deliveryOption: map['deliveryOption'] ?? 'Standard Delivery',
      promoCode: map['promoCode'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      merchantNote: map['merchantNote'],
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'],
    );
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? merchantId,
    String? merchantName,
    List<OrderItem>? items,
    double? totalAmount,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    String? status,
    String? paymentStatus,
    String? paymentMethod,
    String? deliveryAddress,
    String? customerPhone,
    String? customerNote,
    String? deliveryOption,
    String? promoCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? merchantNote,
    double? rating,
    String? review,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerNote: customerNote ?? this.customerNote,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      promoCode: promoCode ?? this.promoCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      merchantNote: merchantNote ?? this.merchantNote,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }
} 