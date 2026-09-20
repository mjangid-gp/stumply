import 'package:flutter_test/flutter_test.dart';
import 'package:crick_app/shared/models/match_model.dart';

void main() {
  test('MatchModel detects a complete playing XI', () {
    final match = MatchModel(
      id: 'match-1',
      teamAId: 'team-a',
      teamBId: 'team-b',
      teamAName: 'A',
      teamBName: 'B',
      teamAPlayers: List.generate(11, (index) => 'a-$index'),
      teamBPlayers: List.generate(11, (index) => 'b-$index'),
    );

    expect(match.hasCompleteSquads, isTrue);
  });

  test('MatchModel rejects incomplete playing XI', () {
    final match = MatchModel(
      id: 'match-1',
      teamAId: 'team-a',
      teamBId: 'team-b',
      teamAName: 'A',
      teamBName: 'B',
      teamAPlayers: List.generate(10, (index) => 'a-$index'),
      teamBPlayers: List.generate(11, (index) => 'b-$index'),
    );

    expect(match.hasCompleteSquads, isFalse);
  });
}
