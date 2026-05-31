import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/saved_searches_provider.dart';
import '../widgets/search_filter_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Searches')),
        body: const _NotSignedIn(),
      );
    }

    final savedSearchesAsync = ref.watch(savedSearchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Searches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Saved Searches'),
                  content: const Text(
                    'Save your search criteria and get notified when new properties match your preferences. '
                    'You can enable or disable notifications for each saved search.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedSearchesProvider);
        },
        child: savedSearchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: 'Failed to load saved searches',
            onRetry: () {
              ref.invalidate(savedSearchesProvider);
            },
          ),
          data: (searches) {
            if (searches.isEmpty) {
              return const _EmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: searches.length,
              itemBuilder: (context, index) {
                final search = searches[index];
                return _SavedSearchCard(search: search);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show search filter dialog
          showDialog(
            context: context,
            builder: (context) => const SearchFilterDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Search'),
      ),
    );
  }
}

class _SavedSearchCard extends ConsumerWidget {
  final Map<String, dynamic> search;

  const _SavedSearchCard({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = search['name'] as String;
    final filters = search['filters'] as Map<String, dynamic>;
    final notificationsEnabled = search['notifications_enabled'] as bool? ?? false;
    final createdAt = DateTime.parse(search['created_at'] as String);
    final searchId = search['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditDialog(context, ref, search);
                        break;
                      case 'delete':
                        _showDeleteDialog(context, ref, searchId, name);
                        break;
                      case 'search':
                        // Execute the saved search by navigating to explore with filters
                        final filters = search['filters'] as Map<String, dynamic>;
                        final queryParams = <String, String>{};
                        
                        // Convert filters to query parameters
                        filters.forEach((key, value) {
                          if (value != null && value.toString().isNotEmpty) {
                            queryParams[key] = value.toString();
                          }
                        });
                        
                        // Navigate to explore screen with filters
                        final uri = Uri(path: '/explore', queryParameters: queryParams.isNotEmpty ? queryParams : null);
                        context.go(uri.toString());
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16),
                          SizedBox(width: 8),
                          Text('Search Now'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Search criteria
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _buildFilterChips(filters),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Created ${_formatDate(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                
                // Notifications toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      notificationsEnabled ? Icons.notifications : Icons.notifications_off,
                      size: 16,
                      color: notificationsEnabled ? AppTheme.primary : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notificationsEnabled ? 'Alerts ON' : 'Alerts OFF',
                      style: TextStyle(
                        fontSize: 12,
                        color: notificationsEnabled ? AppTheme.primary : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: notificationsEnabled,
                      onChanged: (value) async {
                        try {
                          await ref.read(savedSearchesNotifierProvider.notifier)
                              .toggleNotifications(searchId, value);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilterChips(Map<String, dynamic> filters) {
    final chips = <Widget>[];

    filters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        String label = '';
        switch (key) {
          case 'location':
            label = '📍 $value';
            break;
          case 'property_type':
            label = '🏠 $value';
            break;
          case 'min_price':
            label = '💰 From KES $value';
            break;
          case 'max_price':
            label = '💰 Up to KES $value';
            break;
          case 'bedrooms':
            label = '🛏️ ${value} bed${value > 1 ? 's' : ''}';
            break;
          case 'bathrooms':
            label = '🚿 ${value} bath${value > 1 ? 's' : ''}';
            break;
          default:
            label = '$key: $value';
        }

        chips.add(
          Chip(
            label: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
          ),
        );
      }
    });

    return chips.isEmpty 
        ? [const Chip(label: Text('All properties', style: TextStyle(fontSize: 12)))]
        : chips;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> search) {
    showDialog(
      context: context,
      builder: (context) => SearchFilterDialog(
        initialFilters: search['filters'] as Map<String, dynamic>? ?? {},
        savedSearchName: search['name'] as String,
        showSaveOption: false, // We'll handle update separately
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String searchId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Search'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(savedSearchesNotifierProvider.notifier)
                    .deleteSearch(searchId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
          const Icon(Icons.search, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Sign in to save searches',
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.search, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No saved searches yet',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Save your search criteria to get notified of new properties',
            style: TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Start Searching'),
          ),
        ),
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