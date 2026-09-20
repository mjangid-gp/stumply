import 'package:flutter_test/flutter_test.dart';
import 'package:crick_app/shared/models/player.dart';

void main() {
  test('Player serializes and deserializes guest player', () {
    const player = Player(
      id: 'guest-1',
      displayName: 'Rahul Sharma',
      city: 'Jaipur',
      role: 'player',
      isGuest: true,
      createdBy: 'user-1',
    );

    final restored = Player.fromMap(player.id, player.toMap());

    expect(restored.id, 'guest-1');
    expect(restored.displayName, 'Rahul Sharma');
    expect(restored.city, 'Jaipur');
    expect(restored.isGuest, isTrue);
    expect(restored.createdBy, 'user-1');
  });
}
