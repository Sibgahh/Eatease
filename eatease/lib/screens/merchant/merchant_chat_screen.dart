import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../models/chat_conversation_model.dart';
import '../../utils/app_theme.dart';
import '../customer/chat/chat_detail_screen.dart';

class MerchantChatScreen extends StatefulWidget {
  final bool showScaffold;
  
  const MerchantChatScreen({
    Key? key,
    this.showScaffold = false,
  }) : super(key: key);

  @override
  State<MerchantChatScreen> createState() => _MerchantChatScreenState();
}

class _MerchantChatScreenState extends State<MerchantChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Clean up old conversations
    _cleanupCompletedOrderChats();
    // Force refresh initially
    _refreshData();
  }

  Future<void> _cleanupCompletedOrderChats() async {
    try {
      await _chatService.cleanupCompletedOrderConversations();
    } catch (e) {
      print('Error cleaning up chats: $e');
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      // Force a refresh of the current user state
      await _authService.currentUser?.reload();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Could not load conversations. Pull down to retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = RefreshIndicator(
      onRefresh: () async {
        // Force refresh the stream data
        await _refreshData();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Column(
        children: [
          // Optional loading indicator at the top
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          
          Expanded(
            child: StreamBuilder<List<ChatConversationModel>>(
              stream: _chatService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || _hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading conversations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage.isNotEmpty 
                              ? _errorMessage
                              : 'Pull down to refresh',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
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
                          'No customer messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Messages from your customers will appear here',
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
    );
    
    // Return with or without Scaffold based on showScaffold parameter
    return widget.showScaffold
        ? Scaffold(
            appBar: AppBar(
              title: const Text(
                'Customer Messages',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.primaryColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.cleaning_services),
                  tooltip: 'Clean up old chats',
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                    });
                    await _cleanupCompletedOrderChats();
                    await _refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cleaned up completed order chats')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: SafeArea(child: content),
          )
        : content;
  }

  Widget _buildConversationTile(ChatConversationModel conversation) {
    final bool isUserMerchant = _authService.currentUser?.uid == conversation.merchantId;
    final String otherUserName = isUserMerchant ? conversation.customerName : conversation.merchantName;
    final String otherUserImage = isUserMerchant ? conversation.customerImage : conversation.merchantImage;
    final String otherUserId = isUserMerchant ? conversation.customerId : conversation.merchantId;
    
    // Only show unread count for messages sent by the other user
    final bool showUnreadCount = 
        isUserMerchant && 
        conversation.lastMessageSenderRole == 'customer' && 
        conversation.unreadCount > 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
          
          // Refresh the list after returning
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                backgroundImage: otherUserImage.isNotEmpty
                    ? NetworkImage(otherUserImage)
                    : null,
                radius: 24,
                child: otherUserImage.isEmpty
                    ? Icon(Icons.person, color: AppTheme.primaryColor)
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Name
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Time
                        Text(
                          _formatTimestamp(conversation.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Message and unread count
                    Row(
                      children: [
                        // Direction icon
                        if (conversation.lastMessageSenderRole == 'customer')
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 12,
                              color: Colors.green,
                            ),
                          )
                        else if (conversation.lastMessageSenderRole == 'merchant')
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.arrow_upward,
                              size: 12,
                              color: Colors.blue,
                            ),
                          ),
                          
                        // Message preview
                        Expanded(
                          child: Text(
                            conversation.lastMessage.isEmpty
                                ? 'New customer inquiry'
                                : conversation.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: showUnreadCount ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // Unread count
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
                  ],
                ),
              ),
            ],
          ),
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