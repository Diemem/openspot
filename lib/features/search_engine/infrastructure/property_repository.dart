import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/property.dart';
import '../domain/models/search_context.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return PropertyRepository(supabaseService);
});

class PropertyRepository {
  final SupabaseService _supabase;

  PropertyRepository(this._supabase);

  Future<List<Property>> fetchBaseProperties(SearchContext context) async {
    print('📦 PROPERTY REPOSITORY: Fetching with category: ${context.category}');
    
    // For MVP, we load active properties broadly, 
    // letting the client-side filter engine do the heavy lifting of geographical scoring.
    // In the future (v2), we can use PostGIS `st_dwithin` here to restrict the DB query payload.
    
    var query = SupabaseService.client.from('properties').select().eq('status', 'active');
    
    if (context.category != null && context.category != 'all') {
      query = query.eq('category', context.category!);
    }
    
    print('📦 PROPERTY REPOSITORY: Executing Supabase query...');
    final data = await query.order('created_at', ascending: false).limit(200);
    print('📦 PROPERTY REPOSITORY: Query returned ${data.length} rows');

    final properties = (data as List).map((e) => Property.fromJson(e)).toList();
    print('📦 PROPERTY REPOSITORY: Mapped to ${properties.length} Property objects');

    // THE SEARCH RANKING ENGINE
    properties.sort((a, b) {
      return _calculateScore(b).compareTo(_calculateScore(a)); // Descending
    });

    return properties;
  }

  double _calculateScore(Property p) {
    double score = 0;

    // 1. Trust & Authority
    if (p.featured) score += 100;
    if (p.verified) score += 50;
    if (p.landlordVerified) score += 30;

    // 2. Engagement (Capped to prevent viral runaway)
    score += (p.likes * 2).clamp(0, 40);
    score += (p.views * 0.1).clamp(0, 15);

    // 3. Media Completeness
    score += (p.images.length * 5).clamp(0, 25);

    // 4. Recency Decay
    final daysOld = DateTime.now().difference(p.createdAt).inDays;
    if (daysOld <= 7) score += 20;
    else if (daysOld <= 30) score += 5;

    return score;
  }

  /// Increment view count for a property (Explore screen tracking)
  Future<void> incrementViews(String propertyId) async {
    try {
      await SupabaseService.client.rpc('increment_property_views', params: {'property_id': propertyId});
      print('✅ View tracked for property: $propertyId');
    } catch (e) {
      print('❌ Failed to track view: $e');
      // Silent fail - view tracking shouldn't break UX
    }
  }

  /// Increment like count for a property
  Future<void> incrementLikes(String propertyId) async {
    try {
      await SupabaseService.client.rpc('increment_property_likes', params: {'property_id': propertyId});
      print('✅ Like tracked for property: $propertyId');
    } catch (e) {
      print('❌ Failed to track like: $e');
    }
  }

  /// Decrement like count for a property
  Future<void> decrementLikes(String propertyId) async {
    try {
      await SupabaseService.client.rpc('decrement_property_likes', params: {'property_id': propertyId});
      print('✅ Unlike tracked for property: $propertyId');
    } catch (e) {
      print('❌ Failed to track unlike: $e');
    }
  }
}
