import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(firestore: FirebaseFirestore.instance);
});

class PlayerAnalytics {
  const PlayerAnalytics({
    required this.matches,
    required this.runs,
    required this.wickets,
    required this.battingAverage,
    required this.strikeRate,
    required this.economy,
    required this.fours,
    required this.sixes,
    required this.inningsScores,
    required this.badges,
    required this.rank,
  });

  final int matches;
  final int runs;
  final int wickets;
  final double battingAverage;
  final double strikeRate;
  final double economy;
  final int fours;
  final int sixes;
  final List<int> inningsScores;
  final List<String> badges;
  final int rank;
}

class AnalyticsRepository {
  AnalyticsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<PlayerAnalytics> getPlayerAnalytics(String playerId) async {
    final snap = await _firestore.collection('players').doc(playerId).get();
    final data = snap.data() ?? {};
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final matches = stats['matches'] as int? ?? 0;
    final runs = stats['runs'] as int? ?? 0;
    final wickets = stats['wickets'] as int? ?? 0;
    final ballsFaced = stats['ballsFaced'] as int? ?? 0;
    final ballsBowled = stats['ballsBowled'] as int? ?? 0;
    final runsConceded = stats['runsConceded'] as int? ?? 0;
    final dismissals = stats['dismissals'] as int? ?? 0;

    return PlayerAnalytics(
      matches: matches,
      runs: runs,
      wickets: wickets,
      battingAverage: dismissals > 0 ? runs / dismissals : runs.toDouble(),
      strikeRate: ballsFaced > 0 ? (runs / ballsFaced) * 100 : 0,
      economy: ballsBowled > 0 ? (runsConceded / ballsBowled) * 6 : 0,
      fours: stats['fours'] as int? ?? 0,
      sixes: stats['sixes'] as int? ?? 0,
      inningsScores: List<int>.from(data['recentScores'] ?? []),
      badges: List<String>.from(data['badges'] ?? []),
      rank: data['rank'] as int? ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    String scope = 'city',
    String? city,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('rankings');
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.orderBy('points', descending: true).limit(50).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
