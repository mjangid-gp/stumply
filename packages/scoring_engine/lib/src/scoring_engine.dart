import 'models/ball_event.dart';
import 'models/extra_type.dart';
import 'models/match_config.dart';
import 'models/match_state.dart';
import 'models/match_status.dart';
import 'models/player_stats.dart';
import 'models/scorecard.dart';
import 'models/wicket_type.dart';

class ScoringEngineException implements Exception {
  ScoringEngineException(this.message);
  final String message;
  @override
  String toString() => 'ScoringEngineException: $message';
}

class ScoringEngine {
  ScoringEngine({required this.config});

  final MatchConfig config;
  final List<BallEvent> _events = [];

  List<BallEvent> get events => List.unmodifiable(_events);

  LiveMatchState get state => _rebuildState();

  /// Validates and applies a new ball event.
  BallEvent recordBall({
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
    required int runsOffBat,
    ExtraType? extraType,
    int extraRuns = 0,
    WicketType? wicketType,
    String? dismissedPlayerId,
    String? fielderId,
    String? commentary,
  }) {
    final current = state;
    if (current.status == MatchStatus.completed) {
      throw ScoringEngineException('Match is already completed');
    }

    final sequence = current.lastSequence + 1;
    final isFreeHit = current.isFreeHit;

    if (isFreeHit &&
        wicketType != null &&
        wicketType != WicketType.runOut) {
      throw ScoringEngineException('Only run out allowed on free hit');
    }

    if (config.maxOversPerBowler != null && extraType != ExtraType.wide) {
      final bowlerStats = _bowlerStatsForCurrentInnings(bowlerId);
      final legalBalls = bowlerStats.overs * 6 + bowlerStats.ballsInOver;
      final willBeLegal = extraType != ExtraType.noBall;
      if (willBeLegal && legalBalls >= config.maxOversPerBowler! * 6) {
        throw ScoringEngineException('Bowler has reached max overs limit');
      }
    }

    final overNumber = current.overs;
    final ballInOver = current.ballsInOver + 1;

    final event = BallEvent(
      sequence: sequence,
      inningsNumber: current.currentInnings,
      overNumber: overNumber,
      ballInOver: ballInOver > 6 ? 1 : ballInOver,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      bowlerId: bowlerId,
      runsOffBat: runsOffBat,
      extraType: extraType,
      extraRuns: extraRuns,
      wicketType: wicketType,
      dismissedPlayerId: dismissedPlayerId,
      fielderId: fielderId,
      isFreeHit: isFreeHit,
      timestamp: DateTime.now().toUtc(),
      commentary: commentary,
    );

    _events.add(event);
    return event;
  }

  /// Undo the last ball event.
  BallEvent? undoLastBall() {
    if (_events.isEmpty) return null;
    return _events.removeLast();
  }

