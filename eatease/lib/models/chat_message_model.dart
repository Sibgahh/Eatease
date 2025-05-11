import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String chatId; // Combination of senderId and receiverId
  final String? imageUrl; // Optional image message

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.chatId,
    this.imageUrl,
  });

  // Convert model to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp,
      'isRead': isRead,
      'chatId': chatId,
      'imageUrl': imageUrl,
    };
  }

  // Create model from Firestore document
  factory ChatMessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      chatId: data['chatId'] ?? '',
      imageUrl: data['imageUrl'],
    );
  }

  // Create a copy with updated fields
  ChatMessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? chatId,
    String? imageUrl,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      chatId: chatId ?? this.chatId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  // Helper to create a chat ID from two user IDs
  static String createChatId(String userId1, String userId2) {
    // Sort IDs to ensure consistent chat ID regardless of who initiates the chat
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }
} 