import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for handling device GPS location
class LocationService {
  /// Check if location services are enabled and permissions are granted
  static Future<bool> isLocationAvailable() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Request location permissions from the user
  static Future<bool> requestPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('📍 Location services are disabled');
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('📍 Location permissions denied by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('📍 Location permissions permanently denied');
      // You could show a dialog here to guide user to settings
      return false;
    }

    print('📍 Location permission granted');
    return true;
  }

  /// Get current device location
  /// Returns null if location cannot be obtained
  static Future<LatLng?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Ensure we have permission
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      print('📍 GPS Location obtained: ${position.latitude}, ${position.longitude}');
      print('📍 Accuracy: ${position.accuracy}m');
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('📍 Error getting location: $e');
      return null;
    }
  }

  /// Get last known location (faster but may be outdated)
  static Future<LatLng?> getLastKnownLocation() async {
    try {
      bool hasPermission = await isLocationAvailable();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return null;
      }

      print('📍 Last known location: ${position.latitude}, ${position.longitude}');
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('📍 Error getting last known location: $e');
      return null;
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Open device location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for when permissions are permanently denied)
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Stream of location updates (for real-time tracking)
  static Stream<LatLng> getLocationStream({
    Duration interval = const Duration(seconds: 5),
  }) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update only when moved 10 meters
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .map((position) {
      print('📍 Location update: ${position.latitude}, ${position.longitude}');
      return LatLng(position.latitude, position.longitude);
    });
  }
}
