class MatchModel {
  const MatchModel({
    required this.id,
    required this.teamAId,
    required this.teamBId,
    required this.teamAName,
    required this.teamBName,
    this.tournamentId,
    this.status = 'scheduled',
    this.totalOvers = 20,
    this.ground = '',
    this.scorerId,
    this.createdBy,
    this.scheduledAt,
    this.liveScore,
    this.result,
    this.teamAPlayers = const [],
    this.teamBPlayers = const [],
    this.tossWinnerId,
    this.tossDecision,
  });

  final String id;
  final String teamAId;
  final String teamBId;
  final String teamAName;
  final String teamBName;
  final String? tournamentId;
  final String status;
  final int totalOvers;
  final String ground;
  final String? scorerId;
  final String? createdBy;
  final DateTime? scheduledAt;
  final Map<String, dynamic>? liveScore;
  final String? result;
  final List<String> teamAPlayers;
  final List<String> teamBPlayers;
  final String? tossWinnerId;
  final String? tossDecision;

  bool get isLive => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  factory MatchModel.fromMap(String id, Map<String, dynamic> data) {
    return MatchModel(
      id: id,
      teamAId: data['teamAId'] as String? ?? '',
      teamBId: data['teamBId'] as String? ?? '',
      teamAName: data['teamAName'] as String? ?? 'Team A',
      teamBName: data['teamBName'] as String? ?? 'Team B',
      tournamentId: data['tournamentId'] as String?,
      status: data['status'] as String? ?? 'scheduled',
      totalOvers: data['totalOvers'] as int? ?? 20,
      ground: data['ground'] as String? ?? '',
      scorerId: data['scorerId'] as String?,
      createdBy: data['createdBy'] as String?,
      scheduledAt: data['scheduledAt'] != null
          ? DateTime.tryParse(data['scheduledAt'].toString())
          : null,
      liveScore: data['liveScore'] as Map<String, dynamic>?,
      result: data['result'] as String?,
      teamAPlayers: List<String>.from(data['teamAPlayers'] ?? []),
      teamBPlayers: List<String>.from(data['teamBPlayers'] ?? []),
      tossWinnerId: data['tossWinnerId'] as String?,
      tossDecision: data['tossDecision'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'teamAId': teamAId,
        'teamBId': teamBId,
        'teamAName': teamAName,
        'teamBName': teamBName,
        'tournamentId': tournamentId,
        'status': status,
        'totalOvers': totalOvers,
        'ground': ground,
        'scorerId': scorerId,
        'createdBy': createdBy,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'teamAPlayers': teamAPlayers,
        'teamBPlayers': teamBPlayers,
        'tossWinnerId': tossWinnerId,
        'tossDecision': tossDecision,
      };
}
