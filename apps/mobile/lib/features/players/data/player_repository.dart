import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/player.dart';

final playerRepositoryProvider = Provider<PlayerRepository>(
  (ref) => PlayerRepository(firestore: FirebaseFirestore.instance),
);

class PlayerRepository {
  PlayerRepository({required this._firestore});
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  Future<Player?> getPlayer(String playerId) async {
    final s = await _firestore.collection('players').doc(playerId).get();
    return s.exists && s.data() != null
        ? Player.fromMap(s.id, s.data()!)
        : null;
  }

  Future<List<Player>> getPlayersByIds(Iterable<String> ids) async {
    final unique = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (unique.isEmpty) return [];
    final result = await Future.wait(unique.map(getPlayer));
    return result.whereType<Player>().toList();
  }

  Stream<List<Player>> watchPlayers({String query = '', int limit = 50}) {
    return _firestore.collection('players').limit(limit).snapshots().map((
      snap,
    ) {
      final q = query.trim().toLowerCase();
      final players = snap.docs
          .map((d) => Player.fromMap(d.id, d.data()))
          .where((p) {
            if (q.isEmpty) return true;
            return p.displayName.toLowerCase().contains(q) ||
                p.city.toLowerCase().contains(q);
          })
          .toList();
      players.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return players;
    });
  }

  Future<Player> createGuestPlayer({
    required String displayName,
    required String createdBy,
    String city = '',
    String battingStyle = '',
    String bowlingStyle = '',
    String role = 'player',
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Player name cannot be empty.');
    final id = _uuid.v4();
    final player = Player(
      id: id,
      displayName: name,
      city: city.trim(),
      battingStyle: battingStyle.trim(),
      bowlingStyle: bowlingStyle.trim(),
      role: role,
      isGuest: true,
      createdBy: createdBy,
    );
    await _firestore.collection('players').doc(id).set({
      ...player.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return player;
  }
}