  LiveMatchState _rebuildState() {
    if (_events.isEmpty) {
      return LiveMatchState(
        matchId: config.matchId,
        status: MatchStatus.inProgress,
        currentInnings: 1,
        strikerId: '',
        nonStrikerId: '',
        bowlerId: '',
        totalRuns: 0,
        wickets: 0,
        overs: 0,
        ballsInOver: 0,
        isFreeHit: false,
        lastSequence: 0,
        battingTeamId: config.battingTeamId,
        bowlingTeamId: config.bowlingTeamId,
      );
    }

    var innings = 1;
    var runs = 0;
    var wickets = 0;
    var overs = 0;
    var ballsInOver = 0;
    var striker = _events.first.strikerId;
    var nonStriker = _events.first.nonStrikerId;
    var bowler = _events.first.bowlerId;
    var isFreeHit = false;
    var target;
    final inningsScorecards = <InningsScorecard>[];
    String? result;
    var status = MatchStatus.inProgress;
    String battingTeamId = config.battingTeamId;
    String bowlingTeamId = config.bowlingTeamId;

    final inningsEvents = <int, List<BallEvent>>{};
    for (final e in _events) {
      inningsEvents.putIfAbsent(e.inningsNumber, () => []).add(e);
    }

    for (final entry in inningsEvents.entries) {
      final innNum = entry.key;
      final evts = entry.value;
      final scorecard = _buildInningsScorecard(
        innNum,
        evts,
        battingTeamId: innNum == 1 ? config.battingTeamId : config.bowlingTeamId,
        bowlingTeamId: innNum == 1 ? config.bowlingTeamId : config.battingTeamId,
        target: target,
      );
      inningsScorecards.add(scorecard);

      runs = scorecard.totalRuns;
      wickets = scorecard.wickets;
      overs = scorecard.overs;
      ballsInOver = scorecard.ballsInOver;
      innings = innNum;

      final last = evts.last;
      striker = last.strikerId;
      nonStriker = last.nonStrikerId;
      bowler = last.bowlerId;
      isFreeHit = _computeFreeHit(evts);

      final maxWickets = config.playersPerSide - 1;
      final maxBalls = config.totalOvers * 6;
      final totalBalls = overs * 6 + ballsInOver;
      final inningsComplete =
          wickets >= maxWickets || totalBalls >= maxBalls;

      if (innNum == 1 && inningsComplete) {
        target = runs + 1;
        battingTeamId = config.bowlingTeamId;
        bowlingTeamId = config.battingTeamId;
        runs = 0;
        wickets = 0;
        overs = 0;
        ballsInOver = 0;
        innings = 2;
      } else if (innNum == 2) {
        if (target != null && runs >= target) {
          result = 'Batting team won by ${config.playersPerSide - 1 - wickets} wickets';
          status = MatchStatus.completed;
        } else if (inningsComplete) {
          if (target != null && runs < target - 1) {
            result = 'Bowling team won by ${target - 1 - runs} runs';
          } else {
            result = 'Match tied';
          }
          status = MatchStatus.completed;
        }
      }
    }

    return LiveMatchState(
      matchId: config.matchId,
      status: status,
      currentInnings: innings,
      strikerId: striker,
      nonStrikerId: nonStriker,
      bowlerId: bowler,
      totalRuns: runs,
      wickets: wickets,
      overs: overs,
      ballsInOver: ballsInOver,
      isFreeHit: isFreeHit,
      lastSequence: _events.last.sequence,
      target: target,
      inningsScorecards: inningsScorecards,
      result: result,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
    );
  }

  bool _computeFreeHit(List<BallEvent> events) {
    if (!config.allowFreeHit || events.isEmpty) return false;
    final last = events.last;
    return last.extraType == ExtraType.noBall;
  }

  BowlingStats _bowlerStatsForCurrentInnings(String bowlerId) {
    final currentInnings =
        _events.isEmpty ? 1 : _events.last.inningsNumber;
    final evts =
        _events.where((e) => e.inningsNumber == currentInnings).toList();
    if (evts.isEmpty) {
      return BowlingStats(playerId: bowlerId);
    }
    return _buildInningsScorecard(
      currentInnings,
      evts,
      battingTeamId: currentInnings == 1
          ? config.battingTeamId
          : config.bowlingTeamId,
      bowlingTeamId: currentInnings == 1
          ? config.bowlingTeamId
          : config.battingTeamId,
    ).bowling[bowlerId] ??
        BowlingStats(playerId: bowlerId);
  }

