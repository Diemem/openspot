import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for user's saved searches
final savedSearchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('saved_searches')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return response as List<Map<String, dynamic>>;
  } catch (e) {
    throw Exception('Failed to load saved searches: $e');
  }
});

// Provider for saved searches count
final savedSearchesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from('saved_searches')
        .select('id')
        .eq('user_id', user.id);

    return response.length;
  } catch (e) {
    return 0;
  }
});

// Notifier for managing saved searches
class SavedSearchesNotifier extends StateNotifier<AsyncValue<void>> {
  SavedSearchesNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> saveSearch({
    required String name,
    required Map<String, dynamic> filters,
    bool enableNotifications = true,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('Must be signed in to save searches');
    }

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client.from('saved_searches').insert({
        'user_id': user.id,
        'name': name,
        'filters': filters,
        'notifications_enabled': enableNotifications,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Invalidate related providers
      ref.invalidate(savedSearchesProvider);
      ref.invalidate(savedSearchesCountProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? filters,
    bool? enableNotifications,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (filters != null) updates['filters'] = filters;
      if (enableNotifications != null) updates['notifications_enabled'] = enableNotifications;

      await Supabase.instance.client
          .from('saved_searches')
          .update(updates)
          .eq('id', searchId)
          .eq('user_id', user.id);

      // Invalidate related providers
      ref.invalidate(savedSearchesProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteSearch(String searchId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client
          .from('saved_searches')
          .delete()
          .eq('id', searchId)
          .eq('user_id', user.id);

      // Invalidate related providers
      ref.invalidate(savedSearchesProvider);
      ref.invalidate(savedSearchesCountProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> toggleNotifications(String searchId, bool enabled) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client
          .from('saved_searches')
          .update({
            'notifications_enabled': enabled,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', searchId)
          .eq('user_id', user.id);

      // Invalidate related providers
      ref.invalidate(savedSearchesProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final savedSearchesNotifierProvider = StateNotifierProvider<SavedSearchesNotifier, AsyncValue<void>>((ref) {
  return SavedSearchesNotifier(ref);
});