import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Network quality levels for adaptive video streaming
enum NetworkQuality {
  excellent, // >5 Mbps - HD video
  good,      // 2-5 Mbps - SD video
  fair,      // 0.5-2 Mbps - Low quality video
  poor,      // <0.5 Mbps - Images only
  offline,   // No connection
}

/// Service to detect network quality and adapt content delivery
class NetworkQualityService {
  NetworkQuality _currentQuality = NetworkQuality.good;
  Timer? _checkTimer;
  final List<Function(NetworkQuality)> _listeners = [];

  NetworkQuality get currentQuality => _currentQuality;

  /// Start monitoring network quality
  void startMonitoring() {
    _checkQuality();
    // Check every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkQuality());
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Add listener for quality changes
  void addListener(Function(NetworkQuality) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(Function(NetworkQuality) listener) {
    _listeners.remove(listener);
  }

  /// Check network quality by downloading a small test file
  Future<void> _checkQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Download a 100KB test image from a fast CDN
      final response = await http.get(
        Uri.parse('https://via.placeholder.com/100x100.jpg'),
      ).timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes.length;
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        final mbps = (bytes * 8) / (seconds * 1000000); // Convert to Mbps
        
        final newQuality = _calculateQuality(mbps);
        
        if (newQuality != _currentQuality) {
          _currentQuality = newQuality;
          _notifyListeners();
        }
      }
    } catch (e) {
      // Network error - assume poor quality
      if (_currentQuality != NetworkQuality.poor) {
        _currentQuality = NetworkQuality.poor;
        _notifyListeners();
      }
    }
  }

  NetworkQuality _calculateQuality(double mbps) {
    if (mbps > 5) return NetworkQuality.excellent;
    if (mbps > 2) return NetworkQuality.good;
    if (mbps > 0.5) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener(_currentQuality);
    }
  }

  /// Get recommended video quality based on network
  String getRecommendedVideoQuality() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return '720p';
      case NetworkQuality.good:
        return '480p';
      case NetworkQuality.fair:
        return '360p';
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 'thumbnail'; // Show images only
    }
  }

  /// Should load videos based on network quality
  bool shouldLoadVideos() {
    return _currentQuality != NetworkQuality.poor && 
           _currentQuality != NetworkQuality.offline;
  }
}

/// Provider for network quality service
final networkQualityServiceProvider = Provider<NetworkQualityService>((ref) {
  final service = NetworkQualityService();
  service.startMonitoring();
  
  ref.onDispose(() {
    service.stopMonitoring();
  });
  
  return service;
});

/// Provider for current network quality state
final networkQualityProvider = StateProvider<NetworkQuality>((ref) {
  final service = ref.watch(networkQualityServiceProvider);
  return service.currentQuality;
});
