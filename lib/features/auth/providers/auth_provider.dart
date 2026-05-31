import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── AUTH STATE STREAM ─────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session);
});

// ── CURRENT USER ──────────────────────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (session) => session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});

// ── CURRENT PROFILE (from DB with stats) ─────────────────────────────────────
final currentProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  
  try {
    // Try to use the new get_profile_with_stats function first
    final result = await Supabase.instance.client
        .rpc('get_profile_with_stats', params: {'user_id': user.id});
    
    if (result != null && result.isNotEmpty) {
      return result.first as Map<String, dynamic>;
    }
    
    // Fallback to regular profiles table
    return await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  } catch (e) {
    // If function doesn't exist, fallback to regular query
    return await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }
});

// ── AUTH NOTIFIER ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  final _client = Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _googleRedirectUrl(),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Returns the correct redirect URL depending on platform
  String _googleRedirectUrl() {
    // On web, Supabase handles the redirect automatically via the site URL
    // On mobile, we provide the custom scheme defined in our app config
    if (kIsWeb) return ''; 
    return 'com.openspot.app://login-callback';
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.openspot.app://reset-password',
    );
  }

  /// Update profile in the `profiles` table
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').upsert({'id': user.id, ...data});
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);
