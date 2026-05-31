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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make status bar transparent with dark icons (black time/battery on white bg)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Initialize environment configuration
  await EnvironmentConfig.initialize(
    environment: Environment.development,
  );

  // Print configuration in debug mode
  if (EnvironmentConfig.enableDebugLogging) {
    EnvironmentConfig.printConfig();
  }

  // Initialize Sentry for crash reporting
  await SentryConfig.initialize();

  // Initialize Supabase with environment-specific configuration
  await Supabase.initialize(
    url: EnvironmentConfig.supabaseUrl,
    anonKey: EnvironmentConfig.supabaseAnonKey,
    debug: EnvironmentConfig.enableDebugLogging,
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
      debugShowCheckedModeBanner: !EnvironmentConfig.isProduction,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}