import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../models/chat_message_model.dart';
import '../../../models/chat_conversation_model.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/bottom_nav_bar.dart';
import 'chat_detail_screen.dart';
import '../customer_orders_screen.dart';

class CustomerChatScreen extends StatefulWidget {
  final bool showScaffold;
  
  const CustomerChatScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _refreshing = false;
  List<ChatConversationModel> _cachedConversations = [];
  
  @override
  void initState() {
    super.initState();
    _cleanupChats();
    _checkForActiveOrders();
  }
  
  // Clean up chats from completed orders
  Future<void> _cleanupChats() async {
    try {
      // First try the general cleanup
      await _chatService.cleanupCompletedOrderConversations();
      
      // Then force delete all completed order conversations for the current user
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await _chatService.forceDeleteAllCompletedOrderConversations(currentUser.uid);
      }
    } catch (e) {
      print('Error cleaning up chats: $e');
    }
  }
  
  // Check for active orders and create conversations if needed
  Future<void> _checkForActiveOrders() async {
    if (_refreshing) return; // Prevent multiple simultaneous refreshes
    
    setState(() {
      _refreshing = true;
      if (_cachedConversations.isEmpty) {
        _isLoading = true;
      }
    });
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _refreshing = false;
          _isLoading = false;
        });
        return;
      }
      
      // Get active orders
      final activeOrders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .get();
      
      bool conversationsCreated = false;
      
      // For each active order, ensure a conversation exists
      for (final orderDoc in activeOrders.docs) {
        final order = orderDoc.data();
        final merchantId = order['merchantId'];
        final orderId = orderDoc.id;
        
        if (merchantId != null && merchantId is String) {
          try {
            // Create or get a conversation for this order
            final conversationId = await _chatService.createOrGetOrderConversation(
              user.uid,
              merchantId,
              orderId,
            );
            
            if (conversationId.isNotEmpty) {
              conversationsCreated = true;
            }
          } catch (e) {
            print('Error creating conversation for order $orderId: $e');
          }
        }
      }
      
      // If we created at least one conversation, wait a moment for Firestore to update
      if (conversationsCreated) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Get current conversations to cache them
      final conversations = await FirebaseFirestore.instance
          .collection('chat_conversations')
          .where('customerId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      if (conversations.docs.isNotEmpty) {
        _cachedConversations = conversations.docs
            .map((doc) => ChatConversationModel.fromDocument(doc))
            .toList();
      }
    } catch (e) {
      print('Error checking for active orders: $e');
    } finally {
      setState(() {
        _refreshing = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<ChatConversationModel>>(
      stream: _chatService.getConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedConversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading conversations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Use snapshot data if available, otherwise use cached conversations
        final conversations = snapshot.data ?? _cachedConversations;
        
        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Active Conversations',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'You can chat with merchants during active orders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Go to My Orders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerOrdersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            // Update the cached conversations whenever we get new data
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              _cachedConversations = snapshot.data!;
            }
            
            final conversation = conversations[index];
            final currentUserId = _authService.currentUser?.uid;
            final bool isCustomer = conversation.customerId == currentUserId;
            
            final String otherUserId = isCustomer 
                ? conversation.merchantId 
                : conversation.customerId;
            
            final String otherUserName = isCustomer
                ? conversation.merchantName
                : conversation.customerName;
            
            final String otherUserImage = isCustomer
                ? conversation.merchantImage
                : conversation.customerImage;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        conversationId: conversation.id,
                        otherUserId: otherUserId,
                        otherUserName: otherUserName,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: otherUserImage.isNotEmpty
                      ? NetworkImage(otherUserImage)
                      : null,
                  child: otherUserImage.isEmpty
                      ? Icon(
                          isCustomer ? Icons.store : Icons.person,
                          color: Colors.grey.shade400,
                        )
                      : null,
                ),
                title: Text(
                  otherUserName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Row(
                  children: [
                    if (conversation.isOrderChat)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Order',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        conversation.lastMessage.isEmpty
                            ? 'No messages yet'
                            : conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMessageTime(conversation.lastMessageTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (conversation.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          conversation.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    if (!widget.showScaffold) {
      return content;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat with Merchants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Clean up old chats',
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _cleanupChats();
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleaned up completed order chats')),
              );
            },
          ),
          if (_refreshing)
            Container(
              padding: const EdgeInsets.all(8),
              child: const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkForActiveOrders,
            ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: _checkForActiveOrders,
        backgroundColor: AppTheme.customerPrimaryColor,
        child: _refreshing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.refresh),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 3, // Chat tab
        userRole: 'customer',
      ),
    );
  }
  
  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MM/dd/yy').format(dateTime);
    }
  }
} 