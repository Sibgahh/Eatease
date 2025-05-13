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

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({Key? key}) : super(key: key);

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Conversations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatConversationModel>>(
              stream: _chatService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final conversations = snapshot.data ?? [];

                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your conversations with merchants will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return _buildConversationTile(conversation);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 3, // Chat tab is now at index 3
        userRole: 'customer',
      ),
    );
  }

  Widget _buildConversationTile(ChatConversationModel conversation) {
    final bool isUserCustomer = _authService.currentUser?.uid == conversation.customerId;
    final String otherUserName = isUserCustomer ? conversation.merchantName : conversation.customerName;
    final String otherUserImage = isUserCustomer ? conversation.merchantImage : conversation.customerImage;
    final String otherUserId = isUserCustomer ? conversation.merchantId : conversation.customerId;
    
    // Only show unread count for messages sent by the merchant
    final bool showUnreadCount = 
        isUserCustomer && 
        conversation.lastMessageSenderRole == 'merchant' && 
        conversation.unreadCount > 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: () async {
          // Navigate to chat detail screen
          await Navigator.push(
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
          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
          backgroundImage: otherUserImage.isNotEmpty
              ? NetworkImage(otherUserImage)
              : null,
          radius: 24,
          child: otherUserImage.isEmpty
              ? Icon(Icons.person, color: AppTheme.primaryColor)
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
            if (conversation.lastMessageSenderRole == 'customer')
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.arrow_upward,
                  size: 12,
                  color: Colors.blue,
                ),
              )
            else if (conversation.lastMessageSenderRole == 'merchant')
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.arrow_downward,
                  size: 12,
                  color: Colors.green,
                ),
              ),
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? 'Start a conversation'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(conversation.lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            if (showUnreadCount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(timestamp); // Today: 3:30 PM
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(timestamp); // Within a week: Mon, Tue, etc.
    } else {
      return DateFormat.yMd().format(timestamp); // Older: 01/20/2023
    }
  }
} 