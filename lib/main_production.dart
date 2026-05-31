import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment_config.dart';
import 'core/config/feature_flags.dart';
import 'core/config/sentry_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Production environment entry point
/// Build with: flutter build apk -t lib/main_production.dart --release
/// Build iOS: flutter build ios -t lib/main_production.dart --release
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Initialize PRODUCTION environment
  await EnvironmentConfig.initialize(environment: Environment.production);

  // Only print config in debug mode (won't show in release builds)
  assert(() {
    EnvironmentConfig.printConfig();
    return true;
  }());

  // Initialize Sentry for crash reporting
  await SentryConfig.initialize();

  await Supabase.initialize(
    url: EnvironmentConfig.supabaseUrl,
    anonKey: EnvironmentConfig.supabaseAnonKey,
    debug: false, // Never debug in production
  );

  // Initialize feature flags
  await FeatureFlags.initialize();
  await AppConfig.initialize();

  // Run app with Sentry error handling
  await SentryFlutter.init(
    (options) {
      options.dsn = ''; // Will be set in SentryConfig
    },
    appRunner: () => runApp(const ProviderScope(child: OpenSpotApp())),
  );
}

class OpenSpotApp extends ConsumerWidget {
  const OpenSpotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: EnvironmentConfig.appName,
      debugShowCheckedModeBanner: false, // Never show in production
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
