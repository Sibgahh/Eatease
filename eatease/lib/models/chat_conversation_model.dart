import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversationModel {
  final String id;
  final String customerId;
  final String merchantId;
  final String customerName;
  final String merchantName;
  final String customerImage;
  final String merchantImage;
  final DateTime lastMessageTime;
  final String lastMessage;
  final int unreadCount;
  final bool active;
  final DateTime expirationTime;
  final String lastMessageSenderId;
  final String lastMessageSenderRole;
  final bool isOrderChat;
  final String? orderId;

  ChatConversationModel({
    required this.id,
    required this.customerId,
    required this.merchantId,
    required this.customerName,
    required this.merchantName,
    required this.customerImage,
    required this.merchantImage,
    required this.lastMessageTime,
    required this.lastMessage,
    required this.unreadCount,
    this.active = true,
    required this.expirationTime,
    this.lastMessageSenderId = '',
    this.lastMessageSenderRole = '',
    this.isOrderChat = false,
    this.orderId,
  });

  // Convert model to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'merchantId': merchantId,
      'customerName': customerName,
      'merchantName': merchantName,
      'customerImage': customerImage,
      'merchantImage': merchantImage,
      'lastMessageTime': lastMessageTime,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'active': active,
      'expirationTime': expirationTime,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderRole': lastMessageSenderRole,
      'isOrderChat': isOrderChat,
      'orderId': orderId,
    };
  }

  // Create model from Firestore document
  factory ChatConversationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatConversationModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      merchantId: data['merchantId'] ?? '',
      customerName: data['customerName'] ?? '',
      merchantName: data['merchantName'] ?? '',
      customerImage: data['customerImage'] ?? '',
      merchantImage: data['merchantImage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      unreadCount: data['unreadCount'] ?? 0,
      active: data['active'] ?? true,
      expirationTime: (data['expirationTime'] as Timestamp?)?.toDate() ?? 
        DateTime.now().add(const Duration(hours: 1)),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageSenderRole: data['lastMessageSenderRole'] ?? '',
      isOrderChat: data['isOrderChat'] ?? false,
      orderId: data['orderId'],
    );
  }

  // Create a copy with updated fields
  ChatConversationModel copyWith({
    String? id,
    String? customerId,
    String? merchantId,
    String? customerName,
    String? merchantName,
    String? customerImage,
    String? merchantImage,
    DateTime? lastMessageTime,
    String? lastMessage,
    int? unreadCount,
    bool? active,
    DateTime? expirationTime,
    String? lastMessageSenderId,
    String? lastMessageSenderRole,
    bool? isOrderChat,
    String? orderId,
  }) {
    return ChatConversationModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      merchantId: merchantId ?? this.merchantId,
      customerName: customerName ?? this.customerName,
      merchantName: merchantName ?? this.merchantName,
      customerImage: customerImage ?? this.customerImage,
      merchantImage: merchantImage ?? this.merchantImage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      active: active ?? this.active,
      expirationTime: expirationTime ?? this.expirationTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderRole: lastMessageSenderRole ?? this.lastMessageSenderRole,
      isOrderChat: isOrderChat ?? this.isOrderChat,
      orderId: orderId ?? this.orderId,
    );
  }
} 