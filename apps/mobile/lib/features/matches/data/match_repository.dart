import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/match_model.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(firestore: FirebaseFirestore.instance);
});

class MatchRepository {
  MatchRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Future<MatchModel> createMatch({
    required String teamAId,
    required String teamBId,
    required String teamAName,
    required String teamBName,
    required String createdBy,
    int totalOvers = 20,
    String ground = '',
    String? tournamentId,
    List<String> teamAPlayers = const [],
    List<String> teamBPlayers = const [],
  }) async {
    final id = _uuid.v4();
    final match = MatchModel(
      id: id,
      teamAId: teamAId,
      teamBId: teamBId,
      teamAName: teamAName,
      teamBName: teamBName,
      createdBy: createdBy,
      scorerId: createdBy,
      totalOvers: totalOvers,
      ground: ground,
      tournamentId: tournamentId,
      teamAPlayers: teamAPlayers,
      teamBPlayers: teamBPlayers,
      status: 'scheduled',
    );
    await _firestore.collection('matches').doc(id).set({
      ...match.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return match;
  }

  Future<void> startMatch(String matchId, {
    required String tossWinnerId,
    required String tossDecision,
  }) async {
    await _firestore.collection('matches').doc(matchId).update({
      'status': 'in_progress',
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<MatchModel?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return MatchModel.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<MatchModel>> watchUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final matches = snap.docs
              .map((d) => MatchModel.fromMap(d.id, d.data()))
              .toList();
          matches.sort((a, b) {
            final aTime = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return matches.take(30).toList();
        });
  }

  Stream<List<MatchModel>> watchLiveMatches() {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'in_progress')
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MatchModel.fromMap(d.id, d.data())).toList());
  }
}
