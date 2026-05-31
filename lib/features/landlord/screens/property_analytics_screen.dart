import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for property analytics
final propertyAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  
  try {
    // Get properties with detailed stats
    final properties = await Supabase.instance.client
        .from('properties')
        .select('id, title, price, views, likes, status, available, created_at, property_type, location')
        .eq('landlord_id', user.id)
        .order('views', ascending: false);
    
    // Get promotional videos stats
    final promoVideos = await Supabase.instance.client
        .from('free_promotional_videos')
        .select('property_id, impressions, views, likes, contacts')
        .eq('landlord_id', user.id);
    
    // Calculate analytics
    final totalProperties = properties.length;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + (p['views'] as int? ?? 0));
    final totalLikes = properties.fold<int>(0, (sum, p) => sum + (p['likes'] as int? ?? 0));
    final avgViewsPerProperty = totalProperties > 0 ? (totalViews / totalProperties).round() : 0;
    
    // Top performing properties
    final topProperties = properties.take(5).toList();
    
    // Property type breakdown
    final typeBreakdown = <String, int>{};
    for (final property in properties) {
      final type = property['property_type'] as String? ?? 'Unknown';
      typeBreakdown[type] = (typeBreakdown[type] ?? 0) + 1;
    }
    
    return {
      'totalProperties': totalProperties,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'avgViewsPerProperty': avgViewsPerProperty,
      'topProperties': topProperties,
      'typeBreakdown': typeBreakdown,
      'promoVideos': promoVideos,
    };
  } catch (e) {
    return {};
  }
});

class PropertyAnalyticsScreen extends ConsumerWidget {
  const PropertyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(propertyAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(propertyAnalyticsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(propertyAnalyticsProvider);
        },
        child: analytics.when(
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
                  onPressed: () => ref.invalidate(propertyAnalyticsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Stats
                _buildOverviewSection(data),
                const SizedBox(height: 24),

                // Top Performing Properties
                _buildTopPropertiesSection(data),
                const SizedBox(height: 24),

                // Property Type Breakdown
                _buildTypeBreakdownSection(data),
                const SizedBox(height: 24),

                // Performance Tips
                _buildTipsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> data) {
    final totalProperties = data['totalProperties'] as int? ?? 0;
    final totalViews = data['totalViews'] as int? ?? 0;
    final totalLikes = data['totalLikes'] as int? ?? 0;
    final avgViewsPerProperty = data['avgViewsPerProperty'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Properties',
                totalProperties.toString(),
                Icons.home_work,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Views',
                _formatNumber(totalViews),
                Icons.visibility,
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
                'Total Likes',
                _formatNumber(totalLikes),
                Icons.favorite,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Views/Property',
                avgViewsPerProperty.toString(),
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPropertiesSection(Map<String, dynamic> data) {
    final topProperties = data['topProperties'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Performing Properties',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (topProperties.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.analytics,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
                SizedBox(height: 16),
                Text(
                  'No properties to analyze yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add some properties to see analytics',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: topProperties.asMap().entries.map((entry) {
              final index = entry.key;
              final property = entry.value;
              return _buildPropertyCard(property, index + 1);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property, int rank) {
    final title = property['title'] as String? ?? 'Property';
    final price = property['price'] as int? ?? 0;
    final views = property['views'] as int? ?? 0;
    final likes = property['likes'] as int? ?? 0;
    final location = property['location'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber.shade100 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.amber.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${_formatNumber(price)}/month',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(views),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(likes),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBreakdownSection(Map<String, dynamic> data) {
    final typeBreakdown = data['typeBreakdown'] as Map<String, int>? ?? {};

    if (typeBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property Types',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: typeBreakdown.entries.map((entry) {
              final type = entry.key;
              final count = entry.value;
              final total = typeBreakdown.values.fold<int>(0, (sum, v) => sum + v);
              final percentage = total > 0 ? ((count / total) * 100).round() : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '$count ($percentage%)',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Tips',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              _buildTip(
                Icons.video_library,
                'Add promotional videos',
                'Properties with videos get 3x more views',
              ),
              const SizedBox(height: 12),
              _buildTip(
                Icons.photo_camera,
                'Upload quality photos',
                'High-quality images increase engagement by 40%',
              ),
              const SizedBox(height: 12),
              _buildTip(
                Icons.description,
                'Write detailed descriptions',
                'Complete descriptions help students find your property',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
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
            title,
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