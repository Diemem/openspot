import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/saved_searches_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SearchFilterDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialFilters;
  final bool showSaveOption;
  final String? savedSearchName;

  const SearchFilterDialog({
    super.key,
    this.initialFilters,
    this.showSaveOption = true,
    this.savedSearchName,
  });

  @override
  ConsumerState<SearchFilterDialog> createState() => _SearchFilterDialogState();
}

class _SearchFilterDialogState extends ConsumerState<SearchFilterDialog> {
  final _searchNameController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _locationController = TextEditingController();
  
  String? _selectedPropertyType;
  int? _selectedBedrooms;
  int? _selectedBathrooms;
  bool _enableNotifications = true;
  bool _isLoading = false;

  final List<String> _propertyTypes = [
    'apartment',
    'studio',
    'bedsitter',
    'single_room',
    'shared_room',
    'hostel',
    'house',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromFilters();
  }

  void _initializeFromFilters() {
    if (widget.initialFilters != null) {
      final filters = widget.initialFilters!;
      _locationController.text = filters['location']?.toString() ?? '';
      _selectedPropertyType = filters['property_type']?.toString();
      _minPriceController.text = filters['min_price']?.toString() ?? '';
      _maxPriceController.text = filters['max_price']?.toString() ?? '';
      _selectedBedrooms = filters['bedrooms'] as int?;
      _selectedBathrooms = filters['bathrooms'] as int?;
    }
    
    if (widget.savedSearchName != null) {
      _searchNameController.text = widget.savedSearchName!;
    }
  }

  Map<String, dynamic> _buildFilters() {
    final filters = <String, dynamic>{};
    
    if (_locationController.text.isNotEmpty) {
      filters['location'] = _locationController.text.trim();
    }
    if (_selectedPropertyType != null) {
      filters['property_type'] = _selectedPropertyType;
    }
    if (_minPriceController.text.isNotEmpty) {
      final minPrice = int.tryParse(_minPriceController.text);
      if (minPrice != null) filters['min_price'] = minPrice;
    }
    if (_maxPriceController.text.isNotEmpty) {
      final maxPrice = int.tryParse(_maxPriceController.text);
      if (maxPrice != null) filters['max_price'] = maxPrice;
    }
    if (_selectedBedrooms != null) {
      filters['bedrooms'] = _selectedBedrooms;
    }
    if (_selectedBathrooms != null) {
      filters['bathrooms'] = _selectedBathrooms;
    }
    
    return filters;
  }

  Future<void> _saveSearch() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save searches')),
      );
      return;
    }

    final name = _searchNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(savedSearchesNotifierProvider.notifier).saveSearch(
        name: name,
        filters: _buildFilters(),
        enableNotifications: _enableNotifications,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving search: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _searchNow() {
    final filters = _buildFilters();
    final queryParams = <String, String>{};
    
    // Convert filters to query parameters
    filters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParams[key] = value.toString();
      }
    });
    
    // Navigate to explore screen with filters
    Navigator.pop(context);
    final uri = Uri(path: '/explore', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Search Properties',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Westlands, Kasarani, CBD',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Property Type
                    const Text(
                      'Property Type',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPropertyType,
                      decoration: const InputDecoration(
                        hintText: 'Any property type',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any property type'),
                        ),
                        ..._propertyTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_formatPropertyType(type)),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPropertyType = value);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Price Range
                    const Text(
                      'Price Range (KES)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Min price',
                              prefixText: 'KES ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('to'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Max price',
                              prefixText: 'KES ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bedrooms & Bathrooms
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bedrooms',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedBedrooms,
                                decoration: const InputDecoration(
                                  hintText: 'Any',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Any')),
                                  ...List.generate(5, (i) => i + 1).map((num) => 
                                    DropdownMenuItem(value: num, child: Text('$num')),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedBedrooms = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bathrooms',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedBathrooms,
                                decoration: const InputDecoration(
                                  hintText: 'Any',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Any')),
                                  ...List.generate(4, (i) => i + 1).map((num) => 
                                    DropdownMenuItem(value: num, child: Text('$num')),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedBathrooms = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Save Search Section
                    if (widget.showSaveOption) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Save This Search',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchNameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g., 2BR in Westlands',
                          prefixIcon: Icon(Icons.bookmark),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Enable notifications'),
                        subtitle: const Text('Get notified when new properties match this search'),
                        value: _enableNotifications,
                        onChanged: (value) {
                          setState(() => _enableNotifications = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _searchNow,
                      child: const Text('Search Now'),
                    ),
                  ),
                  if (widget.showSaveOption) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSearch,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save & Search'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPropertyType(String type) {
    switch (type) {
      case 'apartment':
        return 'Apartment';
      case 'studio':
        return 'Studio';
      case 'bedsitter':
        return 'Bedsitter';
      case 'single_room':
        return 'Single Room';
      case 'shared_room':
        return 'Shared Room';
      case 'hostel':
        return 'Hostel';
      case 'house':
        return 'House';
      default:
        return type;
    }
  }

  @override
  void dispose() {
    _searchNameController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}