import 'package:latlong2/latlong.dart';
import '../../../../core/models/property.dart';
import '../domain/models/search_context.dart';

class FilterEngine {
  final Distance _distanceCalculator = const Distance();

  List<Property> rankAndFilter(List<Property> properties, SearchContext context) {
    print('🔍 FILTER ENGINE: Starting with ${properties.length} properties');
    print('🔍 FILTER ENGINE: Context - location: ${context.targetLocation != null ? "YES" : "NO"}, maxDistance: ${context.maxDistanceKm}, category: ${context.category}');
    
    List<_RankedProperty> rankedProps = [];

    for (var prop in properties) {
      // 1. Strict Filters (Eliminators)
      if (context.minPrice != null && prop.price < context.minPrice!) continue;
      if (context.maxPrice != null && prop.price > context.maxPrice!) continue;
      if (context.minBedrooms != null && (prop.bedrooms ?? 0) < context.minBedrooms!) continue;
      if (context.listingType != null && prop.listingType != context.listingType) continue;
      
      if (context.query != null && context.query!.isNotEmpty) {
        final q = context.query!.toLowerCase();
        final match = prop.title.toLowerCase().contains(q) ||
                      prop.location.toLowerCase().contains(q) ||
                      (prop.description?.toLowerCase().contains(q) ?? false);
        if (!match) continue;
      }

      // Calculate distance if targetLocation is provided
      double? distanceKm;
      if (context.targetLocation != null && prop.latitude != null && prop.longitude != null) {
        final propLoc = LatLng(prop.latitude!, prop.longitude!);
        distanceKm = _distanceCalculator.as(LengthUnit.Meter, context.targetLocation!, propLoc) / 1000.0;
        
        // Only eliminate if user explicitly set a max distance filter
        if (context.maxDistanceKm != null && distanceKm > context.maxDistanceKm!) continue;
      }

      // 2. Ranking / Scoring Logic
      double score = 0.0;
      
      // Location Match (40%) - only if user has location
      if (distanceKm != null && context.targetLocation != null) {
        // Closer properties get higher score
        // Use a reasonable max distance for scoring (50km) even if no filter is set
        final maxForScoring = context.maxDistanceKm ?? 50.0;
        double locationScore = 1.0 - (distanceKm / maxForScoring).clamp(0.0, 1.0);
        score += locationScore * 0.4;
      } else {
        // If no location, give baseline score so properties still show
        score += 0.2; 
      }

      // Recency Match (30%) - newer properties are slightly better
      final daysOld = DateTime.now().difference(prop.createdAt).inDays;
      double recencyRes = 1.0;
      if (daysOld > 0) {
        recencyRes = (30.0 / (daysOld + 30.0)).clamp(0.0, 1.0); // Simple decay
      }
      score += recencyRes * 0.3;

      // Popularity/Quality Match (20%) - views/likes
      double qualityScore = ((prop.likes * 2 + prop.views) / 100.0).clamp(0.0, 1.0);
      score += qualityScore * 0.2;

      // Featured/Verified Boost (10%)
      if (prop.featured) score += 0.05;
      if (prop.verified) score += 0.05;

      rankedProps.add(_RankedProperty(property: prop, score: score));
    }

    // Sort descending by score
    rankedProps.sort((a, b) => b.score.compareTo(a.score));

    print('🔍 FILTER ENGINE: Filtered to ${rankedProps.length} properties');
    if (rankedProps.isNotEmpty) {
      print('🔍 FILTER ENGINE: Top property: ${rankedProps.first.property.title} (score: ${rankedProps.first.score.toStringAsFixed(2)})');
    }

    return rankedProps.map((r) => r.property).toList();
  }
}

class _RankedProperty {
  final Property property;
  final double score;

  _RankedProperty({required this.property, required this.score});
}
