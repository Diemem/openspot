import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notifications_provider.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _tab = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const _NotSignedIn(),
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── STICKY HEADER ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
                        onPressed: () => context.go('/'),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.notifications_outlined, color: Color(0xFF4F46E5), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            notificationsAsync.when(
                              data: (notifications) => unreadCountAsync.when(
                                data: (unreadCount) => Text(
                                  '${notifications.length} total • $unreadCount unread',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                loading: () => const Text(
                                  'Loading...',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                error: (_, __) => const Text(
                                  'Error loading count',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                              ),
                              loading: () => const Text(
                                'Loading...',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                              error: (_, __) => const Text(
                                'Error loading notifications',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Color(0xFF374151)),
                        onPressed: () => context.go('/account'),
                      ),
                    ]),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Search notifications...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        if (_search.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          ),
                      ]),
                    ),
                  ),
                  // Action bar
                  notificationsAsync.when(
                    data: (notifications) => unreadCountAsync.when(
                      data: (unreadCount) => notifications.isNotEmpty
                          ? Container(
                              color: const Color(0xFFF9FAFB),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: unreadCount > 0
                                        ? () async {
                                            try {
                                              await ref.read(notificationsNotifierProvider.notifier).markAllAsRead();
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e')),
                                                );
                                              }
                                            }
                                          }
                                        : null,
                                    child: Row(children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: unreadCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Mark all as read',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: unreadCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  Row(children: const [
                                    Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7280)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Real-time notifications',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                                    ),
                                  ]),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),

          // ── LIST ───────────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationsCountProvider);
              },
              child: notificationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: 'Failed to load notifications',
                  onRetry: () {
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationsCountProvider);
                  },
                ),
                data: (notifications) {
                  final filtered = _filterNotifications(notifications);
                  
                  if (filtered.isEmpty) {
                    return _EmptyState(search: _search, onClear: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    });
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _NotificationCard(
                      notification: filtered[i],
                      onTap: () => _handleNotificationTap(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterNotifications(List<Map<String, dynamic>> notifications) {
    return notifications.where((notification) {
      final title = notification['title'] as String? ?? '';
      final message = notification['message'] as String? ?? '';
      final type = notification['type'] as String? ?? '';
      final isRead = notification['is_read'] as bool? ?? false;

      // Tab filter
      bool tabMatch = true;
      if (_tab == 'unread') {
        tabMatch = !isRead;
      } else if (_tab != 'all') {
        tabMatch = type == _tab;
      }

      // Search filter
      bool searchMatch = _search.isEmpty ||
          title.toLowerCase().contains(_search.toLowerCase()) ||
          message.toLowerCase().contains(_search.toLowerCase());

      return tabMatch && searchMatch;
    }).toList();
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final notificationId = notification['id'] as String;
    final type = notification['type'] as String? ?? '';
    final isRead = notification['is_read'] as bool? ?? false;

    // Mark as read if not already read
    if (!isRead) {
      try {
        await ref.read(notificationsNotifierProvider.notifier).markAsRead(notificationId);
      } catch (e) {
        // Silently fail - not critical
      }
    }

    // Navigate based on type
    if (mounted) {
      switch (type) {
        case 'new_message':
          context.go('/messages');
          break;
        case 'property_match':
        case 'price_drop':
          context.go('/');
          break;
        case 'system':
          context.go('/account');
          break;
        default:
          context.go('/');
      }
    }
  }
}

class _NotificationCard extends ConsumerWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  static const _iconData = {
    'general': Icons.notifications_outlined,
    'property_match': Icons.home_outlined,
    'price_drop': Icons.trending_down,
    'new_message': Icons.message_outlined,
    'system': Icons.info_outline,
  };

  static const _colors = {
    'general': Color(0xFF3B82F6),
    'property_match': Color(0xFF10B981),
    'price_drop': Color(0xFFEF4444),
    'new_message': Color(0xFF7C3AED),
    'system': Color(0xFFF97316),
  };

  static const _bgColors = {
    'general': Color(0xFFEFF6FF),
    'property_match': Color(0xFFF0FDF4),
    'price_drop': Color(0xFFFEF2F2),
    'new_message': Color(0xFFF5F3FF),
    'system': Color(0xFFFFF7ED),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final type = notification['type'] as String? ?? 'general';
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt = DateTime.tryParse(notification['created_at'] as String? ?? '');
    final notificationId = notification['id'] as String;

    final color = _colors[type] ?? const Color(0xFF3B82F6);
    final bg = _bgColors[type] ?? const Color(0xFFEFF6FF);
    final icon = _iconData[type] ?? Icons.notifications_outlined;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFF3F4F6) : const Color(0xFFC7D2FE),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ]),
                      Row(children: [
                        if (!isRead)
                          GestureDetector(
                            onTap: () async {
                              try {
                                await ref.read(notificationsNotifierProvider.notifier)
                                    .markAsRead(notificationId);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Mark read',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await ref.read(notificationsNotifierProvider.notifier)
                                  .deleteNotification(notificationId);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Sign in to view notifications',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/signin'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String search;
  final VoidCallback onClear;

  const _EmptyState({
    required this.search,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.notifications_outlined, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Center(
          child: Text(
            search.isNotEmpty ? 'No notifications found' : 'No notifications yet',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            search.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'You\'ll see notifications here when you have activity',
            style: const TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
        if (search.isNotEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: onClear,
              child: const Text('Clear Search'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}