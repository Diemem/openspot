import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/property.dart';
import '../domain/models/search_context.dart';
import '../infrastructure/property_repository.dart';
import 'filter_engine.dart';

final filterEngineProvider = Provider<FilterEngine>((ref) => FilterEngine());

// Separate search contexts for each screen
final homeSearchContextProvider = StateProvider<SearchContext>((ref) => const SearchContext());
final exploreSearchContextProvider = StateProvider<SearchContext>((ref) => const SearchContext());
final mapSearchContextProvider = StateProvider<SearchContext>((ref) => const SearchContext());

// Legacy provider for backward compatibility (uses home context)
final searchContextProvider = StateProvider<SearchContext>((ref) => ref.watch(homeSearchContextProvider));

// Separate search controllers for each screen
final homeSearchControllerProvider = FutureProvider<List<Property>>((ref) async {
  final context = ref.watch(homeSearchContextProvider);
  final repository = ref.read(propertyRepositoryProvider);
  final filterEngine = ref.read(filterEngineProvider);

  print('🔍 HOME SEARCH: Searching with context: ${context.describe()}');
  
  final baseProperties = await repository.fetchBaseProperties(context);
  print('🔍 HOME SEARCH: Fetched ${baseProperties.length} base properties');

  final filteredProperties = filterEngine.rankAndFilter(baseProperties, context);
  print('🔍 HOME SEARCH: Filtered to ${filteredProperties.length} properties');
  
  return filteredProperties;
});

final exploreSearchControllerProvider = FutureProvider<List<Property>>((ref) async {
  final context = ref.watch(exploreSearchContextProvider);
  final repository = ref.read(propertyRepositoryProvider);
  final filterEngine = ref.read(filterEngineProvider);

  print('🔍 EXPLORE SEARCH: Searching with context: ${context.describe()}');
  
  final baseProperties = await repository.fetchBaseProperties(context);
  print('🔍 EXPLORE SEARCH: Fetched ${baseProperties.length} base properties');

  final filteredProperties = filterEngine.rankAndFilter(baseProperties, context);
  print('🔍 EXPLORE SEARCH: Filtered to ${filteredProperties.length} properties');
  
  return filteredProperties;
});

final mapSearchControllerProvider = FutureProvider<List<Property>>((ref) async {
  final context = ref.watch(mapSearchContextProvider);
  final repository = ref.read(propertyRepositoryProvider);
  final filterEngine = ref.read(filterEngineProvider);

  print('🔍 MAP SEARCH: Searching with context: ${context.describe()}');
  
  final baseProperties = await repository.fetchBaseProperties(context);
  print('🔍 MAP SEARCH: Fetched ${baseProperties.length} base properties');

  final filteredProperties = filterEngine.rankAndFilter(baseProperties, context);
  print('🔍 MAP SEARCH: Filtered to ${filteredProperties.length} properties');
  
  return filteredProperties;
});

// Legacy provider for backward compatibility (uses home controller)
final searchControllerProvider = FutureProvider<List<Property>>((ref) async {
  return ref.watch(homeSearchControllerProvider).when(
    data: (data) => data,
    loading: () => [],
    error: (_, __) => [],
  );
});
