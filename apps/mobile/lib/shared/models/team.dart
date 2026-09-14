class Team {
  const Team({
    required this.id,
    required this.name,
    required this.captainId,
    required this.createdBy,
    this.logoUrl,
    this.city = '',
    this.homeGround = '',
    this.memberIds = const [],
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String captainId;
  final String createdBy;
  final String? logoUrl;
  final String city;
  final String homeGround;
  final List<String> memberIds;
  final int memberCount;

  factory Team.fromMap(String id, Map<String, dynamic> data) {
    return Team(
      id: id,
      name: data['name'] as String? ?? '',
      captainId: data['captainId'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      logoUrl: data['logoUrl'] as String?,
      city: data['city'] as String? ?? '',
      homeGround: data['homeGround'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberCount: data['memberCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'captainId': captainId,
        'createdBy': createdBy,
        'logoUrl': logoUrl,
        'city': city,
        'homeGround': homeGround,
        'memberIds': memberIds,
        'memberCount': memberCount,
        'searchTerms': [name.toLowerCase(), city.toLowerCase()],
      };
}
