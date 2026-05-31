import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/property_card.dart';
import '../providers/history_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ViewingHistoryScreen extends ConsumerWidget {
  const ViewingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viewing History')),
        body: const _NotSignedIn(),
      );
    }

    final historyAsync = ref.watch(viewingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewing History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Viewing History'),
                  content: const Text(
                    'We track the properties you view to help you find them again later. '
                    'Only properties viewed while signed in are saved.',
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
          ref.invalidate(viewingHistoryProvider);
        },
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: 'Failed to load viewing history',
            onRetry: () {
              ref.invalidate(viewingHistoryProvider);
            },
          ),
          data: (properties) {
            if (properties.isEmpty) {
              return const _EmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                final viewedAt = DateTime.parse(property['viewed_at'] as String);
                
                return Column(
                  children: [
                    if (index == 0 || _shouldShowDateHeader(properties, index))
                      _buildDateHeader(viewedAt),
                    
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: PropertyCard(
                        property: property,
                        width: double.infinity,
                        showViewedTime: true,
                        viewedAt: viewedAt,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _shouldShowDateHeader(List<Map<String, dynamic>> properties, int index) {
    if (index == 0) return true;
    
    final currentDate = DateTime.parse(properties[index]['viewed_at'] as String);
    final previousDate = DateTime.parse(properties[index - 1]['viewed_at'] as String);
    
    return currentDate.day != previousDate.day ||
           currentDate.month != previousDate.month ||
           currentDate.year != previousDate.year;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String headerText;
    if (dateOnly == today) {
      headerText = 'Today';
    } else if (dateOnly == yesterday) {
      headerText = 'Yesterday';
    } else {
      headerText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        headerText,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
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
          const Icon(Icons.history, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Sign in to track viewing history',
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
        const Icon(Icons.history, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No viewing history yet',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Properties you view will appear here',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Browse Properties'),
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