import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/team.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(firestore: FirebaseFirestore.instance);
});

class TeamRepository {
  TeamRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Future<Team> createTeam({
    required String name,
    required String captainId,
    required String createdBy,
    String city = '',
    String homeGround = '',
  }) async {
    final id = _uuid.v4();
    final team = Team(
      id: id,
      name: name,
      captainId: captainId,
      createdBy: createdBy,
      city: city,
      homeGround: homeGround,
      memberIds: [captainId],
      memberCount: 1,
    );
    await _firestore.collection('teams').doc(id).set({
      ...team.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore
        .collection('teams')
        .doc(id)
        .collection('members')
        .doc(captainId)
        .set({'role': 'captain', 'joinedAt': FieldValue.serverTimestamp()});
    return team;
  }

  Stream<List<Team>> watchUserTeams(String userId) {
    return _firestore
        .collection('teams')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Team.fromMap(d.id, d.data())).toList());
  }

  Future<void> addMember(String teamId, String userId) async {
    await _firestore.collection('teams').doc(teamId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberCount': FieldValue.increment(1),
    });
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .doc(userId)
        .set({'role': 'player', 'joinedAt': FieldValue.serverTimestamp()});
  }

  Future<Team?> getTeam(String teamId) async {
    final snap = await _firestore.collection('teams').doc(teamId).get();
    if (!snap.exists) return null;
    return Team.fromMap(snap.id, snap.data()!);
  }
}
