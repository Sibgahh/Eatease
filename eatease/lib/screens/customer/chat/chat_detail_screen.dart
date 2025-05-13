import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/chat_message_model.dart';
import '../../../models/chat_conversation_model.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/bottom_nav_bar.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatDetailScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isSending = false;
  bool _errorLoadingConversation = false;
  String _errorMessage = '';
  
  // For expiration tracking
  DateTime _expirationTime = DateTime.now().add(const Duration(hours: 1));
  Timer? _expirationTimer;
  String _timeRemaining = '1:00:00';

  @override
  void initState() {
    super.initState();
    // Validate conversation ID
    if (widget.conversationId.isEmpty) {
      setState(() {
        _errorLoadingConversation = true;
        _errorMessage = 'Invalid conversation information';
      });
      return;
    }
    
    // Get conversation expiration time
    _loadExpirationTime();
    
    // Start timer to update the expiration countdown
    _startExpirationTimer();
    
    // Mark messages as read when opening the conversation
    _markMessagesAsRead();
    
    // Add connection state listener for mobile
    _addConnectionStateListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _expirationTimer?.cancel();
    super.dispose();
  }
  
  // Listen for connectivity changes
  void _addConnectionStateListener() {
    try {
      // For better mobile performance, we could add connection state handling here
      // using connectivity_plus or other packages
    } catch (e) {
      print('Error setting up connection listener: $e');
    }
  }
  
  // Load the expiration time from Firestore
  Future<void> _loadExpirationTime() async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .get();
          
      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        if (data['expirationTime'] != null) {
          setState(() {
            _expirationTime = (data['expirationTime'] as Timestamp).toDate();
          });
          _updateTimeRemaining();
        }
      }
    } catch (e) {
      print('Error loading expiration time: $e');
      
      // Set a default expiration time 1 hour from now if there's an error
      setState(() {
        _expirationTime = DateTime.now().add(const Duration(hours: 1));
        _updateTimeRemaining();
      });
    }
  }
  
  // Start a timer to update the remaining time display
  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
    });
  }
  
  // Update the time remaining string
  void _updateTimeRemaining() {
    final now = DateTime.now();
    final remaining = _expirationTime.difference(now);
    
    if (remaining.isNegative) {
      setState(() {
        _timeRemaining = 'Expired';
      });
      return;
    }
    
    final hours = remaining.inHours;
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    
    setState(() {
      _timeRemaining = '$hours:$minutes:$seconds';
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.conversationId);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Clear text field immediately for better UX
      final messageText = message;
      _messageController.clear();
      
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUserId,
        content: messageText,
      );
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message. Please try again.'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
      print('Failed to send message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      final imageFile = File(pickedFile.path);
      await _chatService.sendImageMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUserId,
        imageFile: imageFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle error state
    if (_errorLoadingConversation) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.otherUserName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage.isEmpty 
                      ? 'Please try again later or start a new conversation.'
                      : _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(
          currentIndex: 3, // Profile tab (closest match)
          userRole: 'customer',
        ),
      );
    }

    final String chatId = ChatMessageModel.createChatId(
      _authService.currentUser?.uid ?? '',
      widget.otherUserId,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),  // Dismiss keyboard when tapping outside
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.otherUserName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Expiration notice banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: Colors.amber.shade100,
                width: double.infinity,
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This conversation will expire in $_timeRemaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _extendExpiration,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Extend',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Messages list
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: _chatService.getMessages(chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation by sending a message',
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

                    // If new messages arrive, scroll to bottom after frame is rendered
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Display latest messages at the bottom
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final bool isMe = message.senderId == _authService.currentUser?.uid;
                        return _buildMessageBubble(message, isMe);
                      },
                    );
                  },
                ),
              ),

              // Loading indicator
              if (_isLoading)
                const LinearProgressIndicator(),

              // Message input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Image picker button
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.photo,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      onPressed: _sendImage,
                    ),

                    // Text input field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              width: 0,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              width: 1,
                              color: AppTheme.primaryColor.withOpacity(0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          isDense: true,
                          fillColor: Colors.grey.shade100,
                          filled: true,
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    ),

                    // Send button
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(
          currentIndex: 3, // Profile tab (closest match)
          userRole: 'customer',
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    final messageDateTime = message.timestamp;
    final timeString = DateFormat.jm().format(messageDateTime); // Format as 3:30 PM
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.75; // 75% of screen width

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          
          const SizedBox(width: 8),
          
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxBubbleWidth,
            ),
            child: Container(
              padding: message.imageUrl != null
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryColor.withOpacity(0.9)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display image if present
                  if (message.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () {
                        // Show full image in a dialog when tapped
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    // Image
                                    Image.network(
                                      message.imageUrl!,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return SizedBox(
                                          height: 300,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Close button
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 5,
                                              ),
                                            ],
                                          ),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.imageUrl!,
                          width: maxBubbleWidth - 16, // Account for padding
                          fit: BoxFit.fitWidth,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: maxBubbleWidth - 16,
                              height: 150,
                              color: Colors.grey.shade100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: isMe ? Colors.white : AppTheme.primaryColor,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: maxBubbleWidth - 16,
                              height: 100,
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  // Display text message
                  if (message.content != '[Image]')
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                    
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          if (isMe)
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: message.isRead ? Colors.blue : Colors.grey.shade500,
            ),
        ],
      ),
    );
  }

  // Add method to extend the conversation expiration
  Future<void> _extendExpiration() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _chatService.extendConversationExpiration(widget.conversationId);
      
      // Reload the expiration time
      await _loadExpirationTime();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation extended by 1 hour'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to extend conversation: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 