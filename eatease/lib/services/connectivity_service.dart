import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  // Factory constructor to return the same instance
  factory ConnectivityService() => _instance;
  
  // Internal constructor
  ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  final _connectionStatusController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _lastConnectionStatus = true;
  
  void initialize() {
    // Check connectivity when service initializes
    checkConnectivity();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Consider connected if any result is not none
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _checkFirebaseConnection(hasConnection);
    });
    
    // Start periodic checks
    Timer.periodic(const Duration(seconds: 30), (_) => checkConnectivity());
  }
  
  void dispose() {
    _connectionStatusController.close();
  }
  
  Future<void> checkConnectivity() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    // Consider connected if any result is not none
    final hasConnection = connectivityResults.any((result) => result != ConnectivityResult.none);
    await _checkFirebaseConnection(hasConnection);
  }
  
  // Check both connectivity result and actual firebase connection
  Future<void> _checkFirebaseConnection(bool hasNetworkConnection) async {
    bool isConnected = hasNetworkConnection;
    
    if (isConnected) {
      // Double-check with an actual Firebase request
      try {
        // Try a lightweight Firestore operation to confirm real connectivity
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
        isConnected = true;
      } catch (e) {
        print('Firebase connection test failed: $e');
        isConnected = false;
      }
    }
    
    // Only notify listeners if status has changed
    if (_lastConnectionStatus != isConnected) {
      _lastConnectionStatus = isConnected;
      _connectionStatusController.add(isConnected);
    }
  }
  
  // Helper method to get current connection status
  Future<bool> isConnected() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    return connectivityResults.any((result) => result != ConnectivityResult.none);
  }
}