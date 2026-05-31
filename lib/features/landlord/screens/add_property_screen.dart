import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _sizeController = TextEditingController();
  final _amenitiesController = TextEditingController();

  String _propertyType = 'apartment';
  String _furnishingStatus = 'unfurnished';
  bool _isAvailable = true;
  bool _isUploading = false;
  bool _isGettingLocation = false;
  List<File> _selectedImages = [];
  double? _latitude;
  double? _longitude;
  String? _currentLocationText;

  final List<String> _propertyTypes = [
    'apartment',
    'studio',
    'bedsitter',
    'single_room',
    'shared_room',
    'hostel',
    'house',
  ];

  final List<String> _furnishingOptions = [
    'unfurnished',
    'semi_furnished',
    'fully_furnished',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Property'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Property Images
            _buildImageSection(),
            const SizedBox(height: 24),

            // Basic Information
            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Property Title *',
                hintText: 'e.g., Modern 2BR Apartment near USIU',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Property title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _propertyType,
              decoration: const InputDecoration(
                labelText: 'Property Type *',
              ),
              items: _propertyTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_formatPropertyType(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _propertyType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Monthly Rent (KES) *',
                hintText: '15000',
                prefixText: 'KES ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Price is required';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Location
            _buildSectionTitle('Location'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Area/Neighborhood *',
                hintText: 'e.g., Kasarani, Thika Road',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Location is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Full Address',
                hintText: 'Street address, building name, etc.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Live Location Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Property Location',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_currentLocationText != null) ...[
                    Text(
                      _currentLocationText!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isGettingLocation
                        ? 'Getting location...'
                        : _latitude != null
                            ? 'Update location'
                            : 'Get my location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _latitude != null ? Colors.green : null,
                    ),
                  ),
                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Location captured: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Property Details
            _buildSectionTitle('Property Details'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bedroomsController,
                    decoration: const InputDecoration(
                      labelText: 'Bedrooms',
                      hintText: '2',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _bathroomsController,
                    decoration: const InputDecoration(
                      labelText: 'Bathrooms',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Size (sq ft)',
                hintText: '800',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _furnishingStatus,
              decoration: const InputDecoration(
                labelText: 'Furnishing Status',
              ),
              items: _furnishingOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_formatFurnishingStatus(status)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _furnishingStatus = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // Description & Amenities
            _buildSectionTitle('Description & Amenities'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe your property, nearby amenities, transport links...',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amenitiesController,
              decoration: const InputDecoration(
                labelText: 'Amenities',
                hintText: 'WiFi, Parking, Security, Water, Electricity...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Availability
            _buildSectionTitle('Availability'),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Available for Rent'),
              subtitle: Text(_isAvailable ? 'Property is available' : 'Property is not available'),
              value: _isAvailable,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isUploading ? null : _submitProperty,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Uploading...'),
                      ],
                    )
                  : const Text('List Property'),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Photos'),
        const SizedBox(height: 8),
        const Text(
          'Add at least 3 photos to attract more tenants',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add Photo Button
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 32, color: AppTheme.textMuted),
                      SizedBox(height: 4),
                      Text('Add Photos', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              
              // Selected Images
              ..._selectedImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                
                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    final user = ref.read(currentUserProvider);
    if (user == null) return [];

    final uploadedUrls = <String>[];

    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final path = 'property_images/$fileName';

      try {
        await Supabase.instance.client.storage
            .from('property-images')
            .upload(path, image);

        final url = Supabase.instance.client.storage
            .from('property-images')
            .getPublicUrl(path);

        uploadedUrls.add(url);
      } catch (e) {
        debugPrint('Image upload error: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please allow location access to use this feature.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location access in your device settings.');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _currentLocationText = 'Location captured successfully';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture the property location using "Get my location"')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('Please log in to list a property');
      }

      // Upload images
      final imageUrls = await _uploadImages();
      if (imageUrls.isEmpty) {
        throw Exception('Failed to upload images. Please try again.');
      }

      // Get landlord info
      final profile = await ref.read(currentProfileProvider.future);
      final landlordName = user.userMetadata?['full_name'] as String? ?? 
                          profile?['full_name'] as String? ?? 
                          'Landlord';
      final landlordPhone = profile?['phone'] as String? ?? '';

      // Create property data matching database schema
      final propertyData = {
        'landlord_id': user.id,
        'landlord_name': landlordName,
        'landlord_phone': landlordPhone,
        'landlord_email': user.email,
        'landlord_verified': profile?['phone_verified'] == true,
        
        // Basic info
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'property_type': _propertyType,
        'category': 'residential', // Default for rental properties
        'listing_type': 'rent', // Default for rental properties
        
        // Location with coordinates
        'location': _locationController.text.trim(),
        'address': _addressController.text.trim(),
        'city': 'Nairobi', // Default
        'latitude': _latitude,
        'longitude': _longitude,
        
        // Pricing
        'price': int.parse(_priceController.text.trim()),
        'currency': 'KES',
        
        // Details
        'bedrooms': int.tryParse(_bedroomsController.text.trim()),
        'bathrooms': int.tryParse(_bathroomsController.text.trim()),
        'area': int.tryParse(_sizeController.text.trim())?.toDouble(),
        
        // Features - convert amenities string to JSON array
        'amenities': _amenitiesController.text.trim().isEmpty 
            ? [] 
            : _amenitiesController.text.trim().split(',').map((e) => e.trim()).toList(),
        
        // Media
        'images': imageUrls,
        'thumbnail_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        
        // Availability
        'available': _isAvailable,
        'status': 'active',
        'verified': false,
        'featured': false,
        
        // Analytics
        'views': 0,
        'likes': 0,
      };

      await Supabase.instance.client
          .from('properties')
          .insert(propertyData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property listed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/landlord');
      }
    } catch (e) {
      String errorMessage = 'Failed to list property. Please try again.';
      
      // Handle specific database errors with user-friendly messages
      if (e.toString().contains('duplicate key')) {
        errorMessage = 'A property with this information already exists.';
      } else if (e.toString().contains('foreign key')) {
        errorMessage = 'Please complete your profile before listing a property.';
      } else if (e.toString().contains('check constraint')) {
        errorMessage = 'Please check that all information is valid and try again.';
      } else if (e.toString().contains('not-null')) {
        errorMessage = 'Please fill in all required fields.';
      }
      
      // Log the actual error for debugging
      debugPrint('Property listing error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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

  String _formatFurnishingStatus(String status) {
    switch (status) {
      case 'unfurnished':
        return 'Unfurnished';
      case 'semi_furnished':
        return 'Semi Furnished';
      case 'fully_furnished':
        return 'Fully Furnished';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _sizeController.dispose();
    _amenitiesController.dispose();
    super.dispose();
  }
}