import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';
import '../models/chat_message_model.dart';
import '../models/chat_conversation_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Collection references
  CollectionReference get _messages => _firestore.collection('chat_messages');
  CollectionReference get _conversations => _firestore.collection('chat_conversations');
  CollectionReference get _users => _firestore.collection('users');
  
  // Create or get an order-specific conversation
  Future<String> createOrGetOrderConversation(String customerId, String merchantId, String orderId) async {
    try {
      if (customerId.isEmpty || merchantId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid user IDs or order ID provided');
      }
      
      // Check if there's already a conversation for this order
      final query = await _conversations
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      
      // Get user details
      final customerDetails = await getUserDetails(customerId);
      final merchantDetails = await getUserDetails(merchantId);
      
      // Create new conversation
      final conversationData = {
        'customerId': customerId,
        'merchantId': merchantId,
        'customerName': customerDetails['name'],
        'merchantName': merchantDetails['name'],
        'customerImage': customerDetails['image'],
        'merchantImage': merchantDetails['image'],
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': 0,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expirationTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'lastMessageSenderId': customerId,
        'lastMessageSenderRole': 'customer',
        'orderId': orderId,
        'isOrderChat': true,
      };
      
      final docRef = await _conversations.add(conversationData);
      return docRef.id;
    } catch (e) {
      print('Error creating order conversation: $e');
      throw Exception('Failed to create order conversation: ${e.toString()}');
    }
  }
  
  // Delete conversation related to a completed order
  Future<void> deleteOrderConversation(String orderId) async {
    try {
      // Find the conversation for this order
      final conversationQuery = await _conversations
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      
      if (conversationQuery.docs.isEmpty) {
        print('No conversation found for order $orderId');
        return;
      }
      
      final conversationDoc = conversationQuery.docs.first;
      final conversationId = conversationDoc.id;
      final chatId = ChatMessageModel.createChatId(
          conversationDoc['customerId'], conversationDoc['merchantId']);
      
      // Delete all messages
      final messagesQuery = await _messages
          .where('chatId', isEqualTo: chatId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final messageDoc in messagesQuery.docs) {
        batch.delete(messageDoc.reference);
      }
      
      // Delete the conversation
      batch.delete(conversationDoc.reference);
      
      // Execute batch
      await batch.commit();
      print('Successfully deleted conversation for order $orderId');
    } catch (e) {
      print('Error deleting order conversation: $e');
    }
  }
  
  // Clean up all conversations for completed or cancelled orders
  Future<void> cleanupCompletedOrderConversations() async {
    try {
      // First, get all orders that are completed or cancelled
      final completedOrders = await _firestore
          .collection('orders')
          .where('status', whereIn: ['completed', 'cancelled'])
          .get();
      
      if (completedOrders.docs.isEmpty) {
        print('No completed or cancelled orders found to clean up conversations');
        return;
      }
      
      print('Found ${completedOrders.docs.length} completed/cancelled orders to check for conversations');
      
      // Get order IDs
      final List<String> orderIds = completedOrders.docs.map((doc) => doc.id).toList();
      
      // Find conversations with these order IDs
      // Due to Firestore limitations on "whereIn", process in batches of 10
      for (int i = 0; i < orderIds.length; i += 10) {
        final endIndex = (i + 10 < orderIds.length) ? i + 10 : orderIds.length;
        final batchIds = orderIds.sublist(i, endIndex);
        
        final conversationsQuery = await _conversations
            .where('orderId', whereIn: batchIds)
            .get();
        
        print('Found ${conversationsQuery.docs.length} conversations for batch ${i ~/ 10 + 1} of completed orders');
        
        if (conversationsQuery.docs.isEmpty) continue;
        
        // Delete conversations and their messages
        final batch = _firestore.batch();
        for (final conversationDoc in conversationsQuery.docs) {
          final conversationData = conversationDoc.data() as Map<String, dynamic>;
          final chatId = ChatMessageModel.createChatId(
              conversationData['customerId'], conversationData['merchantId']);
          
          // Get messages for this conversation
          final messagesQuery = await _messages
              .where('chatId', isEqualTo: chatId)
              .get();
          
          // Add message deletions to batch
          for (final messageDoc in messagesQuery.docs) {
            batch.delete(messageDoc.reference);
          }
          
          // Add conversation deletion to batch
          batch.delete(conversationDoc.reference);
          
          print('Scheduled deletion for conversation ${conversationDoc.id} with orderId ${conversationData['orderId']}');
        }
        
        // Execute batch
        await batch.commit();
        print('Successfully deleted conversations for batch ${i ~/ 10 + 1} of completed orders');
      }
    } catch (e) {
      print('Error cleaning up completed order conversations: $e');
    }
  }
  
  // Clean up expired conversations
  Future<void> cleanupExpiredConversations() async {
    try {
      final now = Timestamp.now();
      
      // Query for conversations that have expired
      final expiredConversationsQuery = await _conversations
          .where('expirationTime', isLessThan: now)
          .get();
      
      if (expiredConversationsQuery.docs.isEmpty) {
        return;
      }
      
      print('Found ${expiredConversationsQuery.docs.length} expired conversations to delete');
      
      // Batch delete conversations and their messages
      final batch = _firestore.batch();
      
      for (final doc in expiredConversationsQuery.docs) {
        final conversationId = doc.id;
        
        // Get all messages for this conversation
        final messagesQuery = await _messages
            .where('chatId', isEqualTo: ChatMessageModel.createChatId(
                doc['customerId'], doc['merchantId']))
            .get();
        
        // Add message deletions to batch
        for (final messageDoc in messagesQuery.docs) {
          batch.delete(messageDoc.reference);
        }
        
        // Add conversation deletion to batch
        batch.delete(doc.reference);
        
        print('Scheduled deletion for conversation $conversationId with ${messagesQuery.docs.length} messages');
      }
      
      // Execute the batch
      await batch.commit();
      print('Successfully cleaned up expired conversations');
    } catch (e) {
      print('Error cleaning up expired conversations: $e');
    }
  }
  
  // Get user details
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['displayName'] ?? data['name'] ?? 'Unknown User',
          'image': data['profileImage'] ?? '',
          'role': data['role'] ?? 'customer',
        };
      }
      return {
        'id': userId,
        'name': 'Unknown User',
        'image': '',
        'role': 'customer',
      };
    } catch (e) {
      print('Error getting user details: $e');
      return {
        'id': userId,
        'name': 'Unknown User',
        'image': '',
        'role': 'customer',
      };
    }
  }
  
  // Get all conversations for the current user
  Stream<List<ChatConversationModel>> getConversations() {
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    try {
      // First query for conversations where user is the customer
      final customerConversationsStream = _conversations
          .where('customerId', isEqualTo: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ChatConversationModel.fromDocument(doc))
              .toList());
      
      // Second query for conversations where user is the merchant
      final merchantConversationsStream = _conversations
          .where('merchantId', isEqualTo: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ChatConversationModel.fromDocument(doc))
              .toList());
      
      // Combine both streams and sort them
      return StreamGroup.merge([customerConversationsStream, merchantConversationsStream])
          .map((conversations) {
            // Sort combined conversations by lastMessageTime
            conversations.sort((a, b) => 
                b.lastMessageTime.compareTo(a.lastMessageTime));
            return conversations;
          });
    } catch (e) {
      print('Error getting conversations: $e');
      return Stream.value([]);
    }
  }
  
  // Get all messages for a specific conversation
  Stream<List<ChatMessageModel>> getMessages(String chatId) {
    return _messages
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit to last 100 messages
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessageModel.fromDocument(doc))
              .toList();
        });
  }
  
  // Check if a conversation exists between two users
  Future<String?> getConversationId(String userId1, String userId2) async {
    try {
      // First try finding where userId1 is customer and userId2 is merchant
      final query1 = await _conversations
          .where('customerId', isEqualTo: userId1)
          .where('merchantId', isEqualTo: userId2)
          .limit(1)
          .get();
      
      if (query1.docs.isNotEmpty) {
        return query1.docs.first.id;
      }
      
      // Then try the reverse (userId2 is customer, userId1 is merchant)
      final query2 = await _conversations
          .where('customerId', isEqualTo: userId2)
          .where('merchantId', isEqualTo: userId1)
          .limit(1)
          .get();
      
      if (query2.docs.isNotEmpty) {
        return query2.docs.first.id;
      }
      
      return null;
    } catch (e) {
      print('Error checking for existing conversation: $e');
      return null;
    }
  }
  
  // Create a new conversation or get existing
  Future<String> createOrGetConversation(String customerId, String merchantId, {String? orderId}) async {
    try {
      if (customerId.isEmpty || merchantId.isEmpty) {
        throw Exception('Invalid user IDs provided');
      }
      
      // If no order ID is provided, we need to check if there's an active order
      if (orderId == null) {
        // Check for active orders between this customer and merchant
        final QuerySnapshot activeOrders = await FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: customerId)
            .where('merchantId', isEqualTo: merchantId)
            .where('status', whereIn: ['pending', 'preparing', 'ready'])
            .limit(1)
            .get();
        
        if (activeOrders.docs.isEmpty) {
          throw Exception('No active orders found. Chat is only available during order processing.');
        }
        
        // Use the first active order ID
        orderId = activeOrders.docs.first.id;
      }
      
      // Check if a conversation already exists for this order
      final orderConversationQuery = await _conversations
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      
      if (orderConversationQuery.docs.isNotEmpty) {
        return orderConversationQuery.docs.first.id;
      }
      
      // Get user details
      final customerDetails = await getUserDetails(customerId);
      if (customerDetails['name'] == 'Unknown User') {
        print('Warning: Customer details not fully loaded for ID: $customerId');
      }
      
      final merchantDetails = await getUserDetails(merchantId);
      if (merchantDetails['name'] == 'Unknown User') {
        print('Warning: Merchant details not fully loaded for ID: $merchantId');
      }
      
      // Determine who initiated the conversation
      final String initiatorId = currentUserId ?? customerId;
      final bool isCustomerInitiator = initiatorId == customerId;
      
      // Create new conversation
      final conversationData = {
        'customerId': customerId,
        'merchantId': merchantId,
        'customerName': customerDetails['name'],
        'merchantName': merchantDetails['name'],
        'customerImage': customerDetails['image'],
        'merchantImage': merchantDetails['image'],
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': 0,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': initiatorId,
        'lastMessageSenderRole': isCustomerInitiator ? 'customer' : 'merchant',
        'orderId': orderId,
        'isOrderChat': true,
      };
      
      final docRef = await _conversations.add(conversationData);
      if (docRef.id.isEmpty) {
        throw Exception('Failed to create conversation document');
      }
      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      throw Exception('Failed to create conversation: ${e.toString()}');
    }
  }
  
  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    if (currentUserId == null) {
      return;
    }
    
    try {
      // Get conversation
      final conversationDoc = await _conversations.doc(conversationId).get();
      if (!conversationDoc.exists) {
        return;
      }
      
      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      
      // Determine if user is customer or merchant
      bool isCustomer = conversationData['customerId'] == currentUserId;
      String otherUserId = isCustomer 
          ? conversationData['merchantId'] 
          : conversationData['customerId'];
      
      // Create the chat ID (same format used when storing messages)
      final chatId = ChatMessageModel.createChatId(currentUserId!, otherUserId);
      
      // Get unread messages sent TO current user (where current user is the receiver)
      final querySnapshot = await _messages
          .where('chatId', isEqualTo: chatId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        // If no unread messages, just reset the unread count
        if ((isCustomer && conversationData['lastMessageSenderRole'] == 'merchant') ||
            (!isCustomer && conversationData['lastMessageSenderRole'] == 'customer')) {
          await _conversations.doc(conversationId).update({'unreadCount': 0});
        }
        return;
      }
      
      // Update each message to mark as read
      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      // Reset unread count in conversation if current user is the receiver
      if ((isCustomer && conversationData['lastMessageSenderRole'] == 'merchant') ||
          (!isCustomer && conversationData['lastMessageSenderRole'] == 'customer')) {
        batch.update(_conversations.doc(conversationId), {'unreadCount': 0});
      }
      
      // Commit batch
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
      // Don't throw exception as this is a non-critical operation
    }
  }
  
  // Send a text message
  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      final senderDetails = await getUserDetails(currentUserId!);
      final chatId = ChatMessageModel.createChatId(currentUserId!, receiverId);
      
      // Create message
      final messageData = {
        'senderId': currentUserId,
        'senderName': senderDetails['name'],
        'receiverId': receiverId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'chatId': chatId,
      };
      
      // Get conversation document to determine whether sender is customer or merchant
      final conversationDoc = await _conversations.doc(conversationId).get();
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }
      
      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final isCustomer = currentUserId == conversationData['customerId'];
      
      // Use a batch to ensure consistency
      final batch = _firestore.batch();
      
      // Add message to collection
      final messageRef = _messages.doc();
      batch.set(messageRef, messageData);
      
      // Update conversation with last message and increment unread count for receiver
      batch.update(_conversations.doc(conversationId), {
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        // Update unread count only for the receiver, not the sender
        'unreadCount': FieldValue.increment(1),
        // Set the sender type to manage notification routing
        'lastMessageSenderId': currentUserId,
        'lastMessageSenderRole': isCustomer ? 'customer' : 'merchant',
        // Update expiration time to extend the conversation
        'expirationTime': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      });
      
      // Commit all operations together
      await batch.commit();
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }
  
  // Send an image message
  Future<void> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required File imageFile,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      final senderDetails = await getUserDetails(currentUserId!);
      final chatId = ChatMessageModel.createChatId(currentUserId!, receiverId);
      
      // Compress and resize image for mobile before upload
      // Upload image to Firebase Storage
      final fileName = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref().child('chat_images/$fileName');
      
      // Add metadata to set cache control for better mobile performance
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=86400', // Cache for 24 hours
      );
      
      final uploadTask = ref.putFile(imageFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Get conversation document to determine whether sender is customer or merchant
      final conversationDoc = await _conversations.doc(conversationId).get();
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }
      
      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final isCustomer = currentUserId == conversationData['customerId'];
      
      // Use a batch to ensure consistency
      final batch = _firestore.batch();
      
      // Create message
      final messageData = {
        'senderId': currentUserId,
        'senderName': senderDetails['name'],
        'receiverId': receiverId,
        'content': '[Image]',
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'chatId': chatId,
      };
      
      // Add message to collection
      final messageRef = _messages.doc();
      batch.set(messageRef, messageData);
      
      // Update conversation with last message
      batch.update(_conversations.doc(conversationId), {
        'lastMessage': '[Image]',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
        'lastMessageSenderId': currentUserId,
        'lastMessageSenderRole': isCustomer ? 'customer' : 'merchant',
        // Update expiration time to extend the conversation
        'expirationTime': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      });
      
      // Commit all operations together
      await batch.commit();
    } catch (e) {
      print('Error sending image message: $e');
      throw Exception('Failed to send image message: ${e.toString()}');
    }
  }
  
  // Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete messages in the conversation
      final chatMessages = await _messages
          .where('conversationId', isEqualTo: conversationId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in chatMessages.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the conversation
      batch.delete(_conversations.doc(conversationId));
      
      // Commit batch
      await batch.commit();
    } catch (e) {
      print('Error deleting conversation: $e');
      throw Exception('Failed to delete conversation');
    }
  }
  
  // Extend a conversation's expiration time
  Future<void> extendConversationExpiration(String conversationId, {Duration extension = const Duration(hours: 1)}) async {
    try {
      // Calculate new expiration time
      final conversationDoc = await _conversations.doc(conversationId).get();
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }
      
      final data = conversationDoc.data() as Map<String, dynamic>;
      DateTime currentExpiration;
      
      if (data['expirationTime'] != null) {
        currentExpiration = (data['expirationTime'] as Timestamp).toDate();
      } else {
        currentExpiration = DateTime.now();
      }
      
      // Add extension to the current expiration time
      final newExpiration = currentExpiration.add(extension);
      
      // Update the document with new expiration time
      await _conversations.doc(conversationId).update({
        'expirationTime': Timestamp.fromDate(newExpiration)
      });
      
      print('Conversation $conversationId expiration extended to $newExpiration');
    } catch (e) {
      print('Error extending conversation expiration: $e');
      throw Exception('Failed to extend conversation: ${e.toString()}');
    }
  }
  
  // Update existing conversations with the new fields for backward compatibility
  Future<void> updateExistingConversations() async {
    try {
      final batch = _firestore.batch();
      bool hasUpdates = false;
      
      // Get all conversations that don't have the sender role fields
      final querySnapshot = await _conversations
          .where('lastMessageSenderRole', isNull: true)
          .limit(100) // Process in batches
          .get();
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Determine sender based on available information
        String lastMessageSenderId = data['customerId'] ?? '';
        String lastMessageSenderRole = 'customer'; // Default to customer as initiator
        
        batch.update(doc.reference, {
          'lastMessageSenderId': lastMessageSenderId,
          'lastMessageSenderRole': lastMessageSenderRole,
        });
        
        hasUpdates = true;
      }
      
      if (hasUpdates) {
        await batch.commit();
        print('Updated ${querySnapshot.docs.length} existing conversations');
      }
    } catch (e) {
      print('Error updating existing conversations: $e');
    }
  }
  
  // Force delete all conversations for a user's completed orders
  Future<void> forceDeleteAllCompletedOrderConversations(String userId) async {
    if (userId.isEmpty) return;
    
    try {
      print('Force deleting all completed order conversations for user $userId');
      
      // Get all orders for this user that are completed or cancelled
      final completedOrders = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', whereIn: ['completed', 'cancelled'])
          .get();
      
      if (completedOrders.docs.isEmpty) {
        print('No completed orders found for user $userId');
        return;
      }
      
      print('Found ${completedOrders.docs.length} completed/cancelled orders');
      
      // Get all conversations where this user is the customer
      final userConversations = await _conversations
          .where('customerId', isEqualTo: userId)
          .get();
      
      if (userConversations.docs.isEmpty) {
        print('No conversations found for user $userId');
        return;
      }
      
      print('Found ${userConversations.docs.length} conversations for user $userId');
      
      // Create a batch to delete conversations
      final batch = _firestore.batch();
      int deletedCount = 0;
      
      // Check each conversation to see if it's for a completed order
      for (final conversationDoc in userConversations.docs) {
        final conversationData = conversationDoc.data() as Map<String, dynamic>;
        final orderId = conversationData['orderId'];
        
        if (orderId != null) {
          // Check if this order is in the completed orders list
          final isCompleted = completedOrders.docs.any((orderDoc) => orderDoc.id == orderId);
          
          if (isCompleted) {
            // Delete all messages for this conversation
            final chatId = ChatMessageModel.createChatId(
                conversationData['customerId'], conversationData['merchantId']);
            
            final messagesQuery = await _messages
                .where('chatId', isEqualTo: chatId)
                .get();
            
            for (final messageDoc in messagesQuery.docs) {
              batch.delete(messageDoc.reference);
            }
            
            // Delete the conversation
            batch.delete(conversationDoc.reference);
            deletedCount++;
            
            print('Scheduled deletion for conversation ${conversationDoc.id} with orderId $orderId');
          }
        }
      }
      
      if (deletedCount > 0) {
        // Execute batch
        await batch.commit();
        print('Successfully deleted $deletedCount conversations for completed orders');
      } else {
        print('No conversations for completed orders found to delete');
      }
    } catch (e) {
      print('Error force deleting completed order conversations: $e');
    }
  }
} 