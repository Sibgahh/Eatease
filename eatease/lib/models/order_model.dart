import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String merchantId;
  final String merchantName;
  final double totalAmount;
  final List<OrderItemModel> items;
  final String status; // pending, preparing, ready, completed, cancelled
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? customerNote;
  final String? merchantNote;
  final Map<String, dynamic>? paymentDetails;
  final String paymentStatus; // pending, paid, refunded, failed

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.merchantId,
    required this.merchantName,
    required this.totalAmount,
    required this.items,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.customerNote,
    this.merchantNote,
    this.paymentDetails,
    required this.paymentStatus,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      merchantId: map['merchantId'] ?? '',
      merchantName: map['merchantName'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList() ??
          [],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      customerNote: map['customerNote'],
      merchantNote: map['merchantNote'],
      paymentDetails: map['paymentDetails'],
      paymentStatus: map['paymentStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'customerNote': customerNote,
      'merchantNote': merchantNote,
      'paymentDetails': paymentDetails,
      'paymentStatus': paymentStatus,
    };
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? merchantId,
    String? merchantName,
    double? totalAmount,
    List<OrderItemModel>? items,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? customerNote,
    String? merchantNote,
    Map<String, dynamic>? paymentDetails,
    String? paymentStatus,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      customerNote: customerNote ?? this.customerNote,
      merchantNote: merchantNote ?? this.merchantNote,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}

class OrderItemModel {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final List<String>? options;
  final String? imageUrl;
  final Map<String, dynamic>? customizations;

  OrderItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.options,
    this.imageUrl,
    this.customizations,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      options: (map['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      imageUrl: map['imageUrl'],
      customizations: map['customizations'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'options': options,
      'imageUrl': imageUrl,
      'customizations': customizations,
    };
  }
} 