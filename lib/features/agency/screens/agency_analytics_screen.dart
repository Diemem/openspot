import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider for agency analytics
final agencyAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  // Get agency ID
  final agency = await SupabaseService.client
      .from('agencies')
      .select('id')
      .eq('owner_id', userId)
      .single();

  final agencyId = agency['id'];

  // Get properties stats
  final properties = await SupabaseService.client
      .from('properties')
      .select('status, views, likes, price')
      .eq('managed_by_agency_id', agencyId);

  final propertiesList = List<Map<String, dynamic>>.from(properties);
  
  final totalProperties = propertiesList.length;
  final activeProperties = propertiesList.where((p) => p['status'] == 'active').length;
  final rentedProperties = propertiesList.where((p) => p['status'] == 'rented').length;
  final totalViews = propertiesList.fold<int>(0, (sum, p) => sum + (p['views'] as int? ?? 0));
  final totalLikes = propertiesList.fold<int>(0, (sum, p) => sum + (p['likes'] as int? ?? 0));
  final avgViews = totalProperties > 0 ? (totalViews / totalProperties).round() : 0;
  
  // Get clients count
  final clients = await SupabaseService.client
      .from('agency_clients')
      .select('id, status')
      .eq('agency_id', agencyId);
  
  final totalClients = clients.length;
  final activeClients = clients.where((c) => c['status'] == 'active').length;

  return {
    'totalProperties': totalProperties,
    'activeProperties': activeProperties,
    'rentedProperties': rentedProperties,
    'totalViews': totalViews,
    'totalLikes': totalLikes,
    'avgViews': avgViews,
    'totalClients': totalClients,
    'activeClients': activeClients,
  };
});

class AgencyAnalyticsScreen extends ConsumerWidget {
  const AgencyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(agencyAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(agencyAnalyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyAnalyticsProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Properties Stats
                  const Text(
                    'Properties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          stats['totalProperties'].toString(),
                          Icons.home_work,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          stats['activeProperties'].toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Rented',
                          stats['rentedProperties'].toString(),
                          Icons.key,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Views',
                          stats['avgViews'].toString(),
                          Icons.visibility,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Engagement Stats
                  const Text(
                    'Engagement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Views',
                          _formatNumber(stats['totalViews']),
                          Icons.visibility,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Total Likes',
                          _formatNumber(stats['totalLikes']),
                          Icons.favorite,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Clients Stats
                  const Text(
                    'Clients',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          stats['totalClients'].toString(),
                          Icons.people,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          stats['activeClients'].toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
