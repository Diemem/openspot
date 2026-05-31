import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'environment_config.dart';

/// Sentry configuration for crash reporting and error tracking
class SentryConfig {
  static const String _dsn = 'YOUR_SENTRY_DSN_HERE'; // Add your Sentry DSN

  /// Initialize Sentry
  static Future<void> initialize() async {
    // Only initialize in staging and production
    if (EnvironmentConfig.isDevelopment) {
      print('⚠️ Sentry disabled in development environment');
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = EnvironmentConfig.environmentName;
        options.release = 'openspot@1.0.0+1'; // Update with actual version
        
        // Set sample rates
        options.tracesSampleRate = EnvironmentConfig.isProduction ? 0.2 : 1.0;
        options.profilesSampleRate = EnvironmentConfig.isProduction ? 0.2 : 1.0;
        
        // Enable automatic breadcrumbs
        options.enableAutoSessionTracking = true;
        options.sessionTrackingIntervalMillis = 30000;
        
        // Attach stack traces
        options.attachStacktrace = true;
        options.attachThreads = true;
        
        // Debug options
        options.debug = EnvironmentConfig.enableDebugLogging;
        
        // Filter sensitive data
        options.beforeSend = (event, hint) {
          // Don't send events in development
          if (EnvironmentConfig.isDevelopment) {
            return null;
          }
          
          // Filter out sensitive information
          if (event.request?.data != null) {
            // Remove passwords, tokens, etc.
            final data = event.request!.data as Map<String, dynamic>?;
            data?.remove('password');
            data?.remove('token');
            data?.remove('api_key');
          }
          
          return event;
        };
      },
    );

    print('✅ Sentry initialized for ${EnvironmentConfig.environmentName}');
  }

  /// Capture exception manually
  static Future<void> captureException(
    dynamic exception,
    StackTrace? stackTrace, {
    String? hint,
    Map<String, dynamic>? extra,
  }) async {
    if (EnvironmentConfig.isDevelopment) {
      print('Exception (not sent to Sentry in dev): $exception');
      return;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: hint,
      withScope: (scope) {
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
      },
    );
  }

  /// Capture message
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
  }) async {
    if (EnvironmentConfig.isDevelopment) {
      print('Message (not sent to Sentry in dev): $message');
      return;
    }

    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
      },
    );
  }

  /// Set user context
  static void setUser({
    required String id,
    String? email,
    String? username,
    Map<String, dynamic>? extra,
  }) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: extra,
      ));
    });
  }

  /// Clear user context (on logout)
  static void clearUser() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Add breadcrumb
  static void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: data,
      timestamp: DateTime.now(),
    ));
  }

  /// Start transaction for performance monitoring
  static ISentrySpan startTransaction(
    String operation,
    String description,
  ) {
    return Sentry.startTransaction(
      operation,
      description,
      bindToScope: true,
    );
  }
}
