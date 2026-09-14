import 'package:scoring_engine/scoring_engine.dart';
import 'package:test/test.dart';

MatchConfig _config({int overs = 20, int? maxOversPerBowler}) => MatchConfig(
      matchId: 'm1',
      totalOvers: overs,
      battingTeamId: 'team_a',
      bowlingTeamId: 'team_b',
      maxOversPerBowler: maxOversPerBowler ?? 4,
      playersPerSide: 11,
    );

void main() {
  group('ScoringEngine basics', () {
    test('starts at 0/0', () {
      final engine = ScoringEngine(config: _config());
      final state = engine.state;
      expect(state.totalRuns, 0);
      expect(state.wickets, 0);
      expect(state.overs, 0);
      expect(state.ballsInOver, 0);
    });

    test('records dot ball', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 0,
      );
      expect(engine.state.totalRuns, 0);
      expect(engine.state.ballsInOver, 1);
    });

    test('records four and six', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 4,
      );
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 6,
      );
      expect(engine.state.totalRuns, 10);
      final scorecard = engine.state.inningsScorecards.last;
      expect(scorecard.batting['p1']!.runs, 10);
      expect(scorecard.batting['p1']!.fours, 1);
      expect(scorecard.batting['p1']!.sixes, 1);
    });

    test('wide does not count as legal delivery', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 0,
        extraType: ExtraType.wide,
        extraRuns: 1,
      );
      expect(engine.state.totalRuns, 1);
      expect(engine.state.ballsInOver, 0);
    });

    test('no ball adds extra run and does not count ball', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 4,
        extraType: ExtraType.noBall,
        extraRuns: 1,
      );
      expect(engine.state.totalRuns, 5);
      expect(engine.state.ballsInOver, 0);
      expect(engine.state.isFreeHit, true);
    });

    test('free hit disallows non-runout wicket', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 0,
        extraType: ExtraType.noBall,
        extraRuns: 1,
      );
      expect(
        () => engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 0,
          wicketType: WicketType.bowled,
          dismissedPlayerId: 'p1',
        ),
        throwsA(isA<ScoringEngineException>()),
      );
    });

    test('records wicket', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 0,
        wicketType: WicketType.bowled,
        dismissedPlayerId: 'p1',
      );
      expect(engine.state.wickets, 1);
      expect(engine.state.inningsScorecards.last.batting['p1']!.isOut, true);
    });

    test('completes over after 6 legal balls', () {
      final engine = ScoringEngine(config: _config());
      for (var i = 0; i < 6; i++) {
        engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 1,
        );
      }
      expect(engine.state.overs, 1);
      expect(engine.state.ballsInOver, 0);
      expect(engine.state.totalRuns, 6);
    });

    test('undo last ball', () {
      final engine = ScoringEngine(config: _config());
      engine.recordBall(
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 4,
      );
      engine.undoLastBall();
      expect(engine.state.totalRuns, 0);
      expect(engine.events, isEmpty);
    });

    test('enforces max overs per bowler', () {
      final engine = ScoringEngine(config: _config(maxOversPerBowler: 1));
      for (var i = 0; i < 6; i++) {
        engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 0,
        );
      }
      expect(
        () => engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 0,
        ),
        throwsA(isA<ScoringEngineException>()),
      );
    });
  });

  group('BallEvent serialization', () {
    test('toJson and fromJson roundtrip', () {
      final event = BallEvent(
        sequence: 1,
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        runsOffBat: 4,
      );
      final restored = BallEvent.fromJson(event.toJson());
      expect(restored.sequence, 1);
      expect(restored.runsOffBat, 4);
    });
  });

  group('FixtureGenerator', () {
    test('round robin for 4 teams', () {
      final fixtures = FixtureGenerator.roundRobin(['a', 'b', 'c', 'd']);
      expect(fixtures.length, 6);
    });

    test('knockout for 8 teams', () {
      final fixtures = FixtureGenerator.knockout(
        List.generate(8, (i) => 't$i'),
      );
      expect(fixtures.length, 7);
    });
  });

  group('NrrCalculator', () {
    test('calculates positive NRR', () {
      final nrr = NrrCalculator.calculate(
        runsScored: 200,
        oversFaced: 20,
        runsConceded: 180,
        oversBowled: 20,
      );
      expect(nrr, closeTo(1.0, 0.01));
    });

    test('points table NRR', () {
      final entry = PointsTableEntry(
        teamId: 'a',
        played: 2,
        won: 2,
        lost: 0,
        tied: 0,
        noResult: 0,
        runsScored: 300,
        oversFaced: 40,
        runsConceded: 250,
        oversBowled: 40,
      );
      expect(entry.nrr, greaterThan(0));
      expect(entry.totalPoints, 4);
    });
  });

  group('Second innings', () {
    test('transitions to innings 2 after first innings completes', () {
      final engine = ScoringEngine(config: _config(overs: 1));
      for (var i = 0; i < 6; i++) {
        engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 1,
        );
      }
      expect(engine.state.currentInnings, 2);
      expect(engine.state.totalRuns, 0);
      expect(engine.state.target, 7);

      engine.recordBall(
        strikerId: 'p3',
        nonStrikerId: 'p4',
        bowlerId: 'b2',
        runsOffBat: 4,
      );
      expect(engine.state.currentInnings, 2);
      expect(engine.state.totalRuns, 4);
      expect(engine.events.last.inningsNumber, 2);
    });
  });

  group('fromEvents rebuild', () {
    test('rebuilds state from event list', () {
      final config = _config();
      final engine = ScoringEngine(config: config);
      for (var i = 0; i < 3; i++) {
        engine.recordBall(
          strikerId: 'p1',
          nonStrikerId: 'p2',
          bowlerId: 'b1',
          runsOffBat: 2,
        );
      }
      final rebuilt = ScoringEngine.fromEvents(
        config: config,
        events: engine.events,
      );
      expect(rebuilt.totalRuns, 6);
    });
  });
}
