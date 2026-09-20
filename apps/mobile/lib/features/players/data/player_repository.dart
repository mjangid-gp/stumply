import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/player.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(firestore: FirebaseFirestore.instance);
});

class PlayerRepository {
  PlayerRepository({required this._firestore});

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  Future<Player?> getPlayer(String playerId) async {
    final snapshot = await _firestore.collection('players').doc(playerId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return Player.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<List<Player>> getPlayersByIds(Iterable<String> playerIds) async {
    final uniqueIds = playerIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (uniqueIds.isEmpty) return <Player>[];

    final players = await Future.wait(uniqueIds.map(getPlayer));

    return players.whereType<Player>().toList();
  }

  Future<Player> createGuestPlayer({
    required String displayName,
    required String createdBy,
    String city = '',
    String battingStyle = '',
    String bowlingStyle = '',
    String role = 'player',
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Player name cannot be empty.');
    }

    final id = _uuid.v4();
    final player = Player(
      id: id,
      displayName: cleanName,
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
