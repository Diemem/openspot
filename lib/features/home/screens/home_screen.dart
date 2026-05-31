import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/property.dart';
import '../../search_engine/application/search_controller.dart';
import '../widgets/hero_section.dart';
import '../widgets/browse_by_category.dart';
import '../widgets/horizontal_property_list.dart';
import '../widgets/section_title.dart';
import '../widgets/trust_section.dart';
import '../widgets/cta_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(homeSearchControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
          color: const Color(0xFF4F46E5),
          onRefresh: () async => ref.invalidate(homeSearchControllerProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welcome message ──────────────────────────────
                const _WelcomeHeader(),

                // ── Hero section ─────────────────────────────────
                const HeroSection(),

                // ── Properties feed ──────────────────────────────
                propertiesAsync.when(
                  loading: () => const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    ),
                  ),
                  error: (e, _) => SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Failed to load properties'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(homeSearchControllerProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (properties) => _HomeBody(properties: properties),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

// ── Welcome Header ─────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String?;
    final greeting = name != null ? 'Hello, ${name.split(' ').first} 👋' : 'Hello 👋';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        greeting,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

// ── Home Body ──────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final List<Property> properties;

  const _HomeBody({required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Color(0xFFD1D5DB)),
              SizedBox(height: 16),
              Text(
                'No properties found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    // Sort: featured first, then newest
    final sorted = [...properties]..sort((a, b) {
        if (a.featured && !b.featured) return -1;
        if (!a.featured && b.featured) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final featured = sorted.where((p) => p.featured).take(12).toList();
    final recent = [...properties]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentSlice = recent.take(12).toList();
    final nearYou = sorted.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Near You
        SectionTitle(
          title: 'Properties near you',
          actionLabel: 'See all',
          onAction: () => context.push('/map'),
        ),
        HorizontalPropertyList(properties: nearYou),

        // Featured (only if any)
        if (featured.isNotEmpty) ...[
          SectionTitle(
            title: 'Featured properties',
            actionLabel: 'See all',
            onAction: () => context.push('/map'),
          ),
          HorizontalPropertyList(properties: featured),
        ],

        // Browse by Category
        const SizedBox(height: 8),
        const BrowseByCategory(),

        // Recently Added
        SectionTitle(
          title: 'Recently added',
          actionLabel: 'See all',
          onAction: () => context.push('/explore'),
        ),
        HorizontalPropertyList(properties: recentSlice),

        // Trust Section
        const SizedBox(height: 8),
        const TrustSection(),

        // CTA
        const CtaSection(),

        const SizedBox(height: 32),
      ],
    );
  }
}
