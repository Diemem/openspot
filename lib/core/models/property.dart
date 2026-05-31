class Property {
  final String id;
  final String title;
  final String? description;
  final String propertyType;
  final String category;
  final String listingType;
  final String location;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? neighborhood;
  final String city;
  final double price;
  final String currency;
  final double? deposit;
  final int? bedrooms;
  final int? bathrooms;
  final double? area;
  final int? floorNumber;
  final int? parkingSpaces;
  final List<String> amenities;
  final List<String> utilitiesIncluded;
  final List<String> images;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordEmail;
  final bool landlordVerified;
  final bool available;
  final String? availableFrom;
  final String? leaseDuration;
  final String status;
  final bool verified;
  final bool featured;
  final int views;
  final int likes;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.title,
    this.description,
    required this.propertyType,
    required this.category,
    required this.listingType,
    required this.location,
    this.address,
    this.latitude,
    this.longitude,
    this.neighborhood,
    this.city = 'Nairobi',
    required this.price,
    this.currency = 'KES',
    this.deposit,
    this.bedrooms,
    this.bathrooms,
    this.area,
    this.floorNumber,
    this.parkingSpaces,
    this.amenities = const [],
    this.utilitiesIncluded = const [],
    this.images = const [],
    this.thumbnailUrl,
    this.videoUrl,
    this.landlordName,
    this.landlordPhone,
    this.landlordEmail,
    this.landlordVerified = false,
    this.available = true,
    this.availableFrom,
    this.leaseDuration,
    this.status = 'active',
    this.verified = false,
    this.featured = false,
    this.views = 0,
    this.likes = 0,
    required this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    // Safe integer parsing that handles both int and double from database
    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    // Safe double parsing
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return Property(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      propertyType: json['property_type'] as String,
      category: json['category'] as String,
      listingType: json['listing_type'] as String,
      location: json['location'] as String,
      address: json['address'] as String?,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String? ?? 'Nairobi',
      price: parseDouble(json['price']) ?? 0.0,
      currency: json['currency'] as String? ?? 'KES',
      deposit: parseDouble(json['deposit']),
      bedrooms: parseInt(json['bedrooms']),
      bathrooms: parseInt(json['bathrooms']),
      area: parseDouble(json['area']),
      floorNumber: parseInt(json['floor_number']),
      parkingSpaces: parseInt(json['parking_spaces']),
      amenities: parseList(json['amenities']),
      utilitiesIncluded: parseList(json['utilities_included']),
      images: parseList(json['images']),
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoUrl: json['video_url'] as String?,
      landlordName: json['landlord_name'] as String?,
      landlordPhone: json['landlord_phone'] as String?,
      landlordEmail: json['landlord_email'] as String?,
      landlordVerified: json['landlord_verified'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      availableFrom: json['available_from'] as String?,
      leaseDuration: json['lease_duration'] as String?,
      status: json['status'] as String? ?? 'active',
      verified: json['verified'] as bool? ?? false,
      featured: json['featured'] as bool? ?? false,
      views: parseInt(json['views']) ?? 0,
      likes: parseInt(json['likes']) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'KSh $formatted';
  }

  String? get firstImage => images.isNotEmpty ? images.first : thumbnailUrl;
}
