class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.organizerId,
    this.description = '',
    this.logoUrl,
    this.format = 'round_robin',
    this.status = 'upcoming',
    this.startDate,
    this.endDate,
    this.city = '',
    this.teamIds = const [],
    this.homeVsAway = false,
    this.pointsTable = const {},
    this.totalOvers = 20,
  });

  final String id;
  final String name;
  final String organizerId;
  final String description;
  final String? logoUrl;
  final String format;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String city;
  final List<String> teamIds;
  final bool homeVsAway;
  final Map<String, dynamic> pointsTable;
  final int totalOvers;

  factory Tournament.fromMap(String id, Map<String, dynamic> data) {
    return Tournament(
      id: id,
      name: data['name'] as String? ?? '',
      organizerId: data['organizerId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      logoUrl: data['logoUrl'] as String?,
      format: data['format'] as String? ?? 'round_robin',
      status: data['status'] as String? ?? 'upcoming',
      startDate: data['startDate'] != null
          ? DateTime.tryParse(data['startDate'].toString())
          : null,
      endDate: data['endDate'] != null
          ? DateTime.tryParse(data['endDate'].toString())
          : null,
      city: data['city'] as String? ?? '',
      teamIds: List<String>.from(data['teamIds'] ?? []),
      homeVsAway: data['homeVsAway'] as bool? ?? false,
      pointsTable: Map<String, dynamic>.from(data['pointsTable'] ?? {}),
      totalOvers: data['totalOvers'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'organizerId': organizerId,
        'description': description,
        'logoUrl': logoUrl,
        'format': format,
        'status': status,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'city': city,
        'teamIds': teamIds,
        'homeVsAway': homeVsAway,
        'pointsTable': pointsTable,
        'totalOvers': totalOvers,
        'searchTerms': [name.toLowerCase(), city.toLowerCase()],
      };
}
