import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/property.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved')),
        body: const _NotSignedIn(),
      );
    }

    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Properties'),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(favoritesProvider);
        },
        child: favoritesAsync.when(
          loading: () => const _LoadingSkeleton(),

          error: (e, _) => _ErrorState(
            message: 'Failed to load saved properties',
            error: e,
            onRetry: () {
              ref.invalidate(favoritesProvider);
            },
          ),

          data: (properties) {
            if (properties.isEmpty) {
              return const _EmptyState();
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75, // Optimized for image + title only
              ),
              itemCount: properties.length,
              itemBuilder: (_, i) {
                final Property property = properties[i];

                return Dismissible(
                  key: ValueKey(property.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.delete, color: Colors.white),
                        SizedBox(height: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    final shouldRemove = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove from Saved'),
                        content: Text('Remove "${property.title}" from your saved properties?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );

                    if (shouldRemove == true) {
                      try {
                        await ref.read(favoritesProvider.notifier)
                            .removeFavorite(property.id);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed "${property.title}" from saved'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  ref.read(favoritesProvider.notifier)
                                      .addFavorite(property.id);
                                },
                              ),
                            ),
                          );
                        }
                        return true;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error removing favorite: $e')),
                          );
                        }
                        return false;
                      }
                    }
                    return false;
                  },
                  child: _FavoritePropertyCard(property: property),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

//
// ── NOT SIGNED IN ─────────────────────────────────────────────
//
class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border,
              size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Sign in to save properties',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/signin'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

//
// ── EMPTY STATE ─────────────────────────────────────────────
//
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.favorite_border,
            size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No saved properties yet',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Tap the ❤️ on any property to save it here',
            style: TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () => context.go('/explore'),
            child: const Text('Explore Properties'),
          ),
        ),
      ],
    );
  }
}

//
// ── ERROR STATE ─────────────────────────────────────────────
//
class _ErrorState extends StatelessWidget {
  final String message;
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String userFriendlyMessage = message;
    
    // Map technical errors to user-friendly messages
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('connection')) {
      userFriendlyMessage = 'Check your internet connection and try again';
    } else if (errorString.contains('timeout')) {
      userFriendlyMessage = 'Request timed out. Please try again';
    } else if (errorString.contains('unauthorized') || errorString.contains('auth')) {
      userFriendlyMessage = 'Please sign in again to view your saved properties';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 64, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            userFriendlyMessage,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

//
// ── LOADING SKELETON ─────────────────────────────────────────────
//
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Match the main grid
      ),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton - takes most space
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          // Title skeleton - minimal space
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
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
// ── MINIMAL FAVORITE PROPERTY CARD ─────────────────────────────────────────────
//
class _FavoritePropertyCard extends ConsumerWidget {
  final Property property;

  const _FavoritePropertyCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isFavorite = user != null ? ref.watch(isFavoriteProvider(property.id)) : false;

    return GestureDetector(
      onTap: () => context.push('/property/${property.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - takes most of the space
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: property.firstImage != null
                        ? CachedNetworkImage(
                            imageUrl: property.firstImage!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.border,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.border,
                              child: const Center(
                                child: Icon(Icons.home, color: AppTheme.textMuted, size: 40),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppTheme.border,
                            child: const Center(
                              child: Icon(Icons.home, color: AppTheme.textMuted, size: 40),
                            ),
                          ),
                  ),
                  
                  // Favorite button (top right)
                  if (user != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await ref.read(favoritesProvider.notifier).removeFavorite(property.id);
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
                            color: isFavorite ? Colors.red : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  
                  // Verified badge (top left)
                  if (property.verified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text('Verified', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Title section - minimal space
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                property.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}