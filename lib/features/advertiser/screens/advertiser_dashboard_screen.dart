import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for advertiser promotional video stats
final advertiserStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  
  try {
    // Get promotional videos for this advertiser
    final promoVideos = await Supabase.instance.client
        .from('free_promotional_videos')
        .select('*, properties(title, price, location)')
        .eq('landlord_id', user.id)
        .order('created_at', ascending: false);
    
    // Calculate totals
    final totalVideos = promoVideos.length;
    final activeVideos = promoVideos.where((v) => v['status'] == 'approved' && 
        DateTime.parse(v['expires_at']).isAfter(DateTime.now())).length;
    final pendingVideos = promoVideos.where((v) => v['status'] == 'pending').length;
    final expiredVideos = promoVideos.where((v) => v['status'] == 'expired').length;
    
    final totalImpressions = promoVideos.fold<int>(0, (sum, v) => sum + (v['impressions'] as int? ?? 0));
    final totalViews = promoVideos.fold<int>(0, (sum, v) => sum + (v['views'] as int? ?? 0));
    final totalLikes = promoVideos.fold<int>(0, (sum, v) => sum + (v['likes'] as int? ?? 0));
    final totalContacts = promoVideos.fold<int>(0, (sum, v) => sum + (v['contacts'] as int? ?? 0));
    
    return {
      'totalVideos': totalVideos,
      'activeVideos': activeVideos,
      'pendingVideos': pendingVideos,
      'expiredVideos': expiredVideos,
      'totalImpressions': totalImpressions,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalContacts': totalContacts,
      'promoVideos': promoVideos,
    };
  } catch (e) {
    return {};
  }
});

class AdvertiserDashboardScreen extends ConsumerWidget {
  const AdvertiserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider);
    final stats = ref.watch(advertiserStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotional Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => context.push('/add-promotional-video'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(advertiserStatsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(advertiserStatsProvider);
        },
        child: stats.when(
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
                  onPressed: () => ref.invalidate(advertiserStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (statsData) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeaderCard(statsData),
                const SizedBox(height: 24),

                // Stats Overview
                _buildStatsSection(statsData),
                const SizedBox(height: 24),

                // Performance Metrics
                _buildPerformanceSection(statsData),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 24),

                // Video List
                _buildVideosList(context, statsData),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> stats) {
    final totalVideos = stats['totalVideos'] as int? ?? 0;
    final activeVideos = stats['activeVideos'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_library, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Promotional Videos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            totalVideos == 0
                ? 'Get started with FREE promotional videos!'
                : 'You have $activeVideos active videos out of $totalVideos total',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          if (totalVideos == 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload 1-2 videos per property and get 7 days of FREE promotion!',
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
    final totalVideos = stats['totalVideos'] as int? ?? 0;
    final activeVideos = stats['activeVideos'] as int? ?? 0;
    final pendingVideos = stats['pendingVideos'] as int? ?? 0;
    final expiredVideos = stats['expiredVideos'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Videos',
                totalVideos.toString(),
                Icons.video_library,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active',
                activeVideos.toString(),
                Icons.play_circle,
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
                'Pending',
                pendingVideos.toString(),
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Expired',
                expiredVideos.toString(),
                Icons.schedule,
                Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(Map<String, dynamic> stats) {
    final totalImpressions = stats['totalImpressions'] as int? ?? 0;
    final totalViews = stats['totalViews'] as int? ?? 0;
    final totalLikes = stats['totalLikes'] as int? ?? 0;
    final totalContacts = stats['totalContacts'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Impressions',
                _formatNumber(totalImpressions),
                Icons.visibility,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Views',
                _formatNumber(totalViews),
                Icons.play_arrow,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Likes',
                _formatNumber(totalLikes),
                Icons.favorite,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Contacts',
                _formatNumber(totalContacts),
                Icons.phone,
                Colors.indigo,
              ),
            ),
          ],
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
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Video',
                Icons.add_circle,
                Colors.blue,
                () => context.push('/add-promotional-video'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View Analytics',
                Icons.analytics,
                Colors.green,
                () => context.push('/video-analytics'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVideosList(BuildContext context, Map<String, dynamic> stats) {
    final promoVideos = stats['promoVideos'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Your Videos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (promoVideos.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/all-promotional-videos'),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (promoVideos.isEmpty)
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
                  Icons.video_call,
                  size: 64,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No promotional videos yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first promotional video to boost your property visibility',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/add-promotional-video'),
                  child: const Text('Create Video'),
                ),
              ],
            ),
          )
        else
          Column(
            children: promoVideos.take(5).map((video) {
              return _buildVideoCard(video);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final property = video['properties'] as Map<String, dynamic>?;
    final status = video['status'] as String? ?? 'unknown';
    final impressions = video['impressions'] as int? ?? 0;
    final views = video['views'] as int? ?? 0;
    final likes = video['likes'] as int? ?? 0;
    final contacts = video['contacts'] as int? ?? 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle, color: AppTheme.textMuted, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property?['title'] as String? ?? 'Property Video',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (property != null)
                      Text(
                        'KES ${property['price'] ?? 0}/month • ${property['location'] ?? 'Location'}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric(Icons.visibility, impressions.toString(), 'Impressions'),
              const SizedBox(width: 16),
              _buildMetric(Icons.play_arrow, views.toString(), 'Views'),
              const SizedBox(width: 16),
              _buildMetric(Icons.favorite, likes.toString(), 'Likes'),
              const SizedBox(width: 16),
              _buildMetric(Icons.phone, contacts.toString(), 'Contacts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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
}