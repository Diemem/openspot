import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment types
enum Environment {
  development,
  staging,
  production,
}

/// Environment configuration manager
class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.development;

  /// Get current environment
  static Environment get currentEnvironment => _currentEnvironment;

  /// Check if running in development
  static bool get isDevelopment => _currentEnvironment == Environment.development;

  /// Check if running in staging
  static bool get isStaging => _currentEnvironment == Environment.staging;

  /// Check if running in production
  static bool get isProduction => _currentEnvironment == Environment.production;

  /// Initialize environment configuration
  static Future<void> initialize({Environment environment = Environment.development}) async {
    _currentEnvironment = environment;
    
    // Load appropriate .env file based on environment
    String envFile;
    switch (environment) {
      case Environment.development:
        envFile = '.env.development';
        break;
      case Environment.staging:
        envFile = '.env.staging';
        break;
      case Environment.production:
        envFile = '.env.production';
        break;
    }

    try {
      await dotenv.load(fileName: envFile);
      print('✅ Loaded environment: ${environment.name} from $envFile');
    } catch (e) {
      print('⚠️ Failed to load $envFile, falling back to .env');
      await dotenv.load(fileName: '.env');
    }
  }

  /// Get environment variable
  static String get(String key, {String defaultValue = ''}) {
    return dotenv.env[key] ?? defaultValue;
  }

  /// Get required environment variable (throws if not found)
  static String getRequired(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Required environment variable $key is not set');
    }
    return value;
  }

  /// Get boolean environment variable
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }

  // Supabase Configuration
  static String get supabaseUrl => getRequired('SUPABASE_URL');
  static String get supabaseAnonKey => getRequired('SUPABASE_ANON_KEY');

  // App Configuration
  static String get appName => get('APP_NAME', defaultValue: 'OpenSpot');
  static String get environmentName => get('ENVIRONMENT', defaultValue: 'development');

  // AI Services
  static String get openAiApiKey => get('OPENAI_API_KEY');
  static String get geminiApiKey => get('GEMINI_API_KEY');

  // Feature Flags
  static bool get enableDebugLogging => getBool('ENABLE_DEBUG_LOGGING', defaultValue: false);
  static bool get enableAnalytics => getBool('ENABLE_ANALYTICS', defaultValue: false);
  static bool get enableCrashReporting => getBool('ENABLE_CRASH_REPORTING', defaultValue: false);

  /// Print current configuration (for debugging)
  static void printConfig() {
    print('═══════════════════════════════════════');
    print('🚀 OpenSpot Environment Configuration');
    print('═══════════════════════════════════════');
    print('Environment: ${environmentName.toUpperCase()}');
    print('App Name: $appName');
    print('Supabase URL: $supabaseUrl');
    print('Debug Logging: $enableDebugLogging');
    print('Analytics: $enableAnalytics');
    print('Crash Reporting: $enableCrashReporting');
    print('═══════════════════════════════════════');
  }
}
