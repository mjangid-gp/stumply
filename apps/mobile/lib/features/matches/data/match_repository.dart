import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/match_model.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(firestore: FirebaseFirestore.instance);
});

class MatchRepository {
  MatchRepository({required this._firestore});

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

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
    if (teamAId == teamBId) {
      throw ArgumentError('Team A and Team B must be different.');
    }

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

  Future<void> updateSquad({
    required String matchId,
    required List<String> teamAPlayers,
    required List<String> teamBPlayers,
    required String captainAId,
    required String captainBId,
    required String wicketkeeperAId,
    required String wicketkeeperBId,
    List<String> teamASubstitutePlayers = const [],
    List<String> teamBSubstitutePlayers = const [],
  }) async {
    final a = _cleanIds(teamAPlayers);
    final b = _cleanIds(teamBPlayers);

    if (a.length != 11 || b.length != 11) {
      throw StateError('Each team must have exactly 11 starting players.');
    }
    if (a.toSet().length != a.length || b.toSet().length != b.length) {
      throw StateError('A player cannot be selected twice.');
    }
    if (a.toSet().intersection(b.toSet()).isNotEmpty) {
      throw StateError('The same player cannot be selected for both teams.');
    }
    if (!a.contains(captainAId) || !b.contains(captainBId)) {
      throw StateError('Captain must be part of the starting XI.');
    }
    if (!a.contains(wicketkeeperAId) || !b.contains(wicketkeeperBId)) {
      throw StateError('Wicketkeeper must be part of the starting XI.');
    }

    await _firestore.collection('matches').doc(matchId).update({
      'teamAPlayers': a,
      'teamBPlayers': b,
      'teamASubstitutePlayers': _cleanIds(teamASubstitutePlayers),
      'teamBSubstitutePlayers': _cleanIds(teamBSubstitutePlayers),
      'captainAId': captainAId,
      'captainBId': captainBId,
      'wicketkeeperAId': wicketkeeperAId,
      'wicketkeeperBId': wicketkeeperBId,
      'squadUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startMatch(
    String matchId, {
    required String tossWinnerId,
    required String tossDecision,
  }) async {
    final snapshot = await _firestore.collection('matches').doc(matchId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Match not found.');
    }

    final match = MatchModel.fromMap(snapshot.id, snapshot.data()!);

    if (!match.hasCompleteSquads) {
      throw StateError(
        'Select exactly 11 starting players for both teams before starting.',
      );
    }

    if (match.captainAId == null ||
        match.captainBId == null ||
        match.wicketkeeperAId == null ||
        match.wicketkeeperBId == null) {
      throw StateError(
        'Select both captains and both wicketkeepers before starting.',
      );
    }

    if (tossWinnerId != match.teamAId && tossWinnerId != match.teamBId) {
      throw ArgumentError('Invalid toss winner.');
    }

    if (tossDecision != 'bat' && tossDecision != 'bowl') {
      throw ArgumentError('Toss decision must be bat or bowl.');
    }

    await _firestore.collection('matches').doc(matchId).update({
      'status': 'in_progress',
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<MatchModel?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) return null;
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
            final aTime =
                a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
        .map(
          (snap) =>
              snap.docs.map((d) => MatchModel.fromMap(d.id, d.data())).toList(),
        );
  }

  List<String> _cleanIds(Iterable<String> ids) {
    return ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }
}
