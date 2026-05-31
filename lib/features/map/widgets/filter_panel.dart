import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── DATA ─────────────────────────────────────────────────────────────────────

const _categories = [
  _Cat('residential', 'Residential', Icons.home_outlined),
  _Cat('commercial', 'Commercial', Icons.store_outlined),
  _Cat('industrial', 'Industrial', Icons.warehouse_outlined),
  _Cat('agricultural', 'Agricultural', Icons.grass_outlined),
  _Cat('land', 'Land', Icons.landscape_outlined),
];

const _filters = {
  'residential': _CatFilters(
    types: ['Apartment', 'House', 'Studio', 'Bedsitter', 'Villa', 'Townhouse'],
    bedrooms: ['Studio', '1', '2', '3', '4', '5+'],
    bathrooms: ['1', '2', '3', '4+'],
    amenities: ['WiFi', 'Parking', 'Security', 'Water', 'Electricity', 'Generator', 'Gym', 'Pool', 'Garden', 'Balcony'],
    furnishing: ['Furnished', 'Semi-Furnished', 'Unfurnished'],
  ),
  'commercial': _CatFilters(
    types: ['Office', 'Shop', 'Restaurant', 'Showroom', 'Mall Space', 'Co-working'],
    amenities: ['Parking', 'Security', 'WiFi', 'AC', 'Elevator', 'Reception', 'Conference Room', 'Kitchen'],
  ),
  'industrial': _CatFilters(
    types: ['Warehouse', 'Factory', 'Workshop', 'Storage', 'Manufacturing Unit'],
    amenities: ['Loading Dock', 'High Ceiling', 'Power Backup', 'Security', 'Office Space', 'Parking'],
  ),
  'agricultural': _CatFilters(
    types: ['Farm', 'Plantation', 'Ranch', 'Greenhouse', 'Orchard'],
    amenities: ['Water Source', 'Irrigation', 'Electricity', 'Road Access', 'Fenced', 'Buildings'],
  ),
  'land': _CatFilters(
    types: ['Residential Plot', 'Commercial Plot', 'Agricultural Land', 'Mixed Use'],
    amenities: ['Title Deed', 'Fenced', 'Road Access', 'Electricity', 'Water', 'Flat Terrain'],
  ),
};

const _pricePresets = [
  _Preset('Under 10K', 0, 10000),
  _Preset('10K–20K', 10000, 20000),
  _Preset('20K–30K', 20000, 30000),
  _Preset('30K–50K', 30000, 50000),
  _Preset('50K+', 50000, 500000),
];

class _Cat {
  final String id, label;
  final IconData icon;
  const _Cat(this.id, this.label, this.icon);
}

class _CatFilters {
  final List<String> types;
  final List<String> bedrooms;
  final List<String> bathrooms;
  final List<String> amenities;
  final List<String> furnishing;
  const _CatFilters({
    this.types = const [],
    this.bedrooms = const [],
    this.bathrooms = const [],
    this.amenities = const [],
    this.furnishing = const [],
  });
}

class _Preset {
  final String label;
  final double min, max;
  const _Preset(this.label, this.min, this.max);
}

// ── FILTER STATE ──────────────────────────────────────────────────────────────

class FilterState {
  final String listingType;
  final double minPrice;
  final double maxPrice;
  final List<String> propertyTypes;
  final List<String> bedrooms;
  final List<String> bathrooms;
  final List<String> amenities;
  final List<String> furnishing;
  final bool availableOnly;
  final double? maxDistance; // in kilometers
  final String distanceUnit; // 'km' or 'm'

  const FilterState({
    this.listingType = 'rent',
    this.minPrice = 0,
    this.maxPrice = 100000,
    this.propertyTypes = const [],
    this.bedrooms = const [],
    this.bathrooms = const [],
    this.amenities = const [],
    this.furnishing = const [],
    this.availableOnly = false,
    this.maxDistance,
    this.distanceUnit = 'km',
  });

  FilterState copyWith({
    String? listingType,
    double? minPrice,
    double? maxPrice,
    List<String>? propertyTypes,
    List<String>? bedrooms,
    List<String>? bathrooms,
    List<String>? amenities,
    List<String>? furnishing,
    bool? availableOnly,
    double? maxDistance,
    String? distanceUnit,
  }) => FilterState(
    listingType: listingType ?? this.listingType,
    minPrice: minPrice ?? this.minPrice,
    maxPrice: maxPrice ?? this.maxPrice,
    propertyTypes: propertyTypes ?? this.propertyTypes,
    bedrooms: bedrooms ?? this.bedrooms,
    bathrooms: bathrooms ?? this.bathrooms,
    amenities: amenities ?? this.amenities,
    furnishing: furnishing ?? this.furnishing,
    availableOnly: availableOnly ?? this.availableOnly,
    maxDistance: maxDistance,
    distanceUnit: distanceUnit ?? this.distanceUnit,
  );

