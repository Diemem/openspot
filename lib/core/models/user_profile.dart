class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final Map<String, dynamic> profiles;
  final String? activeProfile;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.profiles = const {},
    this.activeProfile,
  });

  bool get isLandlord => profiles.containsKey('landlord');
  bool get isAgency => profiles.containsKey('agency');
  bool get isRoommateSeeking => profiles.containsKey('roommate-seeker');

  factory UserProfile.fromSupabase(Map<String, dynamic> meta, String id, String email) {
    return UserProfile(
      id: id,
      email: email,
      fullName: meta['full_name'] as String?,
      avatarUrl: meta['avatar_url'] as String?,
      phone: meta['phone'] as String?,
      profiles: (meta['profiles'] as Map<String, dynamic>?) ?? {},
      activeProfile: meta['active_profile'] as String?,
    );
  }
}
