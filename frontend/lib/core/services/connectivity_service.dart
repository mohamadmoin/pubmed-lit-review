import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service that monitors and provides network connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  /// Stream controller for connectivity changes
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  /// Stream of connectivity status (true = connected, false = disconnected)
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  
  /// Current connection status
  bool _isConnected = true;
  
  /// Returns the current connection status
  bool get isConnected => _isConnected;
  
  /// Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  /// Factory constructor that returns the singleton instance
  factory ConnectivityService() {
    return _instance;
  }
  
  /// Internal constructor
  ConnectivityService._internal() {
    // Initialize connectivity monitoring
    _initConnectivity();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    try {
      final status = await _connectivity.checkConnectivity();
      _updateConnectionStatus(status);
    } catch (e) {
      if (kDebugMode) {
        print('Could not get connectivity status: $e');
      }
      // Assume connected if we can't determine status
      _isConnected = true;
      _connectionStatusController.add(_isConnected);
    }
  }
  
  /// Update connection status based on connectivity result
  void _updateConnectionStatus(ConnectivityResult result) {
    _isConnected = result != ConnectivityResult.none;
    _connectionStatusController.add(_isConnected);
    
    if (kDebugMode) {
      print('Connection status changed: $_isConnected ($result)');
    }
  }
  
  /// Check if there is an active internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectionStatusController.close();
  }
} 