import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../landlord/screens/landlord_dashboard_screen.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../search/providers/saved_searches_provider.dart';
import '../widgets/role_switcher.dart';
import '../providers/role_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // ── NOT SIGNED IN (GUEST MODE) ─────────────────────────────────────
    if (user == null) {
      return const _GuestAccountScreen();
    }

    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading profile: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (profileData) {
        if (profileData == null) {
          return _NewUserScreen(user: user);
        }

        final role = profileData['role'] as String?;
        final isProfileComplete = profileData['profile_completed'] == true;

        if (!isProfileComplete) {
          return _ProfileIncompleteScreen(user: user, profile: profileData);
        }

        // Route to appropriate dashboard based on role
        if (role == 'landlord') {
          return _LandlordAccountScreen(user: user, profile: profileData);
        } else {
          return _RegularUserAccountScreen(user: user, profile: profileData);
        }
      },
    );
  }

  // Show role switcher bottom sheet
  static void showRoleSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _RoleSwitcherSheet(),
    );
  }
}

//
// ── GUEST ACCOUNT SCREEN (NOT SIGNED IN) ─────────────────────────────────────────────
//

class _GuestAccountScreen extends StatelessWidget {
  const _GuestAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Hero Section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.home,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Find Your Perfect Home',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse freely, no account needed!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Optional Features Preview
              const Text(
                'Sign in for convenience features:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                Icons.favorite,
                'Save Favorites',
                'Bookmark properties for later',
                Colors.red,
              ),
              const SizedBox(height: 12),
              
              _buildFeatureCard(
                Icons.notifications,
                'Get Alerts',
                'Notifications on new properties',
                Colors.orange,
              ),
              const SizedBox(height: 12),
              
              _buildFeatureCard(
                Icons.history,
                'Track History',
                'See what you\'ve viewed before',
                Colors.blue,
              ),
              
              const SizedBox(height: 32),
              
