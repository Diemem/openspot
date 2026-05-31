import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for landlord stats
final landlordStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final result = await Supabase.instance.client
      .rpc('get_profile_with_stats', params: {'user_id': user.id});

  return result as Map<String, dynamic>;
});

// Provider for landlord properties
final landlordPropertiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final result = await Supabase.instance.client
      .from('properties')
      .select('*, free_promotional_videos(*)')
      .eq('landlord_id', user.id)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(result);
});

class LandlordDashboardScreen extends ConsumerWidget {
  const LandlordDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(landlordStatsProvider);
    final propertiesAsync = ref.watch(landlordPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(landlordStatsProvider);
          ref.invalidate(landlordPropertiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats Cards
            statsAsync.when(
              data: (stats) => _StatsSection(stats: stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            const _QuickActionsSection(),

            const SizedBox(height: 24),

            // Properties List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Properties',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/add-property'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Property'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            propertiesAsync.when(
              data: (properties) {
                if (properties.isEmpty) {
                  return _EmptyPropertiesCard();
                }
                return Column(
                  children: properties
                      .map((property) => _PropertyCard(property: property))
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-property'),
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4, // Controlled aspect ratio
      children: [
        _StatCard(
          icon: Icons.home_work,
          label: 'Properties',
          value: '${stats['total_properties'] ?? 0}',
          color: AppTheme.primary,
        ),
        _StatCard(
          icon: Icons.visibility,
          label: 'Total Views',
          value: '${stats['total_views'] ?? 0}',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.star,
          label: 'Rating',
          value: '${stats['rating'] ?? 0.0}',
          color: Colors.amber,
        ),
        _StatCard(
          icon: Icons.reviews,
          label: 'Reviews',
          value: '${stats['total_reviews'] ?? 0}',
          color: Colors.green,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 🔥 KEY FIX: Prevents unconstrained height
          children: [
            Icon(icon, color: color, size: 28), // Slightly smaller for better fit
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20, // Reduced from 24 for better fit
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3, // Controlled aspect ratio
          children: [
            _QuickActionCard(
              icon: Icons.add_home,
              label: 'Add Property',
              onTap: () => context.push('/add-property'),
            ),
            _QuickActionCard(
              icon: Icons.analytics,
              label: 'Analytics',
              onTap: () => context.push('/property-analytics'),
            ),
            _QuickActionCard(
              icon: Icons.video_library,
              label: 'Promo Videos',
              onTap: () => context.push('/promotional-videos'),
            ),
            _QuickActionCard(
              icon: Icons.verified,
              label: 'Get Verified',
              onTap: () => context.push('/verification'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🔥 KEY FIX: Prevents unconstrained height
            children: [
              Icon(icon, color: AppTheme.primary, size: 28), // Slightly smaller
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                maxLines: 2, // Allow 2 lines for longer labels
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final title = property['title'] as String? ?? 'Untitled';
    final price = property['price'] as num? ?? 0;
    final status = property['status'] as String? ?? 'draft';
    final views = property['views'] as num? ?? 0;
    final images = property['images'] as List? ?? [];
    final promoVideos = property['free_promotional_videos'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  images[0] as String,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.home),
              ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KES ${price.toStringAsFixed(0)}/month'),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusBadge(status: status),
                const SizedBox(width: 8),
                Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$views views', style: TextStyle(fontSize: 12)),
                if (promoVideos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.video_library, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text('${promoVideos.length} video(s)', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'analytics',
              child: Row(
                children: [
                  Icon(Icons.analytics, size: 18),
                  SizedBox(width: 8),
                  Text('Analytics'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: AppTheme.danger),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppTheme.danger)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            // TODO: Handle menu actions
          },
        ),
        onTap: () {
          // TODO: Navigate to property details
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'rented':
        color = Colors.orange;
        label = 'Rented';
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyPropertiesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No properties yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first property to start getting tenants',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-property'),
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
            ),
          ],
        ),
      ),
    );
  }
}
