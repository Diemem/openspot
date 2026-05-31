import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class PropertyCard extends ConsumerWidget {
  final dynamic property; // Can be Property model or Map from database
  final double? width;
  final bool showViewedTime;
  final DateTime? viewedAt;

  const PropertyCard({
    super.key,
    required this.property,
    this.width,
    this.showViewedTime = false,
    this.viewedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    try {
      // Extract property data whether it's a Property model or Map
      final String propertyId = property is Property ? property.id : property['id'] as String;
      final String title = property is Property ? property.title : (property['title'] ?? '');
      final double price = property is Property ? property.price : ((property['price'] as num?)?.toDouble() ?? 0.0);
      final String location = property is Property ? property.location : (property['location'] ?? '');
      final int bedrooms = property is Property ? (property.bedrooms ?? 0) : ((property['bedrooms'] as num?)?.toInt() ?? 0);
      final int bathrooms = property is Property ? (property.bathrooms ?? 0) : ((property['bathrooms'] as num?)?.toInt() ?? 0);
      final bool verified = property is Property ? property.verified : (property['verified'] as bool? ?? false);
      
      // Handle image URLs
      String? firstImage;
      if (property is Property) {
        firstImage = property.firstImage;
      } else {
        final imageUrls = (property['image_urls'] as List?)?.cast<String>() ?? [];
        firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;
      }
      
      // Format price
      final formattedPrice = property is Property 
          ? property.formattedPrice 
          : 'KSh ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

      final isFavorite = user != null ? ref.watch(isFavoriteProvider(propertyId)) : false;

      return GestureDetector(
        onTap: () => context.push('/property/$propertyId'),
        child: Container(
          width: width ?? 240,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section with fixed height
              SizedBox(
                height: 130, // Reduced from 140 to give more space for content
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: firstImage != null
                          ? CachedNetworkImage(
                              imageUrl: firstImage,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 130, 
                                color: AppTheme.border,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 130,
                                color: AppTheme.border,
                                child: const Center(
                                  child: Icon(Icons.home, color: AppTheme.textMuted, size: 40),
                                ),
                              ),
                            )
                          : Container(
                              height: 130,
                              width: double.infinity,
                              color: AppTheme.border,
                              child: const Center(
                                child: Icon(Icons.home, color: AppTheme.textMuted, size: 40),
                              ),
                            ),
                    ),
                    
                    // Favorite button (only show if user is signed in)
                    if (user != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              await ref.read(favoritesNotifierProvider).toggleFavorite(propertyId);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isFavorite ? AppTheme.danger : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    
                    // Verified badge
                    if (verified)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Verified', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content section with flexible height
              Padding(
                padding: const EdgeInsets.all(10), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13, // Slightly smaller
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1, // Reduced to 1 line
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    
                    // Price
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 14, // Slightly smaller
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3), // Reduced spacing
                    
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 11, color: AppTheme.textMuted), // Smaller icon
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(
                              fontSize: 11, // Smaller text
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Bedrooms info (if available) - more compact
                    if (bedrooms > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$bedrooms bed${bedrooms > 1 ? 's' : ''}${bathrooms > 0 ? ', $bathrooms bath${bathrooms > 1 ? 's' : ''}' : ''}',
                        style: const TextStyle(
                          fontSize: 10, // Smaller text
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // Viewed time (if applicable) - only show if space allows
                    if (showViewedTime && viewedAt != null && bedrooms == 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Viewed ${_formatViewedTime(viewedAt!)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Error fallback widget
      return Container(
        width: width ?? 240,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 32),
            const SizedBox(height: 8),
            const Text(
              'Error loading property',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to retry',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatViewedTime(DateTime viewedAt) {
    final now = DateTime.now();
    final difference = now.difference(viewedAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${viewedAt.day}/${viewedAt.month}/${viewedAt.year}';
    }
  }
}