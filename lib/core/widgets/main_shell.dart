import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/screens/notifications_detail_screen.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/favorites')) return 3;
    if (location.startsWith('/notifications')) return 4;
    if (location.startsWith('/account')) return 5;
    return 0;
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, int currentIndex) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, ref, index),
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Explore',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'Map',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.favorite_outline),
          activeIcon: Icon(Icons.favorite),
          label: 'Saved',
        ),
        BottomNavigationBarItem(
          icon: user != null 
              ? _buildNotificationIcon(ref)
              : const Icon(Icons.notifications_outlined),
          activeIcon: const Icon(Icons.notifications),
          label: 'Alerts',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    );
  }

  Widget _buildNotificationIcon(WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    
    return unreadCount.when(
      data: (count) {
        if (count > 0) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }
        return const Icon(Icons.notifications_outlined);
      },
      loading: () => const Icon(Icons.notifications_outlined),
      error: (_, __) => const Icon(Icons.notifications_outlined),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final currentIndex = _locationToIndex(location);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: isWide ? _DesktopNavBar(ref: ref) : null,
      body: child,
      bottomNavigationBar: isWide ? null : _buildBottomNav(context, ref, currentIndex),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/explore'); break;
      case 2: context.go('/map'); break;
      case 3: context.go('/favorites'); break;
      case 4:
        final session = Supabase.instance.client.auth.currentSession;
        context.go(session != null ? '/notifications' : '/signin');
        break;
      case 5:
        final session = Supabase.instance.client.auth.currentSession;
        context.go(session != null ? '/account' : '/signin');
        break;
    }
  }
}

class _DesktopNavBar extends ConsumerWidget implements PreferredSizeWidget {
  final WidgetRef ref;
  const _DesktopNavBar({required this.ref});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final location = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    final navItems = [
      {'id': '/', 'label': 'Home', 'icon': Icons.home_outlined},
      {'id': '/explore', 'label': 'Explore', 'icon': Icons.search_outlined},
      {'id': '/map', 'label': 'Map View', 'icon': Icons.map_outlined},
      {'id': '/favorites', 'label': 'Favorites', 'icon': Icons.favorite_outline},
    ];

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Logo
            GestureDetector(
              onTap: () => context.go('/'),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]).createShader(bounds),
                  child: const Text('OpenSpot', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(width: 32),

            // Nav links
            ...navItems.map((item) {
              final isActive = location == item['id'] || (item['id'] != '/' && location.startsWith(item['id'] as String));
              return GestureDetector(
                onTap: () => context.go(item['id'] as String),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(item['icon'] as IconData, size: 16, color: isActive ? const Color(0xFF2563EB) : const Color(0xFF374151)),
                    const SizedBox(width: 6),
                    Text(item['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isActive ? const Color(0xFF2563EB) : const Color(0xFF374151))),
                  ]),
                ),
              );
            }),

            // More button
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.more_horiz, size: 16, color: Color(0xFF374151)),
                  SizedBox(width: 6),
                  Text('More', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                ]),
              ),
            ),

            const Spacer(),

            // Right side
            if (user != null) ...[
              // Notification bell
              GestureDetector(
                onTap: () => context.go('/notifications'),
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF374151)),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // User avatar + name
              GestureDetector(
                onTap: () => context.go('/account'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (user.userMetadata?['full_name'] as String? ?? user.email ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        (user.email ?? '').split('@').first,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                      ),
                      const Text('View profile', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Sign out
              GestureDetector(
                onTap: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.logout, size: 18, color: Color(0xFF6B7280)),
                ),
              ),
            ] else
              GestureDetector(
                onTap: () => context.push('/signin'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
