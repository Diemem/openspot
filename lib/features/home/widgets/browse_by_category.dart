import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BrowseByCategory extends StatelessWidget {
  const BrowseByCategory({super.key});

  static const _categories = [
    _Cat('Residential', Icons.home_outlined, Color(0xFF3B82F6), Color(0xFF1D4ED8),
        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400&q=80'),
    _Cat('Commercial', Icons.storefront_outlined, Color(0xFF8B5CF6), Color(0xFF6D28D9),
        'https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&q=80'),
    _Cat('Industrial', Icons.factory_outlined, Color(0xFFF97316), Color(0xFFEA580C),
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=400&q=80'),
    _Cat('Agricultural', Icons.agriculture_outlined, Color(0xFF10B981), Color(0xFF059669),
        'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400&q=80'),
    _Cat('Land', Icons.landscape_outlined, Color(0xFF14B8A6), Color(0xFF0D9488),
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400&q=80'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse by category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Find the perfect space for your needs',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CategoryCard(cat: cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _Cat cat;
  const _CategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/map?category=${cat.title.toLowerCase()}'),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.network(
                cat.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: cat.colorLight),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cat.colorLight.withOpacity(0.6),
                      cat.colorDark.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat.icon, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    cat.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cat {
  final String title;
  final IconData icon;
  final Color colorLight;
  final Color colorDark;
  final String imageUrl;

  const _Cat(this.title, this.icon, this.colorLight, this.colorDark, this.imageUrl);
}
