import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/update_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/account/screens/profile_completion_screen.dart';
import '../../features/account/screens/phone_verification_screen.dart';
import '../../features/property/screens/property_detail_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_window_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/landlord/screens/landlord_dashboard_screen.dart';
import '../../features/landlord/screens/property_analytics_screen.dart';
import '../../features/landlord/screens/add_property_screen.dart';
import '../../features/landlord/screens/manage_caretakers_screen.dart';
import '../../features/agency/screens/agency_dashboard_screen.dart';
import '../../features/agency/screens/agency_clients_screen.dart';
import '../../features/agency/screens/agency_staff_screen.dart';
import '../../features/agency/screens/agency_properties_screen.dart';
import '../../features/agency/screens/agency_analytics_screen.dart';
import '../../features/advertiser/screens/advertiser_dashboard_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/notifications/screens/notifications_detail_screen.dart';
import '../../features/payment/screens/payment_screen.dart';
import '../../features/history/screens/viewing_history_screen.dart';
import '../../features/search/screens/saved_searches_screen.dart';
import '../widgets/main_shell.dart';

/// Converts a Stream into a Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      
      final protectedRoutes = ['/account', '/messages', '/settings', '/landlord', '/favorites'];
      final isProtected = protectedRoutes.any((r) => state.matchedLocation.startsWith(r));
      
      if (isProtected && !isAuth) return '/signin';
      return null;
    },
    routes: [
      // Shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/explore', builder: (c, s) => const ExploreScreen()),
          GoRoute(path: '/map', builder: (c, s) => const MapScreen()),
          GoRoute(path: '/favorites', builder: (c, s) => const FavoritesScreen()),
          GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
          GoRoute(path: '/messages', builder: (c, s) => const ChatListScreen()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          GoRoute(path: '/landlord', builder: (c, s) => const LandlordDashboardScreen()),
          GoRoute(path: '/agency', builder: (c, s) => const AgencyDashboardScreen()),
          GoRoute(path: '/promotional-videos', builder: (c, s) => const AdvertiserDashboardScreen()),
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsDetailScreen()),
        ],
      ),
      // Full screen routes (no bottom nav)
      GoRoute(path: '/signin', builder: (c, s) => const AuthScreen()),
      GoRoute(path: '/reset-password', builder: (c, s) => const UpdatePasswordScreen()),
      GoRoute(path: '/profile-completion', builder: (c, s) => const ProfileCompletionScreen()),
      GoRoute(path: '/property-analytics', builder: (c, s) => const PropertyAnalyticsScreen()),
      GoRoute(path: '/add-property', builder: (c, s) => const AddPropertyScreen()),
      GoRoute(path: '/manage-caretakers', builder: (c, s) => const ManageCaretakersScreen()),
      GoRoute(path: '/agency-clients', builder: (c, s) => const AgencyClientsScreen()),
      GoRoute(path: '/agency-staff', builder: (c, s) => const AgencyStaffScreen()),
      GoRoute(path: '/agency-properties', builder: (c, s) => const AgencyPropertiesScreen()),
      GoRoute(path: '/agency-analytics', builder: (c, s) => const AgencyAnalyticsScreen()),
      GoRoute(path: '/agency-settings', builder: (c, s) => const Scaffold(body: Center(child: Text('Agency Settings - Coming Soon')))),
      GoRoute(path: '/add-promotional-video', builder: (c, s) => const AdvertiserDashboardScreen()),
      GoRoute(path: '/manage-properties', builder: (c, s) => const LandlordDashboardScreen()), // Temporary redirect
      GoRoute(path: '/viewing-history', builder: (c, s) => const ViewingHistoryScreen()),
      GoRoute(path: '/saved-searches', builder: (c, s) => const SavedSearchesScreen()),
      GoRoute(
        path: '/phone-verification/:phone',
        builder: (c, s) => PhoneVerificationScreen(
          phoneNumber: s.pathParameters['phone']!,
        ),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (c, s) => PropertyDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (c, s) => ChatWindowScreen(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payment/:propertyId/:packageType',
        builder: (c, s) => PaymentScreen(
          propertyId: s.pathParameters['propertyId']!,
          packageType: s.pathParameters['packageType']!,
        ),
      ),
    ],
  );
});
