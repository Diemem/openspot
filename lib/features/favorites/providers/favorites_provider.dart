import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/property.dart';

// Modern AsyncNotifier-based favorites provider
class FavoritesNotifier extends AsyncNotifier<List<Property>> {
  @override
  Future<List<Property>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('''
            created_at,
            properties!inner(
              id, title, description, property_type, category, listing_type,
              location, address, latitude, longitude, city,
              price, currency, bedrooms, bathrooms, area,
              images, thumbnail_url, video_url,
              landlord_name, landlord_phone, landlord_verified,
              available, status, verified, featured, views, likes, created_at
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50); // Reasonable limit for favorites

      final properties = <Property>[];
      
      for (final item in response as List) {
        try {
          final propertyData = item['properties'] as Map<String, dynamic>?;
          if (propertyData != null) {
            final property = Property.fromJson(propertyData);
            properties.add(property);
          }
        } catch (e) {
          // Skip individual property parsing errors but continue with others
          continue;
        }
      }
      
      return properties;
    } catch (e) {
      throw Exception('Failed to load favorites: $e');
    }
  }

  Future<void> addFavorite(String propertyId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('Must be signed in to save favorites');
    }

    // Optimistic update - get property details first
    final currentFavorites = state.value ?? [];
    
    try {
      // Get property details for optimistic update
      final propertyResponse = await Supabase.instance.client
          .from('properties')
          .select('''
            id, title, description, property_type, category, listing_type,
            location, address, latitude, longitude, city,
            price, currency, bedrooms, bathrooms, area,
            images, thumbnail_url, video_url,
            landlord_name, landlord_phone, landlord_verified,
            available, status, verified, featured, views, likes, created_at
          ''')
          .eq('id', propertyId)
          .single();

      final property = Property.fromJson(propertyResponse);
      
      // Update UI immediately (optimistic)
      if (!currentFavorites.any((p) => p.id == propertyId)) {
        state = AsyncValue.data([property, ...currentFavorites]);
      }

      // Then update database using upsert to handle duplicates
      await Supabase.instance.client
          .from('favorites')
          .upsert({
            'user_id': user.id,
            'property_id': propertyId,
          }, onConflict: 'user_id,property_id');

    } catch (e) {
      // Rollback optimistic update on error
      state = AsyncValue.data(currentFavorites);
      rethrow;
    }
  }

  Future<void> removeFavorite(String propertyId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Optimistic update
    final currentFavorites = state.value ?? [];
    final updatedFavorites = currentFavorites.where((p) => p.id != propertyId).toList();
    
    // Update UI immediately
    state = AsyncValue.data(updatedFavorites);

    try {
      await Supabase.instance.client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('property_id', propertyId);

    } catch (e) {
      // Rollback optimistic update on error
      state = AsyncValue.data(currentFavorites);
      rethrow;
    }
  }

  Future<void> toggleFavorite(String propertyId) async {
    final currentFavorites = state.value ?? [];
    final isFavorited = currentFavorites.any((p) => p.id == propertyId);
    
    if (isFavorited) {
      await removeFavorite(propertyId);
    } else {
      await addFavorite(propertyId);
    }
  }
}

// Main favorites provider using AsyncNotifier
final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<Property>>(() {
  return FavoritesNotifier();
});

// Provider for checking if a property is favorited (derived from favorites list)
final isFavoriteProvider = Provider.family<bool, String>((ref, propertyId) {
  final favoritesAsync = ref.watch(favoritesProvider);
  
  return favoritesAsync.maybeWhen(
    data: (favorites) => favorites.any((property) => property.id == propertyId),
    orElse: () => false,
  );
});

// Provider for favorites count (derived from favorites list)
final favoritesCountProvider = Provider.autoDispose<int>((ref) {
  final favoritesAsync = ref.watch(favoritesProvider);
  
  return favoritesAsync.maybeWhen(
    data: (favorites) => favorites.length,
    orElse: () => 0,
  );
});

// Legacy notifier provider for backward compatibility - returns the notifier directly
final favoritesNotifierProvider = Provider<FavoritesNotifier>((ref) {
  return ref.read(favoritesProvider.notifier);
});