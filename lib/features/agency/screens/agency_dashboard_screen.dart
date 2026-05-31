import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider for agency stats
final agencyStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Agency Stats Error: Not authenticated');
      throw Exception('Not authenticated');
    }

    debugPrint('Fetching agency stats for user: $userId');

    // Get agency info
    final agency = await SupabaseService.client
        .from('agencies')
        .select('*')
        .eq('owner_id', userId)
        .maybeSingle();

    debugPrint('Agency query result: $agency');

    if (agency == null) {
      debugPrint('No agency found for user, showing setup screen');
      return {
        'hasAgency': false,
      };
    }

    final agencyId = agency['id'];
    debugPrint('Agency ID: $agencyId');

    // Get clients count
    final clientsResponse = await SupabaseService.client
        .from('agency_clients')
        .select('id')
        .eq('agency_id', agencyId)
        .eq('status', 'active');

    debugPrint('Clients count: ${clientsResponse.length}');

    // Get staff count
    final staffResponse = await SupabaseService.client
        .from('agency_staff')
        .select('id')
        .eq('agency_id', agencyId)
        .eq('status', 'active');

    debugPrint('Staff count: ${staffResponse.length}');

    // Get properties managed
    final propertiesResponse = await SupabaseService.client
        .from('properties')
        .select('id, status, views, likes')
        .eq('managed_by_agency_id', agencyId);

    final properties = List<Map<String, dynamic>>.from(propertiesResponse);
    final totalProperties = properties.length;
    final activeProperties = properties.where((p) => p['status'] == 'active').length;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + (p['views'] as int? ?? 0));
    final totalLikes = properties.fold<int>(0, (sum, p) => sum + (p['likes'] as int? ?? 0));

    debugPrint('Properties count: $totalProperties');

    return {
      'hasAgency': true,
      'agency': agency,
      'totalClients': clientsResponse.length,
      'totalStaff': staffResponse.length,
      'totalProperties': totalProperties,
      'activeProperties': activeProperties,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'recentProperties': properties.take(5).toList(),
    };
  } catch (e, stackTrace) {
    debugPrint('Agency Stats Error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
});

class AgencyDashboardScreen extends ConsumerWidget {
  const AgencyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(agencyStatsProvider);

    return Scaffold(
      body: stats.when(
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
                onPressed: () => ref.invalidate(agencyStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (statsData) {
          if (statsData['hasAgency'] == false) {
            return _SetupAgencyScreen();
          }
          return _AgencyDashboardContent(stats: statsData);
        },
      ),
    );
  }
}

// =====================================================
// SETUP AGENCY SCREEN
// =====================================================

class _SetupAgencyScreen extends StatefulWidget {
  @override
  State<_SetupAgencyScreen> createState() => _SetupAgencyScreenState();
}

class _SetupAgencyScreenState extends State<_SetupAgencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _createAgency() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await SupabaseService.client.from('agencies').insert({
        'owner_id': userId,
        'agency_name': _nameController.text.trim(),
        'agency_license': _licenseController.text.trim(),
        'agency_phone': _phoneController.text.trim(),
        'agency_email': _emailController.text.trim(),
        'agency_address': _addressController.text.trim(),
      });

      // Update profile role
      await SupabaseService.client
          .from('profiles')
          .update({'sub_role': 'agency'})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agency created successfully!')),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Agency'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.business,
                size: 64,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Create Your Agency',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage properties for multiple landlords and grow your real estate business',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Agency Name *',
                  hintText: 'e.g., Prime Properties Ltd',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter agency name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Agency Phone *',
                  hintText: '+254...',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Agency Email *',
                  hintText: 'info@agency.com',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Office Address',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAgency,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Agency'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// AGENCY DASHBOARD CONTENT
// =====================================================

class _AgencyDashboardContent extends ConsumerWidget {
  final Map<String, dynamic> stats;

  const _AgencyDashboardContent({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = stats['agency'] as Map<String, dynamic>;
    final agencyName = agency['agency_name'] as String;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(agencyStatsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/agency-settings'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.business,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          agencyName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'AGENCY',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats Overview
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                          'Clients',
                          stats['totalClients'].toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Properties',
                          stats['totalProperties'].toString(),
                          Icons.home_work,
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
                          'Staff',
                          stats['totalStaff'].toString(),
                          Icons.badge,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Total Views',
                          _formatNumber(stats['totalViews']),
                          Icons.visibility,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildListDelegate([
                _buildActionCard(
                  'Manage Clients',
                  Icons.people,
                  Colors.blue,
                  () => context.push('/agency-clients'),
                ),
                _buildActionCard(
                  'Manage Staff',
                  Icons.badge,
                  Colors.purple,
                  () => context.push('/agency-staff'),
                ),
                _buildActionCard(
                  'Properties',
                  Icons.home_work,
                  Colors.green,
                  () => context.push('/agency-properties'),
                ),
                _buildActionCard(
                  'Analytics',
                  Icons.analytics,
                  Colors.orange,
                  () => context.push('/agency-analytics'),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
            label,
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

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
