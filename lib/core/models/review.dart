class Review {
  final String id;
  final String propertyId;
  final String userId;
  final int rating;
  final String? title;
  final String? comment;
  final int? cleanlinessRating;
  final int? locationRating;
  final int? valueRating;
  final int? landlordRating;
  final bool isAnonymous;
  final bool verifiedTenant;
  final int helpfulCount;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.rating,
    this.title,
    this.comment,
    this.cleanlinessRating,
    this.locationRating,
    this.valueRating,
    this.landlordRating,
    this.isAnonymous = false,
    this.verifiedTenant = false,
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    propertyId: json['property_id'] as String,
    userId: json['user_id'] as String,
    rating: json['rating'] as int,
    title: json['title'] as String?,
    comment: json['comment'] as String?,
    cleanlinessRating: json['cleanliness_rating'] as int?,
    locationRating: json['location_rating'] as int?,
    valueRating: json['value_rating'] as int?,
    landlordRating: json['landlord_rating'] as int?,
    isAnonymous: json['is_anonymous'] as bool? ?? false,
    verifiedTenant: json['verified_tenant'] as bool? ?? false,
    helpfulCount: json['helpful_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