  static const empty = FilterState();
  
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          listingType == other.listingType &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          maxDistance == other.maxDistance &&
          distanceUnit == other.distanceUnit &&
          availableOnly == other.availableOnly;

  @override
  int get hashCode => Object.hash(listingType, minPrice, maxPrice, maxDistance, distanceUnit, availableOnly);
}

// ── PANEL ─────────────────────────────────────────────────────────────────────

class FilterPanel extends StatefulWidget {
  final FilterState initial;
  final void Function(FilterState) onApply;
  final VoidCallback onClose;

  const FilterPanel({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late FilterState _state;
  String _activeCategory = 'residential';
  bool _showAllTypes = false;
  bool _showAllAmenities = false;
  final TextEditingController _distanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    if (_state.maxDistance != null) {
      _distanceController.text = _state.maxDistance!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  _CatFilters get _cf => _filters[_activeCategory]!;

  void _toggle(List<String> list, String item, void Function(List<String>) update) {
    final next = List<String>.from(list);
    next.contains(item) ? next.remove(item) : next.add(item);
    update(next);
  }

  void _reset() => setState(() { 
    _state = FilterState.empty; 
    _showAllTypes = false; 
    _showAllAmenities = false; 
    _distanceController.clear();
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92, maxWidth: 896),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // ── HEADER ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    child: Row(
                      children: [
                        const Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        const Spacer(),
                        IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, size: 24)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── CATEGORY TABS ──
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = _categories[i];
                        final active = _activeCategory == c.id;
                        return GestureDetector(
                          onTap: () => setState(() { _activeCategory = c.id; _showAllTypes = false; _showAllAmenities = false; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(c.icon, size: 16, color: active ? Colors.white : const Color(0xFF374151)),
                              const SizedBox(width: 6),
                              Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF374151))),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),

                  // ── SCROLLABLE CONTENT ──
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Listing type
                          _Section(title: 'Listing Type', child: Row(children: [
                            _TypeBtn(label: 'For Rent', active: _state.listingType == 'rent', onTap: () => setState(() => _state = _state.copyWith(listingType: 'rent'))),
                            const SizedBox(width: 12),
                            _TypeBtn(label: 'For Sale', active: _state.listingType == 'sale', onTap: () => setState(() => _state = _state.copyWith(listingType: 'sale'))),
                          ])),

                          // Distance filter
                          _Section(title: 'Distance from Your Location', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  controller: _distanceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter distance',
                                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  onChanged: (value) {
                                    final distance = double.tryParse(value);
                                    if (distance != null && distance > 0) {
                                      // Convert to km if in meters
                                      final distanceInKm = _state.distanceUnit == 'm' ? distance / 1000 : distance;
                                      setState(() => _state = _state.copyWith(maxDistance: distanceInKm));
                                    } else if (value.isEmpty) {
                                      setState(() => _state = _state.copyWith(maxDistance: null));
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Unit selector
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _state = _state.copyWith(distanceUnit: 'km');
                                        // Convert current value if exists
                                        if (_distanceController.text.isNotEmpty) {
                                          final currentValue = double.tryParse(_distanceController.text);
                                          if (currentValue != null) {
                                            // Was in meters, convert to km
                                            final kmValue = currentValue / 1000;
                                            _distanceController.text = kmValue.toStringAsFixed(1);
                                            _state = _state.copyWith(maxDistance: kmValue);
                                          }
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _state.distanceUnit == 'km' ? const Color(0xFF2563EB) : Colors.white,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), bottomLeft: Radius.circular(7)),
                                      ),
                                      child: Text('km', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _state.distanceUnit == 'km' ? Colors.white : const Color(0xFF374151))),
                                    ),
                                  ),
                                  Container(width: 1, height: 20, color: const Color(0xFFE5E7EB)),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _state = _state.copyWith(distanceUnit: 'm');
                                        // Convert current value if exists
                                        if (_distanceController.text.isNotEmpty) {
                                          final currentValue = double.tryParse(_distanceController.text);
                                          if (currentValue != null) {
                                            // Was in km, convert to meters
                                            final mValue = currentValue * 1000;
                                            _distanceController.text = mValue.toStringAsFixed(0);
                                            _state = _state.copyWith(maxDistance: currentValue); // Keep in km internally
                                          }
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _state.distanceUnit == 'm' ? const Color(0xFF2563EB) : Colors.white,
                                        borderRadius: const BorderRadius.only(topRight: Radius.circular(7), bottomRight: Radius.circular(7)),
                                      ),
                                      child: Text('m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _state.distanceUnit == 'm' ? Colors.white : const Color(0xFF374151))),
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              _state.maxDistance != null 
                                  ? 'Showing properties within ${_state.distanceUnit == 'km' ? '${_state.maxDistance!.toStringAsFixed(1)} km' : '${(_state.maxDistance! * 1000).toStringAsFixed(0)} m'} radius'
                                  : 'No distance filter applied',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ])),

                          // Price
                          _Section(title: 'Price Range', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Presets
                            Wrap(spacing: 8, runSpacing: 8, children: _pricePresets.map((p) {
                              final active = _state.minPrice == p.min && _state.maxPrice == p.max;
                              return GestureDetector(
                                onTap: () => setState(() => _state = _state.copyWith(minPrice: p.min, maxPrice: p.max)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active ? const Color(0xFFEFF6FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB), width: active ? 2 : 1),
                                  ),
                                  child: Text(p.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? const Color(0xFF2563EB) : const Color(0xFF374151))),
                                ),
                              );
                            }).toList()),
                            const SizedBox(height: 16),
                            // Min/Max display
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('KSh ${_state.minPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('KSh ${_state.maxPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ]),
                            const SizedBox(height: 8),
                            // Min slider
                            _SliderRow(label: 'Min', value: _state.minPrice, min: 0, max: 500000, onChanged: (v) {
                              if (v <= _state.maxPrice) setState(() => _state = _state.copyWith(minPrice: v));
                            }),
                            // Max slider
                            _SliderRow(label: 'Max', value: _state.maxPrice, min: 0, max: 500000, onChanged: (v) {
                              if (v >= _state.minPrice) setState(() => _state = _state.copyWith(maxPrice: v));
                            }),
                          ])),

                          // Property types
                          if (_cf.types.isNotEmpty)
                            _Section(title: 'Property Type', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _ChipGrid(
                                items: _showAllTypes ? _cf.types : _cf.types.take(6).toList(),
                                selected: _state.propertyTypes,
                                onToggle: (v) => setState(() => _toggle(_state.propertyTypes, v.toLowerCase(), (l) => _state = _state.copyWith(propertyTypes: l))),
                              ),
                              if (_cf.types.length > 6)
                                TextButton(
                                  onPressed: () => setState(() => _showAllTypes = !_showAllTypes),
                                  child: Text(_showAllTypes ? '− Show Less' : '+ Show ${_cf.types.length - 6} More', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
                                ),
                            ])),

                          // Bedrooms (residential only)
                          if (_activeCategory == 'residential' && _cf.bedrooms.isNotEmpty)
                            _Section(title: 'Bedrooms', child: _ChipGrid(
                              items: _cf.bedrooms,
                              selected: _state.bedrooms,
                              onToggle: (v) => setState(() => _toggle(_state.bedrooms, v, (l) => _state = _state.copyWith(bedrooms: l))),
                            )),

                          // Bathrooms (residential only)
                          if (_activeCategory == 'residential' && _cf.bathrooms.isNotEmpty)
                            _Section(title: 'Bathrooms', child: _ChipGrid(
                              items: _cf.bathrooms,
                              selected: _state.bathrooms,
                              onToggle: (v) => setState(() => _toggle(_state.bathrooms, v, (l) => _state = _state.copyWith(bathrooms: l))),
                            )),

                          // Furnishing (residential only)
                          if (_activeCategory == 'residential' && _cf.furnishing.isNotEmpty)
                            _Section(title: 'Furnishing', child: _ChipGrid(
                              items: _cf.furnishing,
                              selected: _state.furnishing,
                              onToggle: (v) => setState(() => _toggle(_state.furnishing, v, (l) => _state = _state.copyWith(furnishing: l))),
                            )),

                          // Amenities
                          if (_cf.amenities.isNotEmpty)
                            _Section(title: 'Amenities', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _ChipGrid(
                                items: _showAllAmenities ? _cf.amenities : _cf.amenities.take(6).toList(),
                                selected: _state.amenities,
                                onToggle: (v) => setState(() => _toggle(_state.amenities, v, (l) => _state = _state.copyWith(amenities: l))),
                              ),
                              if (_cf.amenities.length > 6)
                                TextButton(
                                  onPressed: () => setState(() => _showAllAmenities = !_showAllAmenities),
                                  child: Text(_showAllAmenities ? '− Show Less' : '+ Show ${_cf.amenities.length - 6} More', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
                                ),
                            ])),

                          // Availability
                          _Section(title: 'Availability', child: Row(children: [
                            Checkbox(
                              value: _state.availableOnly,
                              onChanged: (v) => setState(() => _state = _state.copyWith(availableOnly: v ?? false)),
                              activeColor: const Color(0xFF2563EB),
                            ),
                            const Text('Show only available properties', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                          ])),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER ──
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Reset All', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w500, fontSize: 15)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () { widget.onApply(_state); widget.onClose(); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Apply Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF374151))),
        ),
      ),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  final List<String> items;
  final List<String> selected;
  final void Function(String) onToggle;
  const _ChipGrid({required this.items, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final active = selected.contains(item.toLowerCase()) || selected.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB), width: active ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (active) ...[
                const Icon(Icons.check, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
              ],
              Text(item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? const Color(0xFF2563EB) : const Color(0xFF374151))),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final void Function(double) onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 32, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: 100,
          activeColor: const Color(0xFF2563EB),
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}
