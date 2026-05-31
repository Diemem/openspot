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
  
  try {
    // Get landlord properties and stats
    final properties = await Supabase.instance.client
        .from('properties')
        .select('id, title, price, views, likes, status, available, created_at')
        .eq('landlord_id', user.id);
    
    // Get promotional videos stats
    final promoVideos = await Supabase.instance.client
        .from('free_promotional_videos')
        .select('id, impressions, views, likes, contacts, status')
        .eq('landlord_id', user.id);
    
    // Calculate totals
    final totalProperties = properties.length;
    final activeProperties = properties.where((p) => p['status'] == 'active').length;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + (p['views'] as int? ?? 0));
    final totalLikes = properties.fold<int>(0, (sum, p) => sum + (p['likes'] as int? ?? 0));
    
    final totalPromoViews = promoVideos.fold<int>(0, (sum, v) => sum + (v['views'] as int? ?? 0));
    final totalPromoImpressions = promoVideos.fold<int>(0, (sum, v) => sum + (v['impressions'] as int? ?? 0));
    final totalContacts = promoVideos.fold<int>(0, (sum, v) => sum + (v['contacts'] as int? ?? 0));
    
    return {
      'totalProperties': totalProperties,
      'activeProperties': activeProperties,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalPromoViews': totalPromoViews,
      'totalPromoImpressions': totalPromoImpressions,
      'totalContacts': totalContacts,
      'recentProperties': properties.take(3).toList(),
      'promoVideos': promoVideos,
    };
  } catch (e) {
    return {};
  }
});

class LandlordDashboardScreen extends ConsumerWidget {
  const LandlordDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider);
    final stats = ref.watch(landlordStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-property'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(landlordStatsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(landlordStatsProvider);
        },
        child: profile.when(
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
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (profileData) {
            if (profileData == null) {
              return const Center(child: Text('Profile not found'));
            }

            return stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Stats Error: $error')),
              data: (statsData) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeCard(context, profileData, statsData),
                    const SizedBox(height: 24),

                    // Quick Stats
                    _buildStatsSection(statsData),
                    const SizedBox(height: 24),

                    // Promotional Videos Section
                    _buildPromoVideosSection(context, statsData),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(context),
                    const SizedBox(height: 24),

                    // Recent Properties
                    _buildRecentProperties(context, statsData),
                    const SizedBox(height: 24),

                    // Performance Insights
                    _buildPerformanceInsights(statsData),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, Map<String, dynamic> profile, Map<String, dynamic> stats) {
    final name = profile['full_name'] as String? ?? 'Landlord';
    final totalProperties = stats['totalProperties'] as int? ?? 0;
    final activeProperties = stats['activeProperties'] as int? ?? 0;
    final isVerified = profile['phone_verified'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome back, ${name.split(' ').first}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalProperties == 0
                ? 'Ready to list your first property?'
                : 'You have $activeProperties active properties out of $totalProperties total',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          if (!isVerified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Verify your phone to unlock all features',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/profile-completion'),
                    child: const Text(
                      'Verify',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats) {
    final totalProperties = stats['totalProperties'] as int? ?? 0;
    final totalViews = stats['totalViews'] as int? ?? 0;
    final totalContacts = stats['totalContacts'] as int? ?? 0;
    final totalLikes = stats['totalLikes'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _buildStatCard(
                'Properties',
                totalProperties.toString(),
                Icons.home_work,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _buildStatCard(
                'Inquiries',
                totalContacts.toString(),
                Icons.message,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Likes',
                _formatNumber(totalLikes),
                Icons.favorite,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildPromoVideosSection(BuildContext context, Map<String, dynamic> stats) {
    final promoVideos = stats['promoVideos'] as List? ?? [];
    final totalPromoViews = stats['totalPromoViews'] as int? ?? 0;
    final totalPromoImpressions = stats['totalPromoImpressions'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Promotional Videos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/promotional-videos'),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _buildStatCard(
                'Video Views',
                _formatNumber(totalPromoViews),
                Icons.play_circle,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Impressions',
                _formatNumber(totalPromoImpressions),
                Icons.visibility,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (promoVideos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.video_library, size: 48, color: Colors.blue.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Get FREE promotional videos!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload 1-2 videos per property and get 7 days of free promotion in our Explore feed',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/add-promotional-video'),
                  child: const Text('Add Video'),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You have ${promoVideos.length} promotional video${promoVideos.length == 1 ? '' : 's'} active',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
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
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Add Property',
              Icons.add_home,
              Colors.blue,
              () => context.push('/add-property'),
            ),
            _buildActionCard(
              'Add Promo Video',
              Icons.video_call,
              Colors.purple,
              () => context.push('/add-promotional-video'),
            ),
            _buildActionCard(
              'Manage Caretakers',
              Icons.people,
              Colors.teal,
              () => context.push('/manage-caretakers'),
            ),
            _buildActionCard(
              'View Analytics',
              Icons.analytics,
              Colors.green,
              () => context.push('/property-analytics'),
            ),
            _buildActionCard(
              'Messages',
              Icons.message,
              Colors.orange,
              () => context.push('/messages'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProperties(BuildContext context, Map<String, dynamic> stats) {
    final recentProperties = stats['recentProperties'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Properties',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/manage-properties'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentProperties.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No properties yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start by adding your first property listing',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/add-property'),
                  child: const Text('Add Property'),
                ),
              ],
            ),
          )
        else
          Column(
            children: recentProperties.map((property) {
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.home, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property['title'] as String? ?? 'Property',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KES ${property['price'] ?? 0}/month',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${property['views'] ?? 0} views',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.favorite, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${property['likes'] ?? 0} likes',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: property['status'] == 'active' 
                            ? Colors.green.shade100 
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        property['status'] as String? ?? 'unknown',
                        style: TextStyle(
                          color: property['status'] == 'active' 
                              ? Colors.green.shade800 
                              : Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        final propertyId = property['id'] as String;
                        switch (value) {
                          case 'promote_7':
                            context.push('/payment/$propertyId/featured_7_days');
                            break;
                          case 'promote_30':
                            context.push('/payment/$propertyId/featured_30_days');
                            break;
                          case 'edit':
                            // TODO: Navigate to edit property
                            break;
                          case 'view':
                            context.push('/property/$propertyId');
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 16),
                              SizedBox(width: 8),
                              Text('View Property'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit Property'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'promote_7',
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Promote 7 Days (KES 500)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'promote_30',
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Promote 30 Days (KES 1,500)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPerformanceInsights(Map<String, dynamic> stats) {
    final totalProperties = stats['totalProperties'] as int? ?? 0;
    final totalViews = stats['totalViews'] as int? ?? 0;
    final totalLikes = stats['totalLikes'] as int? ?? 0;

    if (totalProperties == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Insights',
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
            child: const Column(
              children: [
                Icon(
                  Icons.insights,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
                SizedBox(height: 16),
                Text(
                  'Insights coming soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'We\'ll show you detailed analytics once you have active properties',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Calculate performance metrics
    final avgViewsPerProperty = totalProperties > 0 ? (totalViews / totalProperties).round() : 0;
    final avgLikesPerProperty = totalProperties > 0 ? (totalLikes / totalProperties).round() : 0;
    final engagementRate = totalViews > 0 ? ((totalLikes / totalViews) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Insights',
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
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      'Avg Views/Property',
                      avgViewsPerProperty.toString(),
                      Icons.trending_up,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      'Engagement Rate',
                      '$engagementRate%',
                      Icons.favorite,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tip: Properties with videos get 3x more views!',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}