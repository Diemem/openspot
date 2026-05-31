import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feature flags manager using Supabase
class FeatureFlags {
  static final _supabase = Supabase.instance.client;
  static Map<String, bool> _cachedFlags = {};
  static DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  /// Initialize and fetch feature flags
  static Future<void> initialize() async {
    await refresh();
  }

  /// Refresh feature flags from Supabase
  static Future<void> refresh() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userRole = await _getUserRole();
      final appVersion = await _getAppVersion();

      // Call Supabase function to get all features for this user
      final response = await _supabase.rpc(
        'get_user_features',
        params: {
          'p_user_id': userId,
          'p_user_role': userRole,
          'p_app_version': appVersion,
        },
      );

      if (response != null) {
        _cachedFlags = Map<String, bool>.fromEntries(
          (response as List).map((item) => MapEntry(
                item['flag_key'] as String,
                item['is_enabled'] as bool,
              )),
        );
        _lastFetch = DateTime.now();
      }
    } catch (e) {
      print('Failed to fetch feature flags: $e');
      // Keep using cached flags if fetch fails
    }
  }

  /// Check if feature is enabled
  static bool isEnabled(String flagKey) {
    // Auto-refresh if cache is stale
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > _cacheDuration) {
      refresh(); // Fire and forget
    }

    return _cachedFlags[flagKey] ?? false;
  }

  /// Get all feature flags
  static Map<String, bool> getAllFlags() {
    return Map.unmodifiable(_cachedFlags);
  }

  /// Check if a specific feature is enabled (with real-time check)
  static Future<bool> isEnabledAsync(String flagKey) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userRole = await _getUserRole();
      final appVersion = await _getAppVersion();

      final response = await _supabase.rpc(
        'is_feature_enabled',
        params: {
          'p_flag_key': flagKey,
          'p_user_id': userId,
          'p_user_role': userRole,
          'p_app_version': appVersion,
        },
      );

      return response as bool? ?? false;
    } catch (e) {
      print('Failed to check feature flag: $e');
      return _cachedFlags[flagKey] ?? false;
    }
  }

  /// Get user role from profile
  static Future<String?> _getUserRole() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('role, sub_role')
          .eq('id', userId)
          .single();

      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get app version
  static Future<String> _getAppVersion() async {
    try {
      // You can use package_info_plus to get actual version
      // For now, return hardcoded version
      return '1.0.0';
    } catch (e) {
      return '1.0.0';
    }
  }

  // Predefined feature flags (for type safety and autocomplete)
  static bool get enableNewAgencyDashboard =>
      isEnabled('enable_new_agency_dashboard');

  static bool get enableAIPropertyDescription =>
      isEnabled('enable_ai_property_description');

  static bool get enableVideoTours => isEnabled('enable_video_tours');

  static bool get enableChatFeature => isEnabled('enable_chat_feature');

  static bool get enableAdvancedSearch => isEnabled('enable_advanced_search');

  static bool get maintenanceMode => isEnabled('maintenance_mode');
}

/// Riverpod provider for feature flags
final featureFlagsProvider = StateNotifierProvider<FeatureFlagsNotifier, Map<String, bool>>((ref) {
  return FeatureFlagsNotifier();
});

class FeatureFlagsNotifier extends StateNotifier<Map<String, bool>> {
  FeatureFlagsNotifier() : super({}) {
    _initialize();
  }

  Future<void> _initialize() async {
    await FeatureFlags.initialize();
    state = FeatureFlags.getAllFlags();
  }

  Future<void> refresh() async {
    await FeatureFlags.refresh();
    state = FeatureFlags.getAllFlags();
  }

  bool isEnabled(String flagKey) {
    return state[flagKey] ?? false;
  }
}

/// App configuration manager using Supabase
class AppConfig {
  static final _supabase = Supabase.instance.client;
  static Map<String, dynamic> _cachedConfig = {};

  /// Initialize and fetch app configuration
  static Future<void> initialize() async {
    await refresh();
  }

  /// Refresh configuration from Supabase
  static Future<void> refresh() async {
    try {
      final response = await _supabase.from('app_config').select();

      if (response != null) {
        _cachedConfig = Map<String, dynamic>.fromEntries(
          (response as List).map((item) => MapEntry(
                item['config_key'] as String,
                item['config_value'],
              )),
        );
      }
    } catch (e) {
      print('Failed to fetch app config: $e');
    }
  }

  /// Get configuration value
  static dynamic get(String key, {dynamic defaultValue}) {
    return _cachedConfig[key] ?? defaultValue;
  }

  /// Get string configuration
  static String getString(String key, {String defaultValue = ''}) {
    final value = _cachedConfig[key];
    if (value is String) return value;
    return defaultValue;
  }

  /// Get integer configuration
  static int getInt(String key, {int defaultValue = 0}) {
    final value = _cachedConfig[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get boolean configuration
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = _cachedConfig[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  /// Get JSON configuration
  static Map<String, dynamic> getJson(String key, {Map<String, dynamic>? defaultValue}) {
    final value = _cachedConfig[key];
    if (value is Map<String, dynamic>) return value;
    return defaultValue ?? {};
  }

  // Predefined config getters
  static String get minSupportedVersion => getString('min_supported_version', defaultValue: '1.0.0');
  static String get forceUpdateVersion => getString('force_update_version', defaultValue: '0.9.0');
  static Map<String, dynamic> get maintenanceMessage => getJson('maintenance_message');
  static List<dynamic> get featureAnnouncements => get('feature_announcements', defaultValue: []);
}
