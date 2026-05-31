import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Staging environment entry point
/// Run with: flutter run -t lib/main_staging.dart
/// Build with: flutter build apk -t lib/main_staging.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Initialize STAGING environment
  await EnvironmentConfig.initialize(environment: Environment.staging);
  EnvironmentConfig.printConfig();

  await Supabase.initialize(
    url: EnvironmentConfig.supabaseUrl,
    anonKey: EnvironmentConfig.supabaseAnonKey,
    debug: EnvironmentConfig.enableDebugLogging,
  );

  runApp(const ProviderScope(child: OpenSpotApp()));
}

class OpenSpotApp extends ConsumerWidget {
  const OpenSpotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: EnvironmentConfig.appName,
      debugShowCheckedModeBanner: true, // Show in staging for testing
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
