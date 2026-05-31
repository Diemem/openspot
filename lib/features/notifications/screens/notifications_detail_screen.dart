import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'dart:convert';

// Provider for notifications
final notificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

// Provider for unread count
final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return Stream.value(0);

  return SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.where((item) => item['is_read'] == false).length);
});

class NotificationsDetailScreen extends ConsumerWidget {
  const NotificationsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAllAsRead(context),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (notificationsList) {
          if (notificationsList.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notificationsList.length,
              itemBuilder: (context, index) {
                final notification = notificationsList[index];
                return _buildNotificationCard(context, notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> notification) {
    final type = notification['type'] as String;
    final title = notification['title'] as String;
    final message = notification['message'] as String;
    final isRead = notification['is_read'] as bool;
    final actionType = notification['action_type'] as String?;
    final actionDataJson = notification['action_data'];
    final createdAt = DateTime.parse(notification['created_at'] as String);

    Map<String, dynamic>? actionData;
    if (actionDataJson != null) {
      actionData = actionDataJson is String 
          ? jsonDecode(actionDataJson) 
          : Map<String, dynamic>.from(actionDataJson);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue.shade50,
      child: InkWell(
        onTap: () => _handleNotificationTap(context, notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getNotificationIcon(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (actionType == 'accept_decline' && actionData != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _acceptInvitation(context, notification),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _declineInvitation(context, notification),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'caretaker_invitation':
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case 'caretaker_accepted':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'caretaker_declined':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'property_update':
        icon = Icons.home;
        color = Colors.orange;
        break;
      case 'inquiry_received':
        icon = Icons.question_answer;
        color = Colors.purple;
        break;
      case 'message_received':
        icon = Icons.message;
        color = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) async {
    // Mark as read
    await _markAsRead(notification['id']);
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('is_read', false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvitation(BuildContext context, Map<String, dynamic> notification) async {
    try {
      final actionDataJson = notification['action_data'];
      final actionData = actionDataJson is String 
          ? jsonDecode(actionDataJson) 
          : Map<String, dynamic>.from(actionDataJson);
      
      final caretakerId = actionData['caretaker_id'] as String;

      // Update caretaker status to accepted
      await SupabaseService.client
          .from('caretakers')
          .update({
            'status': 'active',
            'invitation_status': 'accepted',
          })
          .eq('id', caretakerId);

      // Mark notification as read
      await _markAsRead(notification['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted! You can now manage properties.')),
        );
        
        // Navigate to caretaker dashboard
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(BuildContext context, Map<String, dynamic> notification) async {
    try {
      final actionDataJson = notification['action_data'];
      final actionData = actionDataJson is String 
          ? jsonDecode(actionDataJson) 
          : Map<String, dynamic>.from(actionDataJson);
      
      final caretakerId = actionData['caretaker_id'] as String;

      // Update caretaker status to declined
      await SupabaseService.client
          .from('caretakers')
          .update({
            'status': 'declined',
            'invitation_status': 'declined',
          })
          .eq('id', caretakerId);

      // Mark notification as read
      await _markAsRead(notification['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
