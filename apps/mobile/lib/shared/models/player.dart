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
    this.matches = 0,
    this.runs = 0,
    this.wickets = 0,
    this.catches = 0,
    this.highestScore = 0,
    this.fours = 0,
    this.sixes = 0,
    this.ballsFaced = 0,
    this.runsConceded = 0,
    this.ballsBowled = 0,
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
  final int matches;
  final int runs;
  final int wickets;
  final int catches;
  final int highestScore;
  final int fours;
  final int sixes;
  final int ballsFaced;
  final int runsConceded;
  final int ballsBowled;

  double get strikeRate => ballsFaced == 0 ? 0 : runs * 100 / ballsFaced;
  double get battingAverage => matches == 0 ? 0 : runs / matches;
  double get economy => ballsBowled == 0 ? 0 : runsConceded / (ballsBowled / 6);

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    final stats = data['stats'] is Map
        ? Map<String, dynamic>.from(data['stats'] as Map)
        : const <String, dynamic>{};
    int value(String key, [String? legacy]) =>
        (stats[key] ?? (legacy == null ? data[key] : data[legacy]) ?? 0)
            as int? ??
        0;
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
      matches: value('matches', 'matchesPlayed'),
      runs: value('runs'),
      wickets: value('wickets'),
      catches: value('catches'),
      highestScore: value('highestScore'),
      fours: value('fours'),
      sixes: value('sixes'),
      ballsFaced: value('ballsFaced'),
      runsConceded: value('runsConceded'),
      ballsBowled: value('ballsBowled'),
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
    'stats': {
      'matches': matches,
      'runs': runs,
      'wickets': wickets,
      'catches': catches,
      'highestScore': highestScore,
      'fours': fours,
      'sixes': sixes,
      'ballsFaced': ballsFaced,
      'runsConceded': runsConceded,
      'ballsBowled': ballsBowled,
    },
    'searchTerms': [
      displayName.toLowerCase(),
      city.toLowerCase(),
    ].where((e) => e.isNotEmpty).toList(),
  };
}