              // Sign In Button (Soft CTA)
              ElevatedButton(
                onPressed: () => context.push('/signin'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Sign In for Convenience Features'),
              ),
              
              const SizedBox(height: 16),
              
              // Become a Landlord (PROMINENT CTA)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.business, size: 32, color: Colors.green.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Are you a landlord?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'List your property for FREE + get promotional videos',
                      style: TextStyle(
                        color: Colors.green.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.push('/signin?redirect=landlord'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Listing Properties'),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Help & Support
              TextButton(
                onPressed: () {
                  // TODO: Add help/support screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help & Support coming soon!')),
                  );
                },
                child: const Text('Help & Support'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//
// ── NEW USER SCREEN ─────────────────────────────────────────────
//

class _NewUserScreen extends ConsumerWidget {
  final dynamic user;
  const _NewUserScreen({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName = user.userMetadata?['full_name'] as String? ?? '';
    final name = fullName.isNotEmpty ? fullName.split(' ').first : 'there';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              Text(
                'Welcome, $name 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              const Text(
                'What brings you to OpenSpot?',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 40),

              _ProfileTypeCard(
                title: 'I\'m a Landlord',
                subtitle: 'List properties and manage rentals',
                icon: Icons.home_work_outlined,
                color: Colors.blue,
                onTap: () => _createProfile(ref, context, 'landlord'),
              ),

              const SizedBox(height: 16),

              _ProfileTypeCard(
                title: 'I\'m Looking for Property',
                subtitle: 'Find and rent properties',
                icon: Icons.search,
                color: Colors.green,
                onTap: () => _createProfile(ref, context, 'regular'),
              ),

              const Spacer(),

              TextButton(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/');
                  }
                },
                child: const Text('Sign Out'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProfile(WidgetRef ref, BuildContext context, String type) async {
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile({'role': type});
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}

class _ProfileTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProfileTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

//
// ── PROFILE INCOMPLETE SCREEN ──────────────────────────────────
//

class _ProfileIncompleteScreen extends StatelessWidget {
  final dynamic user;
  final dynamic profile;

  const _ProfileIncompleteScreen({
    required this.user,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.userMetadata?['full_name'] as String? ?? 'User';
    final role = profile['role'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Hi $name!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your ${role == 'landlord' ? 'landlord' : 'user'} profile to get started',
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            _MissingField(
              icon: Icons.phone,
              title: 'Phone Number',
              subtitle: 'Required for contact',
              isComplete: profile['phone'] != null,
            ),
            
            _MissingField(
              icon: Icons.photo_camera,
              title: 'Profile Photo',
              subtitle: 'Help others recognize you',
              isComplete: profile['photo_url'] != null,
            ),
            
            _MissingField(
              icon: Icons.description,
              title: 'Bio',
              subtitle: 'Tell others about yourself',
              isComplete: profile['bio'] != null,
            ),
            
            if (role == 'landlord')
              _MissingField(
                icon: Icons.verified,
                title: 'Phone Verification',
                subtitle: 'Required for landlords',
                isComplete: profile['phone_verified'] == true,
              ),
            
            const Spacer(),
            
            ElevatedButton(
              onPressed: () => context.push('/profile-completion'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Complete Profile'),
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingField extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isComplete;

  const _MissingField({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isComplete ? Colors.green : AppTheme.textMuted,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isComplete ? Colors.green : AppTheme.textMuted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isComplete ? Colors.green : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete ? Colors.green : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

//
// ── REGULAR USER ACCOUNT SCREEN ──────────────────────────────────────────
//

class _RegularUserAccountScreen extends ConsumerWidget {
  final dynamic user;
  final dynamic profile;

  const _RegularUserAccountScreen({
    required this.user,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.userMetadata?['full_name'] as String? ?? 'User';
    final email = user.email as String? ?? '';
    final photoUrl = profile['photo_url'] as String?;
    final phone = profile['phone'] as String? ?? '';
    final phoneVerified = profile['phone_verified'] == true;
    final favoritesCount = ref.watch(favoritesCountProvider);
    final viewingHistoryCount = ref.watch(viewingHistoryCountProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            actions: [
              // Role Switcher Icon (like Instagram)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => AccountScreen.showRoleSwitcher(context, ref),
                tooltip: 'Switch Role',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      // Profile Photo
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: photoUrl != null 
                            ? NetworkImage(photoUrl) 
                            : null,
                        child: photoUrl == null 
                            ? Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // My Activity Section Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'My Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Activity Stats Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: _buildStatCard('Saved', favoritesCount.toString(), Icons.favorite, Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: viewingHistoryCount.when(
                      data: (count) => _buildStatCard('Viewed', count.toString(), Icons.history, Colors.blue),
                      loading: () => _buildStatCard('Viewed', '...', Icons.history, Colors.blue),
                      error: (_, __) => _buildStatCard('Viewed', '0', Icons.history, Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ref.watch(savedSearchesCountProvider).when(
                      data: (count) => _buildStatCard('Alerts', count.toString(), Icons.notifications, Colors.orange),
                      loading: () => _buildStatCard('Alerts', '...', Icons.notifications, Colors.orange),
                      error: (_, __) => _buildStatCard('Alerts', '0', Icons.notifications, Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions Section Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Quick Actions Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3, // More realistic ratio
              ),
              delegate: SliverChildListDelegate([
                _buildActionCard(
                  'Favorites',
                  Icons.favorite,
                  Colors.red,
                  () => context.push('/favorites'),
                ),
                _buildActionCard(
                  'History',
                  Icons.history,
                  Colors.blue,
                  () => context.push('/viewing-history'),
                ),
                _buildActionCard(
                  'Saved Searches',
                  Icons.search,
                  Colors.green,
                  () => context.push('/saved-searches'),
                ),
                _buildActionCard(
                  'Messages',
                  Icons.message,
                  Colors.purple,
                  () => context.push('/messages'),
                ),
              ]),
            ),
          ),

          // Become a Landlord CTA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.business, size: 32, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text(
                      'Become a Landlord',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'List your property for FREE + get promotional videos',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        // Switch to landlord role and handle verification flow
                        try {
                          await ref.read(authNotifierProvider.notifier).updateProfile({
                            'role': 'landlord',
                          });
                          
                          // Check if phone verification is needed
                          final currentProfile = ref.read(currentProfileProvider);
                          currentProfile.whenData((profileData) {
                            if (profileData != null) {
                              final phone = profileData['phone'] as String?;
                              final phoneVerified = profileData['phone_verified'] as bool? ?? false;
                              
                              if (context.mounted) {
                                if (phone == null || phone.isEmpty) {
                                  // Need to complete profile first
                                  context.push('/profile-completion');
                                } else if (!phoneVerified) {
                                  // Need to verify phone
                                  context.push('/phone-verification/$phone');
                                } else {
                                  // Already verified, go to landlord dashboard
                                  context.push('/landlord');
                                }
                              }
                            }
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green.shade600,
                      ),
                      child: const Text('Start Listing Properties'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Profile Information Section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Profile Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Profile Info List
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildInfoTile(Icons.email, 'Email', email),
                    _buildInfoTile(
                      Icons.phone,
                      'Phone',
                      phone.isNotEmpty ? phone : 'Not provided',
                      trailing: phoneVerified
                          ? const Icon(Icons.verified, color: Colors.green)
                          : const Icon(Icons.warning, color: Colors.orange),
                    ),
                    const SizedBox(height: 24),
                    _buildActionTile(
                      Icons.edit,
                      'Edit Profile',
                      'Update your information',
                      () => context.push('/profile-completion'),
                    ),
                    _buildActionTile(
                      Icons.logout,
                      'Sign Out',
                      'Log out of your account',
                      () => _showSignOutDialog(context, ref),
                      isDestructive: true,
                    ),
                    const SizedBox(height: 32), // Bottom padding
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
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

  Widget _buildInfoTile(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppTheme.danger : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppTheme.danger : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

//
// ── LANDLORD ACCOUNT SCREEN ──────────────────────────────────────────
//

class _LandlordAccountScreen extends ConsumerWidget {
  final dynamic user;
  final dynamic profile;

  const _LandlordAccountScreen({
    required this.user,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.userMetadata?['full_name'] as String? ?? 'User';
    final email = user.email as String? ?? '';
    final photoUrl = profile['photo_url'] as String?;
    final phone = profile['phone'] as String? ?? '';
    final phoneVerified = profile['phone_verified'] == true;
    final stats = ref.watch(landlordStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(landlordStatsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Profile Header
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              actions: [
                // Role Switcher Icon
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () => AccountScreen.showRoleSwitcher(context, ref),
                  tooltip: 'Switch Role',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.push('/settings'),
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
                          // Profile Photo
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: photoUrl != null 
                                ? NetworkImage(photoUrl) 
                                : null,
                            child: photoUrl == null 
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          // Name + Verified Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (phoneVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Landlord Badge
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
                              'Landlord',
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

            // Content based on stats loading state
            stats.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading stats: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(landlordStatsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (statsData) => _buildLandlordContent(context, ref, statsData, email, phone, phoneVerified),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordContent(BuildContext context, WidgetRef ref, Map<String, dynamic> statsData, String email, String phone, bool phoneVerified) {
    return SliverMainAxisGroup(
      slivers: [
        // Dashboard Quick Access (HERO CARD)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDashboardCard(context, statsData),
          ),
        ),

        // Role Switcher
        const SliverToBoxAdapter(
          child: RoleSwitcher(),
        ),

        // Quick Actions Section Header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Quick Actions Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3, // More realistic ratio
            ),
            delegate: SliverChildListDelegate([
              _buildActionCard(
                'Add Property',
                Icons.add_home,
                Colors.blue,
                () => context.push('/add-property'),
              ),
              _buildActionCard(
                'Promo Videos',
                Icons.video_library,
                Colors.purple,
                () => context.push('/promotional-videos'),
                badge: '${statsData['promoVideos']?.length ?? 0}',
              ),
              _buildActionCard(
                'Analytics',
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
            ]),
          ),
        ),

        // Recent Activity Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _buildRecentActivity(context, statsData),
          ),
        ),

        // Profile Information Section
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Profile Info and Actions List
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildInfoTile(Icons.email, 'Email', email),
                  _buildInfoTile(
                    Icons.phone,
                    'Phone',
                    phone.isNotEmpty ? phone : 'Not provided',
                    trailing: phoneVerified
                        ? const Icon(Icons.verified, color: Colors.green)
                        : const Icon(Icons.warning, color: Colors.orange),
                  ),
                  const SizedBox(height: 24),
                  _buildActionTile(
                    Icons.edit,
                    'Edit Profile',
                    'Update your information',
                    () => context.push('/profile-completion'),
                  ),
                  _buildActionTile(
                    Icons.logout,
                    'Sign Out',
                    'Log out of your account',
                    () => _showSignOutDialog(context, ref),
                    isDestructive: true,
                  ),
                  const SizedBox(height: 32), // Bottom padding
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(BuildContext context, Map<String, dynamic> stats) {
    final totalProperties = stats['totalProperties'] as int? ?? 0;
    final totalViews = stats['totalViews'] as int? ?? 0;
    final totalContacts = stats['totalContacts'] as int? ?? 0;
    final activeProperties = stats['activeProperties'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Landlord Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick Stats
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: _buildQuickStat('Properties', totalProperties.toString(), Icons.home_work),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStat('Views', _formatNumber(totalViews), Icons.visibility),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStat('Contacts', totalContacts.toString(), Icons.phone),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status Summary
          if (totalProperties > 0) ...[
            Text(
              '$activeProperties of $totalProperties properties are active',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // CTA Button
          ElevatedButton(
            onPressed: () => context.push('/landlord'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text(
              'Go to Full Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap, {String? badge}) {
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
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (badge != null && badge != '0')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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

  Widget _buildRecentActivity(BuildContext context, Map<String, dynamic> stats) {
    final recentProperties = stats['recentProperties'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (recentProperties.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.timeline, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'No recent activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add your first property to see activity here',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/add-property'),
                  child: const Text('Add Property'),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              _buildActivityItem(
                Icons.visibility,
                'Your properties got ${stats['totalViews'] ?? 0} views this week',
                Colors.blue,
              ),
              _buildActivityItem(
                Icons.phone,
                '${stats['totalContacts'] ?? 0} people contacted you',
                Colors.green,
              ),
              _buildActivityItem(
                Icons.home_work,
                'You have ${stats['activeProperties'] ?? 0} active listings',
                Colors.orange,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActivityItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppTheme.danger : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppTheme.danger : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}


//
// ── ROLE SWITCHER BOTTOM SHEET ──────────────────────────────────────────
//

class _RoleSwitcherSheet extends ConsumerWidget {
  const _RoleSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final availableRoles = ref.watch(availableRolesProvider);

    debugPrint('=== Role Switcher Sheet Opened ===');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Switch Role',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a role to switch to or create a new profile',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // All Available Roles (Always Show All Options)
          profile.when(
            data: (profileData) {
              final currentRole = profileData?['role'] as String? ?? 'regular';
              final subRole = profileData?['sub_role'] as String?;

              debugPrint('Current Role: $currentRole');
              debugPrint('Sub Role: $subRole');

              return availableRoles.when(
                data: (activeRoles) {
                  debugPrint('Active Roles: $activeRoles');
                  
                  // Check which roles are active
                  final hasLandlord = activeRoles.contains('landlord') || currentRole == 'landlord';
                  final hasCaretaker = activeRoles.contains('caretaker');
                  final hasAgency = activeRoles.contains('agency') || subRole == 'agency';
                  final isCurrentlyLandlord = currentRole == 'landlord';

                  debugPrint('Has Landlord: $hasLandlord');
                  debugPrint('Has Caretaker: $hasCaretaker');
                  debugPrint('Has Agency: $hasAgency');
                  debugPrint('Is Currently Landlord: $isCurrentlyLandlord');

                  return Column(
                    children: [
                      // Landlord Role
                      _buildRoleOption(
                        context,
                        ref,
                        role: 'landlord',
                        icon: Icons.home_work,
                        label: 'Landlord',
                        description: 'List and manage your properties',
                        color: Colors.blue,
                        isActive: isCurrentlyLandlord,
                        hasProfile: hasLandlord,
                        onTap: () => _handleRoleSwitch(
                          context,
                          ref,
                          'landlord',
                          hasLandlord,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Agency Role
                      _buildRoleOption(
                        context,
                        ref,
                        role: 'agency',
                        icon: Icons.business,
                        label: 'Agency',
                        description: 'Manage properties for multiple landlords',
                        color: Colors.purple,
                        isActive: subRole == 'agency',
                        hasProfile: hasAgency,
                        onTap: () => _handleRoleSwitch(
                          context,
                          ref,
                          'agency',
                          hasAgency,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Caretaker Role (Show if user has assignments)
                      if (hasCaretaker)
                        _buildRoleOption(
                          context,
                          ref,
                          role: 'caretaker',
                          icon: Icons.person,
                          label: 'Caretaker',
                          description: 'Manage properties for landlords',
                          color: Colors.green,
                          isActive: false,
                          hasProfile: true,
                          onTap: () {
                            Navigator.pop(context);
                            _showCaretakerSelection(context);
                          },
                        ),

                      // Info about caretaker if not available
                      if (!hasCaretaker) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Caretaker role appears when a landlord invites you',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading roles'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading profile'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context,
    WidgetRef ref, {
    required String role,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required bool isActive,
    required bool hasProfile,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            if (!hasProfile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: isActive
            ? Icon(Icons.check_circle, color: color)
            : Icon(
                hasProfile ? Icons.chevron_right : Icons.add_circle_outline,
                color: hasProfile ? Colors.grey : color,
              ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleRoleSwitch(
    BuildContext context,
    WidgetRef ref,
    String targetRole,
    bool hasProfile,
  ) async {
    if (hasProfile) {
      // Profile exists, just switch
      Navigator.pop(context);
      _switchToExistingRole(context, targetRole);
    } else {
      // No profile, show create profile dialog
      final shouldCreate = await _showCreateProfileDialog(context, targetRole);
      if (shouldCreate == true && context.mounted) {
        // Create the profile while bottom sheet is still open
        await _createRoleProfile(context, ref, targetRole);
        // Close the bottom sheet after creation
        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  void _switchToExistingRole(BuildContext context, String role) {
    switch (role) {
      case 'landlord':
        context.go('/landlord');
        break;
      case 'agency':
        context.go('/agency');
        break;
      case 'caretaker':
        _showCaretakerSelection(context);
        break;
      default:
        context.go('/account');
    }
  }

  Future<bool?> _showCreateProfileDialog(
    BuildContext context,
    String targetRole,
  ) async {
    String roleLabel;
    String roleDescription;
    IconData roleIcon;
    Color roleColor;

    switch (targetRole) {
      case 'landlord':
        roleLabel = 'Landlord';
        roleDescription = 'You\'ll be able to list properties, manage rentals, and track analytics.';
        roleIcon = Icons.home_work;
        roleColor = Colors.blue;
        break;
      case 'agency':
        roleLabel = 'Agency';
        roleDescription = 'You\'ll be able to manage properties for multiple landlords and track your agency performance.';
        roleIcon = Icons.business;
        roleColor = Colors.purple;
        break;
      default:
        return false;
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(roleIcon, color: roleColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Create $roleLabel Profile'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You don\'t have a $roleLabel profile yet.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(roleDescription),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: roleColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Free to create and use',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Create $roleLabel Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoleProfile(
    BuildContext context,
    WidgetRef ref,
    String targetRole,
  ) async {
    try {
      debugPrint('Creating profile for role: $targetRole');
      
      if (targetRole == 'landlord') {
        // Switch to landlord role
        await ref.read(authNotifierProvider.notifier).updateProfile({
          'role': 'landlord',
        });

        debugPrint('Landlord profile created successfully');

        if (context.mounted) {
          // Check if phone verification is needed
          final profile = await ref.read(currentProfileProvider.future);
          final phone = profile?['phone'] as String?;
          final phoneVerified = profile?['phone_verified'] as bool? ?? false;

          if (phone == null || phone.isEmpty) {
            // Need to add phone number
            context.push('/profile-completion');
          } else if (!phoneVerified) {
            // Need to verify phone
            context.push('/phone-verification/$phone');
          } else {
            // All set, go to landlord dashboard
            context.go('/landlord');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Landlord profile created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (targetRole == 'agency') {
        debugPrint('Attempting to create agency profile...');
        
        // Add agency sub-role
        await ref.read(authNotifierProvider.notifier).updateProfile({
          'sub_role': 'agency',
        });

        debugPrint('Agency profile created successfully');

        if (context.mounted) {
          context.go('/agency');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agency profile created! Complete your agency setup to continue.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating profile: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showCaretakerSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CaretakerSelectionSheet(),
    );
  }
}

class _CaretakerSelectionSheet extends ConsumerWidget {
  const _CaretakerSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(caretakerAssignmentsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Landlord',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which landlord\'s properties you want to manage',
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          assignments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (assignmentsList) {
              if (assignmentsList.isEmpty) {
                return const Text('No active caretaker assignments');
              }

              return Column(
                children: assignmentsList.map((assignment) {
                  final landlord = assignment['landlord'] as Map<String, dynamic>?;
                  final landlordName = landlord?['full_name'] ?? 'Unknown';
                  final landlordEmail = landlord?['email'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(landlordName[0].toUpperCase()),
                    ),
                    title: Text(landlordName),
                    subtitle: Text(landlordEmail),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/caretaker-dashboard/${assignment['landlord_id']}');
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
