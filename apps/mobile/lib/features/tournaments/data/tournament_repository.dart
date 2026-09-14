import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/tournament.dart';

final tournamentRepositoryProvider = Provider<TournamentRepository>((ref) {
  return TournamentRepository(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

class TournamentRepository {
  TournamentRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final _uuid = const Uuid();

  Future<Tournament> createTournament({
    required String name,
    required String organizerId,
    String description = '',
    String format = 'round_robin',
    String city = '',
    int totalOvers = 20,
    bool homeVsAway = false,
    DateTime? startDate,
  }) async {
    final id = _uuid.v4();
    final tournament = Tournament(
      id: id,
      name: name,
      organizerId: organizerId,
      description: description,
      format: format,
      city: city,
      totalOvers: totalOvers,
      homeVsAway: homeVsAway,
      startDate: startDate,
      status: 'upcoming',
    );
    await _firestore.collection('tournaments').doc(id).set({
      ...tournament.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return tournament;
  }

  Future<int> generateFixtures({
    required String tournamentId,
    required List<String> teamIds,
    required String format,
  }) async {
    final callable = _functions.httpsCallable('generateFixtures');
    final result = await callable.call({
      'tournamentId': tournamentId,
      'teamIds': teamIds,
      'format': format,
    });
    return result.data['fixtureCount'] as int? ?? 0;
  }

  Stream<List<Tournament>> watchTournaments() {
    return _firestore.collection('tournaments').snapshots().map((snap) {
      final list = snap.docs.map((d) => Tournament.fromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        final aDate = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return list.take(50).toList();
    });
  }

  Stream<Tournament?> watchTournament(String id) {
    return _firestore.collection('tournaments').doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Tournament.fromMap(snap.id, snap.data()!);
    });
  }

  Future<void> addTeam(String tournamentId, String teamId) async {
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'teamIds': FieldValue.arrayUnion([teamId]),
    });
  }

  Stream<List<Map<String, dynamic>>> watchTournamentMatches(String tournamentId) {
    return _firestore
        .collection('matches')
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('round')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
