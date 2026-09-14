import 'package:scoring_engine/scoring_engine.dart';

void main() {
  final engine = ScoringEngine(
    config: MatchConfig(
      matchId: 'example',
      totalOvers: 20,
      battingTeamId: 'team_a',
      bowlingTeamId: 'team_b',
      maxOversPerBowler: 4,
      playersPerSide: 11,
    ),
  );

  engine.recordBall(
    strikerId: 'p1',
    nonStrikerId: 'p2',
    bowlerId: 'b1',
    runsOffBat: 4,
  );

  print('Score: ${engine.state.totalRuns}/${engine.state.wickets}');
}
