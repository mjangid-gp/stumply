class Player {
  const Player({
    required this.id,
    required this.displayName,
    this.userId,
    this.city = '',
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.photoUrl,
    this.role = 'player',
    this.isGuest = false,
    this.createdBy,
  });

  final String id;
  final String displayName;
  final String? userId;
  final String city;
  final String battingStyle;
  final String bowlingStyle;
  final String? photoUrl;
  final String role;
  final bool isGuest;
  final String? createdBy;

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    return Player(
      id: id,
      displayName: data['displayName'] as String? ?? 'Unknown Player',
      userId: data['userId'] as String?,
      city: data['city'] as String? ?? '',
      battingStyle: data['battingStyle'] as String? ?? '',
      bowlingStyle: data['bowlingStyle'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String? ?? 'player',
      isGuest: data['isGuest'] as bool? ?? false,
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'userId': userId,
        'city': city,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        'photoUrl': photoUrl,
        'role': role,
        'isGuest': isGuest,
        'createdBy': createdBy,
        'searchTerms': <String>[
          displayName.toLowerCase(),
          city.toLowerCase(),
        ],
      };
}
