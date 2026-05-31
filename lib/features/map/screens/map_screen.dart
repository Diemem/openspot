import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/property.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../search_engine/application/search_controller.dart';
import '../widgets/filter_panel.dart';

// Property type colors — matches original
const _typeColors = {
  'bedsitter': Color(0xFFEF4444),
  'studio':    Color(0xFF3B82F6),
  'apartment': Color(0xFF10B981),
  'house':     Color(0xFF8B5CF6),
  'office':    Color(0xFFF59E0B),
  'shop':      Color(0xFFF97316),
  'warehouse': Color(0xFF6B7280),
  'land':      Color(0xFF14B8A6),
};
const _defaultMarkerColor = Color(0xFF6366F1);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  static const _nairobiCenter = LatLng(-1.2921, 36.8219);

  // State
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  List<String> _selectedTypes = ['all'];
  Property? _selectedProperty;
  List<Property>? _clusterProperties;
  bool _isSatellite = false;
  bool _showFilters = false;
  FilterState _filterState = FilterState.empty;
  double _currentZoom = 12.0; // Track zoom level for smart clustering

  // Search suggestions
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  
  // Map interaction debouncing
  Timer? _mapDebounce;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _mapDebounce?.cancel();
    super.dispose();
  }

  // ── LIVE LOCATION ──────────────────────────────────────────────────────────
  Future<void> _getUserLocation() async {
    setState(() => _isLoadingLocation = true);
    
    // Try to get last known location first (faster)
    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() => _userLocation = lastKnown);
      _mapController.move(lastKnown, 14);
      
      // Update search context
      ref.read(mapSearchContextProvider.notifier).update((ctx) => ctx.copyWith(
        targetLocation: lastKnown,
      ));
    }

    // Then get current accurate location
    final currentLocation = await LocationService.getCurrentLocation();
    if (currentLocation != null && mounted) {
      setState(() {
        _userLocation = currentLocation;
        _isLoadingLocation = false;
      });
      _mapController.move(currentLocation, 14);
      
      // Update search context with accurate location
      ref.read(mapSearchContextProvider.notifier).update((ctx) => ctx.copyWith(
        targetLocation: currentLocation,
      ));
    } else {
      setState(() => _isLoadingLocation = false);
      
      if (lastKnown == null && mounted) {
        // No location available, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission needed to show properties near you'),
            action: SnackBarAction(
              label: 'Enable',
              onPressed: () => LocationService.openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ── SEARCH SUGGESTIONS (Nominatim OSM — free, no key needed) ──────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      // Use Nominatim (OSM) Geocoding API - completely free
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)},Kenya&format=json&limit=5&addressdetails=1',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'OpenSpot/1.0 (contact@openspot.co.ke)'},
      ).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _suggestions = data.map((e) {
            return {
              'name': e['display_name'] as String,
              'lat': double.parse(e['lat'] as String),
              'lon': double.parse(e['lon'] as String),
            };
          }).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      // Handle errors gracefully - show message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search unavailable. Check your internet connection.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _selectSuggestion(Map<String, dynamic> s) {
    final pos = LatLng(s['lat'] as double, s['lon'] as double);
    _mapController.move(pos, 14);
    _searchCtrl.text = (s['name'] as String).split(',').first;
    setState(() { _suggestions = []; _showSuggestions = false; });
    ref.read(mapSearchContextProvider.notifier).update((ctx) => ctx.copyWith(targetLocation: pos));
  }

  // ── SMART CLUSTERING (Zoom + Density Based) ───────────────────────────────
  
  /// Get cluster distance based on zoom level
  double _getClusterDistance(double zoom) {
    if (zoom < 12) return 500;      // City view - large clusters
    if (zoom < 14) return 200;      // District view - medium clusters  
    if (zoom < 16) return 100;      // Neighborhood view - small clusters
    return 50;                      // Street view - minimal clustering
  }
  
  /// Calculate density of properties in an area (properties per 100m radius)
  int _calculateDensity(List<Property> props, Property center) {
    int count = 0;
    for (final p in props) {
      if (p.latitude == null || p.longitude == null) continue;
      final dist = _dist(center.latitude!, center.longitude!, p.latitude!, p.longitude!);
      if (dist < 100) count++; // Count properties within 100m
    }
    return count;
  }
  
  List<_MarkerGroup> _buildGroups(List<Property> props) {
    final groups = <_MarkerGroup>[];
    final processed = <int>{};
    
    // Get base cluster distance from zoom level
    double clusterDistance = _getClusterDistance(_currentZoom);
    
    // For zoomed-in views, adjust based on density
    if (_currentZoom >= 16) {
      // Check if this is a high-density area (like slums)
      if (props.isNotEmpty) {
        final sampleDensity = _calculateDensity(props, props.first);
        if (sampleDensity > 15) {
          // High density area - use tighter clustering
          clusterDistance = 30;
        } else if (sampleDensity < 5) {
          // Low density area - show individual properties
          clusterDistance = 10;
        }
      }
    }

    for (int i = 0; i < props.length; i++) {
      if (processed.contains(i)) continue;
      final p = props[i];
      if (p.latitude == null || p.longitude == null) continue;

      final group = [p];
      processed.add(i);

      for (int j = i + 1; j < props.length; j++) {
        if (processed.contains(j)) continue;
        final q = props[j];
        if (q.latitude == null || q.longitude == null) continue;

        final dist = _dist(p.latitude!, p.longitude!, q.latitude!, q.longitude!);
        if (dist < clusterDistance) { 
          group.add(q); 
          processed.add(j); 
        }
      }

      groups.add(_MarkerGroup(LatLng(p.latitude!, p.longitude!), group));
    }
    return groups;
  }

  /// Calculate actual distance between two points in meters (Haversine formula simplified)
  double _dist(double lat1, double lon1, double lat2, double lon2) {
    final dlat = (lat2 - lat1) * 111000; // 1 degree latitude ≈ 111km
    final dlon = (lon2 - lon1) * 111000 * cos((lat1 + lat2) / 2 * 0.0174533); // Adjust for longitude
    return sqrt(dlat * dlat + dlon * dlon); // Actual distance in meters
  }

  IconData _getPropertyIcon(String propertyType) {
    switch (propertyType.toLowerCase()) {
      case 'bedsitter':
        return Icons.single_bed;
      case 'studio':
        return Icons.meeting_room; // Different from apartment
      case 'apartment':
        return Icons.apartment;
      case 'house':
        return Icons.home;
      case 'office':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'warehouse':
        return Icons.warehouse;
      case 'land':
        return Icons.landscape;
      default:
        return Icons.location_on;
    }
  }

  bool _matchesFilter(Property p) {
    // Check pill filters (mobile quick filters)
    if (!_selectedTypes.contains('all') && !_selectedTypes.contains(p.propertyType)) {
      return false;
    }
    
    // Check advanced filters from filter panel
    if (_filterState.propertyTypes.isNotEmpty) {
      final normalizedType = p.propertyType.toLowerCase();
      final hasMatch = _filterState.propertyTypes.any((t) => t.toLowerCase() == normalizedType);
      if (!hasMatch) return false;
    }
    
    // Check availability
    if (_filterState.availableOnly && !p.available) return false;
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(mapSearchControllerProvider);
    final topPad = MediaQuery.of(context).padding.top;
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ────────────────────────────────────────────────────────────
          propertiesAsync.when(
            loading: () => _buildMap([], isWide),
            error: (_, __) => _buildMap([], isWide),
            data: (props) => _buildMap(props.where(_matchesFilter).toList(), isWide),
          ),

          // ── DISMISS SUGGESTIONS OVERLAY ────────────────────────────────────
          if (_showSuggestions && _suggestions.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() { 
                  _showSuggestions = false; 
                }),
                child: Container(color: Colors.transparent),
              ),
            ),

          // ── SEARCH BAR ─────────────────────────────────────────────────────
          Positioned(
            top: topPad + (isWide ? 8 : 24),
            left: 16, right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26), // Fully rounded pill
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search location...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) {
                            if (_suggestions.isNotEmpty) _selectSuggestion(_suggestions.first);
                          },
                          onTap: () {
                            // Show suggestions when tapping search bar if there's text
                            if (_searchCtrl.text.isNotEmpty && _suggestions.isNotEmpty) {
                              setState(() => _showSuggestions = true);
                            }
                          },
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() { 
                              _suggestions = []; 
                              _showSuggestions = false; 
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else
                        const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(width: 4),
                      // Filter button with active dot
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune, color: Color(0xFF374151), size: 22),
                            onPressed: () => setState(() => _showFilters = true),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(),
                          ),
                          if (_filterState != FilterState.empty)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── FILTER PILLS (mobile) ──────────────────────────────────────────
          if (!isWide)
            Positioned(
              top: topPad + 84, // Adjusted for new search bar height
              left: 0, right: 0,
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _PillData('all', 'All', Color(0xFF6366F1), Icons.apps),
                    _PillData('bedsitter', 'Bedsitters', Color(0xFFEF4444), Icons.single_bed),
                    _PillData('studio', 'Studios', Color(0xFF3B82F6), Icons.meeting_room),
                    _PillData('apartment', 'Apartments', Color(0xFF10B981), Icons.apartment),
                    _PillData('house', 'Houses', Color(0xFF8B5CF6), Icons.home),
                    _PillData('office', 'Offices', Color(0xFFF59E0B), Icons.business),
                  ].map((t) {
                    final selected = _selectedTypes.contains(t.key);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (t.key == 'all') { _selectedTypes = ['all']; return; }
                          _selectedTypes.remove('all');
                          selected ? _selectedTypes.remove(t.key) : _selectedTypes.add(t.key);
                          if (_selectedTypes.isEmpty) _selectedTypes = ['all'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF2563EB) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            t.icon, 
                            size: 16, 
                            color: selected ? Colors.white : t.color,
                          ),
                          const SizedBox(width: 6),
                          Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF374151))),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── SUGGESTIONS (below filter pills) ───────────────────────────────
          if (_showSuggestions && _suggestions.isNotEmpty)
            Positioned(
              top: topPad + 132, // Adjusted: search bar (52) + spacing (8) + pills (40) + spacing (8) + status bar padding
              left: 16, right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          return InkWell(
                            onTap: () => _selectSuggestion(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.location_on, size: 18, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (s['name'] as String).split(',').take(3).join(', '),
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── MAP CONTROLS ───────────────────────────────────────────────────
          Positioned(
            bottom: 100, right: 16,
            child: Column(
              children: [
                if (isWide) ...[
                  _MapBtn(icon: Icons.add, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                  const SizedBox(height: 6),
                  _MapBtn(icon: Icons.remove, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                  const SizedBox(height: 6),
                ],
                _MapBtn(icon: Icons.my_location, onTap: () {
                  if (_userLocation != null) _mapController.move(_userLocation!, 14);
                  else _getUserLocation();
                }, active: _userLocation != null, loading: _isLoadingLocation),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.layers_outlined, onTap: () => setState(() => _isSatellite = !_isSatellite), active: _isSatellite),
              ],
            ),
          ),

          // ── PROPERTY MODAL ─────────────────────────────────────────────────
          if (_selectedProperty != null)
            _PropertyModal(
              property: _selectedProperty!,
              onClose: () => setState(() => _selectedProperty = null),
              ref: ref,
            ),

          // ── CLUSTER GRID ───────────────────────────────────────────────────
          if (_clusterProperties != null)
            _ClusterGrid(
              properties: _clusterProperties!,
              onSelect: (p) => setState(() { _clusterProperties = null; _selectedProperty = p; }),
              onClose: () => setState(() => _clusterProperties = null),
            ),

          // ── FILTER PANEL ───────────────────────────────────────────────────
          if (_showFilters)
            Positioned.fill(
              child: FilterPanel(
                initial: _filterState,
                onApply: (state) {
                  setState(() { _filterState = state; _showFilters = false; });
                  ref.read(mapSearchContextProvider.notifier).update((s) => s.copyWith(
                    listingType: state.listingType,
                    minPrice: state.minPrice > 0 ? state.minPrice : null,
                    maxPrice: state.maxPrice < 500000 ? state.maxPrice : null,
                    maxDistanceKm: state.maxDistance,
                    clearDistance: state.maxDistance == null, // Clear distance if not set
                  ));
                  
                  // If distance filter is set, move map back to user location
                  if (state.maxDistance != null && _userLocation != null) {
                    // Calculate zoom level to show the radius
                    final radiusKm = state.maxDistance!;
                    double targetZoom = 14; // Default
                    
                    if (radiusKm <= 0.5) targetZoom = 16;      // 500m or less
                    else if (radiusKm <= 1) targetZoom = 15;   // 1km
                    else if (radiusKm <= 2) targetZoom = 14;   // 2km
                    else if (radiusKm <= 5) targetZoom = 13;   // 5km
                    else if (radiusKm <= 10) targetZoom = 12;  // 10km
                    else targetZoom = 11;                      // >10km
                    
                    _mapController.move(_userLocation!, targetZoom);
                  }
                },
                onClose: () => setState(() => _showFilters = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(List<Property> props, bool isWide) {
    final groups = _buildGroups(props);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _nairobiCenter,
        initialZoom: 12,
        onTap: (_, __) => setState(() { _selectedProperty = null; _clusterProperties = null; _showSuggestions = false; }),
        onMapEvent: (event) {
          // Track zoom level for smart clustering
          if (event is MapEventMove) {
            final newZoom = event.camera.zoom;
            if ((newZoom - _currentZoom).abs() > 0.5) {
              // Zoom changed significantly - update clustering
              _currentZoom = newZoom;
              _mapDebounce?.cancel();
              _mapDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() {}); // Rebuild with new cluster distance
              });
            }
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.openspot.app',
          maxNativeZoom: 19,
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            // Property markers
            ...groups.map((g) {
              if (g.properties.length == 1) {
                // Single property - modern pin design
                final p = g.properties.first;
                final color = _typeColors[p.propertyType] ?? _defaultMarkerColor;
                return Marker(
                  point: g.center,
                  width: 40, height: 48,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedProperty = p),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pin shadow
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 16,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        // Main pin
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  _getPropertyIcon(p.propertyType),
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Pin pointer
                            CustomPaint(
                              size: const Size(8, 8),
                              painter: _PinPointerPainter(color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Cluster - modern cluster design
                return Marker(
                  point: g.center,
                  width: 50, height: 58,
                  child: GestureDetector(
                    onTap: () => setState(() => _clusterProperties = g.properties),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cluster shadow
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 20,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Main cluster
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _defaultMarkerColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${g.properties.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Cluster pointer
                            CustomPaint(
                              size: const Size(10, 10),
                              painter: _PinPointerPainter(_defaultMarkerColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
            }),
            // User location - pulsing blue dot (like Google Maps)
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 40, height: 40,
                child: const _PulsingLocationDot(),
              ),
          ],
        ),
      ],
    );
  }
}

class _PillData {
  final String key, label;
  final Color color;
  final IconData icon;
  const _PillData(this.key, this.label, this.color, this.icon);
}

class _MarkerGroup {
  final LatLng center;
  final List<Property> properties;
  const _MarkerGroup(this.center, this.properties);
}

// ── MAP CONTROL BUTTON ────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool loading;
  const _MapBtn({required this.icon, required this.onTap, this.active = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD1D5DB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: loading 
            ? const SizedBox(
                width: 18, height: 18,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              )
            : Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF374151)),
      ),
    );
  }
}

// ── PROPERTY MODAL ────────────────────────────────────────────────────────────
// Slides up from bottom, image gallery, title, price, type, description, 3 buttons
class _PropertyModal extends ConsumerStatefulWidget {
  final Property property;
  final VoidCallback onClose;
  final WidgetRef ref;
  const _PropertyModal({required this.property, required this.onClose, required this.ref});

  @override
  ConsumerState<_PropertyModal> createState() => _PropertyModalState();
}

class _PropertyModalState extends ConsumerState<_PropertyModal> {
  int _imgIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final user = ref.watch(currentUserProvider);
    final isFav = ref.watch(isFavoriteProvider(p.id));
    final images = p.images.isNotEmpty ? p.images : (p.thumbnailUrl != null ? [p.thumbnailUrl!] : <String>[]);

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9, maxWidth: 576),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── IMAGE GALLERY ──
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: SizedBox(
                            height: 256,
                            width: double.infinity,
                            child: images.isEmpty
                                ? Container(color: const Color(0xFFE5E7EB), child: const Icon(Icons.home, size: 60, color: Color(0xFF9CA3AF)))
                                : PageView.builder(
                                    itemCount: images.length,
                                    onPageChanged: (i) => setState(() => _imgIndex = i),
                                    itemBuilder: (_, i) => CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        // Action buttons top-right
                        Positioned(
                          top: 12, right: 12,
                          child: Row(children: [
                            _CircleBtn(
                              icon: isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : null,
                              onTap: () {
                                if (user == null) { context.push('/signin'); return; }
                                ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
                              },
                            ),
                            const SizedBox(width: 8),
                            _CircleBtn(icon: Icons.close, onTap: widget.onClose),
                          ]),
                        ),
                        // Image counter
                        if (images.length > 1)
                          Positioned(
                            bottom: 10, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: Text('${_imgIndex + 1} / ${images.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        // Dots
                        if (images.length > 1)
                          Positioned(
                            bottom: 10, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: i == _imgIndex ? Colors.white : Colors.white54,
                                  shape: BoxShape.circle,
                                ),
                              )),
                            ),
                          ),
                      ],
                    ),

                    // ── DETAILS ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            const SizedBox(height: 8),
                            // Price + type + rating row
                            Wrap(spacing: 16, children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.attach_money, size: 16, color: Color(0xFF6366F1)),
                                Text('${p.formattedPrice} / month', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6366F1), fontSize: 14)),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.bed_outlined, size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 4),
                                Text(p.propertyType.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                              ]),
                            ]),
                            const SizedBox(height: 8),
                            if (p.description != null && p.description!.isNotEmpty) ...[
                              Text(p.description!, style: const TextStyle(color: Color(0xFF374151), fontSize: 13, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                            ],
                            Row(children: [
                              const Icon(Icons.location_on, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(p.location, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 16),
                            // Buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () { widget.onClose(); context.push('/property/${p.id}'); },
                                icon: const Icon(Icons.info_outline, size: 18),
                                label: const Text('See Full Details'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (p.landlordPhone != null)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => launchUrl(Uri.parse('tel:${p.landlordPhone}')),
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: Text('Call ${p.landlordPhone}'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (p.latitude != null && p.longitude != null)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}'), mode: LaunchMode.externalApplication),
                                  icon: const Icon(Icons.navigation, size: 18),
                                  label: const Text('Navigate to Property'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
        child: Icon(icon, size: 20, color: color ?? const Color(0xFF374151)),
      ),
    );
  }
}

// ── CLUSTER GRID ──────────────────────────────────────────────────────────────
// Modal overlay showing all properties in a cluster as a grid
class _ClusterGrid extends StatelessWidget {
  final List<Property> properties;
  final void Function(Property) onSelect;
  final VoidCallback onClose;
  const _ClusterGrid({required this.properties, required this.onSelect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final cols = isWide ? (properties.length <= 5 ? properties.length : 5) : 2;

    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 960, maxHeight: 600),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24)]),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                      child: Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${properties.length} Properties Available in this Area', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            Text(properties.first.location, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ])),
                          IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Color(0xFF374151))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Grid
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: properties.length,
                          itemBuilder: (_, i) {
                            final p = properties[i];
                            final img = p.firstImage;
                            return GestureDetector(
                              onTap: () => onSelect(p),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: img != null
                                          ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity)
                                          : Container(color: const Color(0xFFE5E7EB), child: const Icon(Icons.home, color: Color(0xFF9CA3AF))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF111827)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          Text('KSh ${(p.price / 1000).toStringAsFixed(1)}K', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                                          Row(children: [
                                            const Icon(Icons.visibility, size: 12, color: Color(0xFF6B7280)),
                                            Text(' ${p.views}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                          ]),
                                        ]),
                                      ]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ── PIN POINTER PAINTER ───────────────────────────────────────────────────────
class _PinPointerPainter extends CustomPainter {
  final Color color;
  
  _PinPointerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── PULSING LOCATION DOT ──────────────────────────────────────────────────────
class _PulsingLocationDot extends StatefulWidget {
  const _PulsingLocationDot();

  @override
  State<_PulsingLocationDot> createState() => _PulsingLocationDotState();
}

class _PulsingLocationDotState extends State<_PulsingLocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: false);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing outer circle
            Container(
              width: 40 * _animation.value,
              height: 40 * _animation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withOpacity(0.3 * (1 - _animation.value)),
              ),
            ),
            // Middle circle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withOpacity(0.3),
              ),
            ),
            // Inner dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}