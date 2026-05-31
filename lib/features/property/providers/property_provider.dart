import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property.dart';
import '../../../core/services/supabase_service.dart';

/// ─────────────────────────────
/// Filters State
/// ─────────────────────────────
class PropertyFilters {
  final String? category;
  final String listingType;
  final double? minPrice;
  final double? maxPrice;
  final int? bedrooms;
  final String searchQuery;

  const PropertyFilters({
    this.category,
    this.listingType = 'rent',
    this.minPrice,
    this.maxPrice,
    this.bedrooms,
    this.searchQuery = '',
  });

  PropertyFilters copyWith({
    String? category,
    String? listingType,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    String? searchQuery,
  }) {
    return PropertyFilters(
      category: category ?? this.category,
      listingType: listingType ?? this.listingType,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      bedrooms: bedrooms ?? this.bedrooms,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// ─────────────────────────────
/// Filters Provider
/// ─────────────────────────────
final propertyFiltersProvider =
    StateProvider<PropertyFilters>((ref) => const PropertyFilters());

/// Optional helper for cleaner updates in UI
void updateFilters(WidgetRef ref, PropertyFilters Function(PropertyFilters) fn) {
  ref.read(propertyFiltersProvider.notifier).update(fn);
}

/// ─────────────────────────────
/// Properties List
/// ─────────────────────────────
final propertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  final filters = ref.watch(propertyFiltersProvider);

  // If searching → ignore other filters (faster + clearer UX)
  if (filters.searchQuery.trim().isNotEmpty) {
    return supabaseService.searchProperties(filters.searchQuery.trim());
  }

  return supabaseService.getProperties(
    category: filters.category,
    listingType: filters.listingType,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    bedrooms: filters.bedrooms,
  );
});

/// ─────────────────────────────
/// Featured Properties
/// ─────────────────────────────
final featuredPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return supabaseService.getProperties(
    featuredOnly: true,
    limit: 10,
  );
});

/// ─────────────────────────────
/// Property Details
/// ─────────────────────────────
final propertyDetailProvider =
    FutureProvider.autoDispose.family<Property?, String>((ref, id) async {
  final property = await supabaseService.getPropertyById(id);
  if (property != null) supabaseService.incrementViews(id);
  return property;
});

/// ─────────────────────────────
/// Landlord Properties
/// ─────────────────────────────
final landlordPropertiesProvider =
    FutureProvider.autoDispose.family<List<Property>, String>((ref, uid) async {
  return supabaseService.getLandlordProperties(uid);
});