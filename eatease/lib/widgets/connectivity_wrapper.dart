import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../screens/shared/no_connection_screen.dart';

/// A widget that shows a no connection screen when device is offline
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  
  const ConnectivityWrapper({
    Key? key, 
    required this.child,
  }) : super(key: key);

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<bool> _connectionSubscription;
  bool _isConnected = true;
  
  @override
  void initState() {
    super.initState();
    
    // Listen to connection changes
    _connectionSubscription = _connectivityService.connectionStatus.listen((isConnected) {
      if (mounted && isConnected != _isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
        
        // Show a snackbar when connection is restored
        if (isConnected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Connection restored'),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
    
    // Check connection immediately
    _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    final isConnected = await _connectivityService.isConnected();
    if (mounted && isConnected != _isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }
  
  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isConnected 
        ? widget.child
        : NoConnectionScreen(
            onRetry: () {
              setState(() {
                _isConnected = true;
              });
            },
          ),
    );
  }
} 