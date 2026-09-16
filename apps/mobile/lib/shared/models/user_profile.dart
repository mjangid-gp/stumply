class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.phone,
    this.photoUrl,
    this.city = '',
    this.bio = '',
    this.battingStyle = 'right',
    this.bowlingStyle = 'none',
    this.role = 'player',
    this.isPro = false,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String city;
  final String bio;
  final String battingStyle;
  final String bowlingStyle;
  final String role;
  final bool isPro;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      displayName: data['displayName'] as String? ?? 'Player',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      city: data['city'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      battingStyle: data['battingStyle'] as String? ?? 'right',
      bowlingStyle: data['bowlingStyle'] as String? ?? 'none',
      role: data['role'] as String? ?? 'player',
      isPro: data['isPro'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'city': city,
        'bio': bio,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        'role': role,
        'isPro': isPro,
        'searchTerms': [displayName.toLowerCase(), city.toLowerCase()],
      };

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    bool clearPhoto = false,
    String? city,
    String? bio,
    String? battingStyle,
    String? bowlingStyle,
    bool? isPro,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      phone: phone,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      city: city ?? this.city,
      bio: bio ?? this.bio,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      role: role,
      isPro: isPro ?? this.isPro,
      createdAt: createdAt,
    );
  }
}
