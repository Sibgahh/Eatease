import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';

/// A service that periodically cleans up expired data in the app
class CleanupService {
  static final CleanupService _instance = CleanupService._internal();
  factory CleanupService() => _instance;
  
  // Private constructor
  CleanupService._internal();
  
  final ChatService _chatService = ChatService();
  Timer? _cleanupTimer;
  bool _isRunning = false;
  
  // Start the periodic cleanup service
  void startPeriodicCleanup({Duration checkInterval = const Duration(minutes: 15)}) {
    if (_isRunning) return;
    
    print('Starting periodic cleanup service with interval: ${checkInterval.inMinutes} minutes');
    
    // Run cleanup once immediately
    _runCleanup();
    
    // Then set up periodic timer
    _cleanupTimer = Timer.periodic(checkInterval, (_) {
      _runCleanup();
    });
    
    _isRunning = true;
  }
  
  // Stop the cleanup service
  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _isRunning = false;
    print('Cleanup service stopped');
  }
  
  // Run cleanup tasks
  Future<void> _runCleanup() async {
    if (kDebugMode) {
      print('Running scheduled cleanup tasks at ${DateTime.now().toIso8601String()}');
    }
    
    try {
      // Clean up expired chat conversations
      await _chatService.cleanupExpiredConversations();
      
      // Add any other cleanup tasks here as needed
      
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
  
  // Manually trigger a cleanup
  Future<void> runManualCleanup() async {
    print('Running manual cleanup');
    return _runCleanup();
  }
} 