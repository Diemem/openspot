import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Development environment entry point
/// Run with: flutter run -t lib/main_development.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Initialize DEVELOPMENT environment
  await EnvironmentConfig.initialize(environment: Environment.development);
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
      debugShowCheckedModeBanner: true, // Always show in development
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
