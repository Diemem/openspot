import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ── Properties ──────────────────────────────────────────────
  Future<List<Property>> getProperties({
    String? category,
    String? listingType,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    bool featuredOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    // Build filter query first, then apply ordering and pagination
    var query = client.from('properties').select().eq('status', 'active');

    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    if (listingType != null) {
      query = query.eq('listing_type', listingType);
    }
    if (minPrice != null) {
      query = query.gte('price', minPrice);
    }
    if (maxPrice != null) {
      query = query.lte('price', maxPrice);
    }
    if (bedrooms != null) {
      query = query.gte('bedrooms', bedrooms);
    }
    if (featuredOnly) {
      query = query.eq('featured', true);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => Property.fromJson(e)).toList();
  }

  Future<Property?> getPropertyById(String id) async {
    final data = await client
        .from('properties')
        .select()
        .eq('id', id)
        .single();
    return Property.fromJson(data);
  }

  Future<List<Property>> searchProperties(String term) async {
    final data = await client
        .from('properties')
        .select()
        .eq('status', 'active')
        .or('title.ilike.%$term%,location.ilike.%$term%,description.ilike.%$term%')
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => Property.fromJson(e)).toList();
  }

  Future<List<Property>> getLandlordProperties(String landlordId) async {
    final data = await client
        .from('properties')
        .select()
        .eq('landlord_id', landlordId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Property.fromJson(e)).toList();
  }

  // ── Favorites ────────────────────────────────────────────────
  Future<List<String>> getFavoriteIds(String userId) async {
    final data = await client
        .from('favorites')
        .select('property_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['property_id'] as String).toList();
  }

  Future<void> addFavorite(String userId, String propertyId) async {
    await client.from('favorites').insert({
      'user_id': userId,
      'property_id': propertyId,
    });
  }

  Future<void> removeFavorite(String userId, String propertyId) async {
    await client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('property_id', propertyId);
  }

  Future<List<Property>> getFavoriteProperties(String userId) async {
    final data = await client
        .from('favorites')
        .select('properties(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Property.fromJson(e['properties'] as Map<String, dynamic>))
        .toList();
  }

  // ── Property CRUD ────────────────────────────────────────────
  Future<Property> createProperty(Map<String, dynamic> data) async {
    final result = await client
        .from('properties')
        .insert(data)
        .select()
        .single();
    return Property.fromJson(result);
  }

  Future<Property> updateProperty(String id, Map<String, dynamic> data) async {
    final result = await client
        .from('properties')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Property.fromJson(result);
  }

  Future<void> deleteProperty(String id) async {
    await client.from('properties').delete().eq('id', id);
  }

  Future<void> incrementViews(String propertyId) async {
    try {
      await client.rpc('increment_property_views', params: {'property_id': propertyId});
    } catch (_) {
      // Non-critical — fire and forget, don't crash if RPC doesn't exist
    }
  }

  // ── Storage ──────────────────────────────────────────────────
  Future<String> uploadImage(String path, Uint8List bytes, String mimeType) async {
    await client.storage.from('property-images').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
    return client.storage.from('property-images').getPublicUrl(path);
  }
}

final supabaseService = SupabaseService();