  InningsScorecard _buildInningsScorecard(
    int inningsNumber,
    List<BallEvent> events, {
    required String battingTeamId,
    required String bowlingTeamId,
    int? target,
  }) {
    var runs = 0;
    var wickets = 0;
    var overs = 0;
    var ballsInOver = 0;
    var wides = 0;
    var noBalls = 0;
    var byes = 0;
    var legByes = 0;
    final batting = <String, BattingStats>{};
    final bowling = <String, BowlingStats>{};
    final fallOfWickets = <FallOfWicket>[];

    if (events.isEmpty) {
      return InningsScorecard(
        inningsNumber: inningsNumber,
        battingTeamId: battingTeamId,
        bowlingTeamId: bowlingTeamId,
        totalRuns: 0,
        wickets: 0,
        overs: 0,
        ballsInOver: 0,
        extras: const ExtrasBreakdown(),
        batting: {},
        bowling: {},
        fallOfWickets: [],
        target: target,
      );
    }

    String striker = events.first.strikerId;
    String nonStriker = events.first.nonStrikerId;

    for (final event in events) {
      striker = event.strikerId;
      nonStriker = event.nonStrikerId;

      final ballRuns = event.totalRuns;
      runs += ballRuns;

      if (event.extraType == ExtraType.wide) wides += event.extraRuns;
      if (event.extraType == ExtraType.noBall) noBalls += event.extraRuns;
      if (event.extraType == ExtraType.bye) byes += event.extraRuns;
      if (event.extraType == ExtraType.legBye) legByes += event.extraRuns;

      // Batting stats
      if (event.isLegalDelivery || event.extraType == ExtraType.noBall) {
        final batterId = event.extraType == ExtraType.bye ||
                event.extraType == ExtraType.legBye
            ? null
            : event.strikerId;
        if (batterId != null) {
          final current = batting[batterId] ??
              BattingStats(playerId: batterId);
          var fours = current.fours;
          var sixes = current.sixes;
          if (event.runsOffBat == 4) fours++;
          if (event.runsOffBat == 6) sixes++;
          batting[batterId] = current.copyWith(
            runs: current.runs + event.runsOffBat,
            ballsFaced: event.isLegalDelivery
                ? current.ballsFaced + 1
                : current.ballsFaced,
            fours: fours,
            sixes: sixes,
          );
        }
      }

      // Bowling stats
      final bowler = bowling[event.bowlerId] ??
          BowlingStats(playerId: event.bowlerId);
      var bOvers = bowler.overs;
      var bBalls = bowler.ballsInOver;
      if (event.isLegalDelivery) {
        bBalls++;
        if (bBalls == 6) {
          bOvers++;
          bBalls = 0;
        }
      }
      bowling[event.bowlerId] = bowler.copyWith(
        overs: bOvers,
        ballsInOver: bBalls,
        runsConceded: bowler.runsConceded + ballRuns,
        wickets: event.isWicket ? bowler.wickets + 1 : bowler.wickets,
        wides: event.extraType == ExtraType.wide
            ? bowler.wides + 1
            : bowler.wides,
        noBalls: event.extraType == ExtraType.noBall
            ? bowler.noBalls + 1
            : bowler.noBalls,
      );

      if (event.isWicket) {
        wickets++;
        final dismissed = event.dismissedPlayerId ?? event.strikerId;
        final bat = batting[dismissed] ?? BattingStats(playerId: dismissed);
        batting[dismissed] = bat.copyWith(
          isOut: true,
          dismissalText: _dismissalText(event),
        );
        fallOfWickets.add(FallOfWicket(
          wicketNumber: wickets,
          runs: runs,
          playerId: dismissed,
          overDisplay: '${event.overNumber}.${event.ballInOver}',
        ));
      }

      if (event.isLegalDelivery) {
        ballsInOver++;
        if (ballsInOver == 6) {
          overs++;
          ballsInOver = 0;
        }
      }

      // Strike rotation
      final total = event.totalRuns;
      if (total % 2 == 1) {
        final temp = striker;
        striker = nonStriker;
        nonStriker = temp;
      }
      if (event.isLegalDelivery && ballsInOver == 0 && overs > 0) {
        final temp = striker;
        striker = nonStriker;
        nonStriker = temp;
      }
    }

    return InningsScorecard(
      inningsNumber: inningsNumber,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      totalRuns: runs,
      wickets: wickets,
      overs: overs,
      ballsInOver: ballsInOver,
      extras: ExtrasBreakdown(
        wides: wides,
        noBalls: noBalls,
        byes: byes,
        legByes: legByes,
      ),
      batting: batting,
      bowling: bowling,
      fallOfWickets: fallOfWickets,
      target: target,
    );
  }

  String _dismissalText(BallEvent event) {
    switch (event.wicketType) {
      case WicketType.bowled:
        return 'b ${event.bowlerId}';
      case WicketType.caught:
        return event.fielderId != null
            ? 'c ${event.fielderId} b ${event.bowlerId}'
            : 'c & b ${event.bowlerId}';
      case WicketType.lbw:
        return 'lbw b ${event.bowlerId}';
      case WicketType.runOut:
        return event.fielderId != null
            ? 'run out (${event.fielderId})'
            : 'run out';
      case WicketType.stumped:
        return 'st ${event.fielderId} b ${event.bowlerId}';
      default:
        return event.wicketType?.name ?? 'out';
    }
  }

  /// Rebuild state from persisted events (e.g. after sync).
  static LiveMatchState fromEvents({
    required MatchConfig config,
    required List<BallEvent> events,
  }) {
    final engine = ScoringEngine(config: config);
    engine._events.addAll(events);
    return engine.state;
  }
}
