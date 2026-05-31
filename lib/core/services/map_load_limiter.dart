import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service to limit map loads and prevent excessive API usage
class MapLoadLimiter {
  static final MapLoadLimiter _instance = MapLoadLimiter._internal();
  factory MapLoadLimiter() => _instance;
  MapLoadLimiter._internal();

  // Track map loads per session
  int _sessionLoads = 0;
  DateTime? _sessionStart;
  
  // Limits
  static const int maxLoadsPerSession = 30; // Allow more exploration
  static const Duration sessionDuration = Duration(hours: 1);
  
  // Debounce timer for map movements
  Timer? _debounceTimer;
  
  /// Check if map load is allowed
  bool canLoadMap() {
    _initSession();
    
    if (_sessionLoads >= maxLoadsPerSession) {
      print('⚠️ MAP LOAD LIMIT: Reached $maxLoadsPerSession loads this session');
      return false;
    }
    
    return true;
  }
  
  /// Record a map load
  void recordLoad() {
    _initSession();
    _sessionLoads++;
    print('📊 MAP LOADS: $_sessionLoads/$maxLoadsPerSession this session');
  }
  
  /// Debounce map updates (wait for user to stop moving)
  void debounceMapUpdate(VoidCallback callback, {Duration delay = const Duration(milliseconds: 1200)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }
  
  /// Initialize or reset session
  void _initSession() {
    final now = DateTime.now();
    
    if (_sessionStart == null || now.difference(_sessionStart!) > sessionDuration) {
      _sessionStart = now;
      _sessionLoads = 0;
      print('🔄 MAP SESSION: Started new session');
    }
  }
  
  /// Reset session (for testing or manual reset)
  void resetSession() {
    _sessionStart = null;
    _sessionLoads = 0;
    _debounceTimer?.cancel();
  }
  
  /// Get current session stats
  Map<String, dynamic> getStats() {
    return {
      'loads': _sessionLoads,
      'limit': maxLoadsPerSession,
      'remaining': maxLoadsPerSession - _sessionLoads,
      'sessionStart': _sessionStart?.toIso8601String(),
    };
  }
}
