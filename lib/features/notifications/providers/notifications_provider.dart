import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for user notifications
final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);

    return response as List<Map<String, dynamic>>;
  } catch (e) {
    throw Exception('Failed to load notifications: $e');
  }
});

// Provider for unread notifications count
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);

    return response.length;
  } catch (e) {
    return 0;
  }
});

// Notifier for managing notifications
class NotificationsNotifier extends StateNotifier<AsyncValue<void>> {
  NotificationsNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> markAsRead(String notificationId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', user.id);

      // Invalidate related providers
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('is_read', false);

      // Invalidate related providers
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();

    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', user.id);

      // Invalidate related providers
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final notificationsNotifierProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<void>>((ref) {
  return NotificationsNotifier(ref);
});

// Function to create a notification
Future<void> createNotification({
  required String userId,
  required String title,
  required String message,
  String? type,
  Map<String, dynamic>? data,
}) async {
  try {
    await Supabase.instance.client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type ?? 'general',
      'data': data,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    // Silently fail - notifications are not critical
    print('Failed to create notification: $e');
  }
}