import 'package:latlong2/latlong.dart';

class SearchContext {
  final LatLng? targetLocation;
  final double? maxDistanceKm;
  final double? minPrice;
  final double? maxPrice;
  final int? minBedrooms;
  final String? category;
  final String? listingType;
  final String? query; // e.g., 'kilimani', 'pool'

  const SearchContext({
    this.targetLocation,
    this.maxDistanceKm, // No default - only filter by distance if explicitly set
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.category,
    this.listingType,
    this.query,
  });

  SearchContext copyWith({
    LatLng? targetLocation,
    double? maxDistanceKm,
    double? minPrice,
    double? maxPrice,
    int? minBedrooms,
    String? category,
    String? listingType,
    String? query,
    bool clearDistance = false, // Flag to explicitly clear distance
  }) {
    return SearchContext(
      targetLocation: targetLocation ?? this.targetLocation,
      maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minBedrooms: minBedrooms ?? this.minBedrooms,
      category: category ?? this.category,
      listingType: listingType ?? this.listingType,
      query: query ?? this.query,
    );
  }

  String describe() {
    final parts = <String>[];
    if (category != null && category != 'all') parts.add('"$category"');
    if (listingType != null && listingType != 'all') parts.add('for $listingType');
    if (query != null && query!.isNotEmpty) parts.add("matching '$query'");
    if (minBedrooms != null) parts.add('$minBedrooms+ beds');
    
    if (parts.isEmpty) return 'these filters';
    return parts.join(' ');
  }
}
