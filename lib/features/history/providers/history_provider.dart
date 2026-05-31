import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// Provider for user's viewing history
final viewingHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('property_views')
        .select('''
          property_id, viewed_at,
          properties!inner(
            id, title, price, location, property_type, bedrooms, bathrooms,
            image_urls, landlord_id, created_at, views, likes, available,
            profiles!landlord_id(full_name, phone, photo_url)
          )
        ''')
        .eq('user_id', user.id)
        .not('viewed_at', 'is', null)
        .order('viewed_at', ascending: false)
        .limit(50); // Last 50 viewed properties

    return (response as List).map((item) {
      final property = item['properties'] as Map<String, dynamic>;
      return {
        ...property,
        'landlord': property['profiles'],
        'viewed_at': item['viewed_at'],
      };
    }).toList();
  } catch (e) {
    throw Exception('Failed to load viewing history: $e');
  }
});

// Provider for viewing history count
final viewingHistoryCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from('property_views')
        .select('id')
        .eq('user_id', user.id)
        .not('viewed_at', 'is', null);

    return response.length;
  } catch (e) {
    return 0;
  }
});

// Function to track property view
Future<void> trackPropertyView(String propertyId, String? userId) async {
  if (userId == null) return; // Don't track for guests

  try {
    // Check if already viewed today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final existing = await Supabase.instance.client
        .from('property_views')
        .select('id')
        .eq('user_id', userId)
        .eq('property_id', propertyId)
        .gte('viewed_at', startOfDay.toIso8601String())
        .maybeSingle();

    if (existing != null) {
      // Already viewed today, just update timestamp
      await Supabase.instance.client
          .from('property_views')
          .update({
            'viewed_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('property_id', propertyId);
    } else {
      // Check if record exists at all
      final anyExisting = await Supabase.instance.client
          .from('property_views')
          .select('id')
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .maybeSingle();

      if (anyExisting != null) {
        // Update existing record
        await Supabase.instance.client
            .from('property_views')
            .update({
              'viewed_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('property_id', propertyId);
      } else {
        // Create new record
        await Supabase.instance.client
            .from('property_views')
            .insert({
              'user_id': userId,
              'property_id': propertyId,
              'viewed_at': DateTime.now().toIso8601String(),
            });
      }

      // Also increment the property's view count
      await Supabase.instance.client.rpc('increment_property_views', params: {
        'property_id': propertyId,
      });
    }
  } catch (e) {
    // Silently fail - viewing history is not critical
    debugPrint('Failed to track property view: $e');
  }
}