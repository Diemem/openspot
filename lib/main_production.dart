import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment_config.dart';
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

  await Supabase.initialize(
    url: EnvironmentConfig.supabaseUrl,
    anonKey: EnvironmentConfig.supabaseAnonKey,
    debug: false, // Never debug in production
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
      debugShowCheckedModeBanner: false, // Never show in production
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
