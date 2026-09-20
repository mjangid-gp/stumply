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

/// Event-sourced cricket scoring engine.
///
/// The event log is the source of truth. Scorecards, totals and player
/// statistics are rebuilt from the events, which makes undo/correction safe.
class ScoringEngine {
  ScoringEngine({required this.config});

  final MatchConfig config;
  final List<BallEvent> _events = [];

  List<BallEvent> get events => List.unmodifiable(_events);
  LiveMatchState get state => _rebuildState();

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
    if (strikerId.trim().isEmpty ||
        nonStrikerId.trim().isEmpty ||
        bowlerId.trim().isEmpty) {
      throw ScoringEngineException(
          'Striker, non-striker and bowler are required');
    }
    if (runsOffBat < 0 || extraRuns < 0) {
      throw ScoringEngineException('Runs cannot be negative');
    }
    if (extraType == ExtraType.wide && runsOffBat != 0) {
      throw ScoringEngineException('A wide cannot contain bat runs');
    }
    if (extraType == ExtraType.noBall && extraRuns < 1) {
      throw ScoringEngineException(
          'A no-ball must include at least one no-ball extra');
    }
    if (extraType == ExtraType.wide && extraRuns < 1) {
      throw ScoringEngineException(
          'A wide must include at least one wide extra');
    }
    if (wicketType != null && dismissedPlayerId == null) {
      throw ScoringEngineException('Dismissed player is required for a wicket');
    }
    if (current.isFreeHit &&
        wicketType != null &&
        wicketType != WicketType.runOut) {
      throw ScoringEngineException('Only run out is allowed on a free hit');
    }

    if (config.maxOversPerBowler != null && extraType != ExtraType.wide) {
      final bowlerStats = _bowlerStatsForCurrentInnings(bowlerId);
      final legalBalls = bowlerStats.overs * 6 + bowlerStats.ballsInOver;
      if (extraType != ExtraType.noBall &&
          legalBalls >= config.maxOversPerBowler! * 6) {
        throw ScoringEngineException('Bowler has reached max overs limit');
      }
    }

    final event = BallEvent(
      sequence: current.lastSequence + 1,
      inningsNumber: current.currentInnings,
      overNumber: current.overs,
      ballInOver: current.ballsInOver + 1,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      bowlerId: bowlerId,
      runsOffBat: runsOffBat,
      extraType: extraType,
      extraRuns: extraRuns,
      wicketType: wicketType,
      dismissedPlayerId: dismissedPlayerId,
      fielderId: fielderId,
      isFreeHit: current.isFreeHit,
      timestamp: DateTime.now().toUtc(),
      commentary: commentary,
    );
    _events.add(event);
    return event;
  }

  BallEvent? undoLastBall() => _events.isEmpty ? null : _events.removeLast();

  /// Removes a selected event and re-numbers the remaining event stream.
  /// Useful for scorer corrections; callers should then persist the rebuilt log.
  BallEvent? removeBall(int sequence) {
    final index = _events.indexWhere((e) => e.sequence == sequence);
    if (index < 0) return null;
    final removed = _events.removeAt(index);
    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      _events[i] = e.copyWith(sequence: i + 1);
    }
    return removed;
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

    final grouped = <int, List<BallEvent>>{};
    for (final event in _events) {
      grouped.putIfAbsent(event.inningsNumber, () => []).add(event);
    }

    final scorecards = <InningsScorecard>[];
    int? target;
    String? result;
    var status = MatchStatus.inProgress;
    var currentInnings = 1;
    var striker = _events.first.strikerId;
    var nonStriker = _events.first.nonStrikerId;
    var bowler = _events.first.bowlerId;
    var battingTeamId = config.battingTeamId;
    var bowlingTeamId = config.bowlingTeamId;
    var totalRuns = 0;
    var wickets = 0;
    var overs = 0;
    var ballsInOver = 0;
    var freeHit = false;

    for (final inningsNumber in grouped.keys.toList()..sort()) {
      final events = grouped[inningsNumber]!;
      final inningsBatting =
          inningsNumber == 1 ? config.battingTeamId : config.bowlingTeamId;
      final inningsBowling =
          inningsNumber == 1 ? config.bowlingTeamId : config.battingTeamId;
      final scorecard = _buildInningsScorecard(
        inningsNumber,
        events,
        battingTeamId: inningsBatting,
        bowlingTeamId: inningsBowling,
        target: target,
      );
      scorecards.add(scorecard);
      currentInnings = inningsNumber;
      totalRuns = scorecard.totalRuns;
      wickets = scorecard.wickets;
      overs = scorecard.overs;
      ballsInOver = scorecard.ballsInOver;
      battingTeamId = inningsBatting;
      bowlingTeamId = inningsBowling;
      final last = events.last;
      striker = last.strikerId;
      nonStriker = last.nonStrikerId;
      bowler = last.bowlerId;
      freeHit = config.allowFreeHit && last.extraType == ExtraType.noBall;

      final inningsComplete = scorecard.wickets >= config.playersPerSide - 1 ||
          (scorecard.overs * 6 + scorecard.ballsInOver) >=
              config.totalOvers * 6;

      if (inningsNumber == 1 && inningsComplete) {
        target = scorecard.totalRuns + 1;
        currentInnings = 2;
        battingTeamId = config.bowlingTeamId;
        bowlingTeamId = config.battingTeamId;
        totalRuns = 0;
        wickets = 0;
        overs = 0;
        ballsInOver = 0;
      }

      if (inningsNumber == 2 && target != null) {
        if (scorecard.totalRuns >= target) {
          result =
              'Batting team won by ${config.playersPerSide - 1 - scorecard.wickets} wickets';
          status = MatchStatus.completed;
        } else if (inningsComplete) {
          result = scorecard.totalRuns == target - 1
              ? 'Match tied'
              : 'Bowling team won by ${target - 1 - scorecard.totalRuns} runs';
          status = MatchStatus.completed;
        }
      }
    }

    return LiveMatchState(
      matchId: config.matchId,
      status: status,
      currentInnings: currentInnings,
      strikerId: striker,
      nonStrikerId: nonStriker,
      bowlerId: bowler,
      totalRuns: totalRuns,
      wickets: wickets,
      overs: overs,
      ballsInOver: ballsInOver,
      isFreeHit: freeHit,
      lastSequence: _events.last.sequence,
      target: target,
      inningsScorecards: scorecards,
      result: result,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
    );
  }

  BowlingStats _bowlerStatsForCurrentInnings(String bowlerId) {
    final innings = _events.isEmpty ? 1 : _events.last.inningsNumber;
    final events = _events.where((e) => e.inningsNumber == innings).toList();
    if (events.isEmpty) return BowlingStats(playerId: bowlerId);
    return _buildInningsScorecard(
          innings,
          events,
          battingTeamId:
              innings == 1 ? config.battingTeamId : config.bowlingTeamId,
          bowlingTeamId:
              innings == 1 ? config.bowlingTeamId : config.battingTeamId,
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
    var penalty = 0;
    final batting = <String, BattingStats>{};
    final bowling = <String, BowlingStats>{};
    final fows = <FallOfWicket>[];

    String striker = events.isEmpty ? '' : events.first.strikerId;
    String nonStriker = events.isEmpty ? '' : events.first.nonStrikerId;

    for (final event in events) {
      final ballRuns = event.totalRuns;
      runs += ballRuns;
      switch (event.extraType) {
        case ExtraType.wide:
          wides += event.extraRuns;
        case ExtraType.noBall:
          noBalls += event.extraRuns;
        case ExtraType.bye:
          byes += event.extraRuns;
        case ExtraType.legBye:
          legByes += event.extraRuns;
        case ExtraType.penalty:
          penalty += event.extraRuns;
        case null:
          break;
      }

      final batter =
          batting[event.strikerId] ?? BattingStats(playerId: event.strikerId);
      final isBatterBall = event.extraType != ExtraType.wide &&
          event.extraType != ExtraType.bye &&
          event.extraType != ExtraType.legBye;
      batting[event.strikerId] = batter.copyWith(
        runs: batter.runs + event.runsOffBat,
        ballsFaced: isBatterBall && event.isLegalDelivery
            ? batter.ballsFaced + 1
            : batter.ballsFaced,
        fours: batter.fours + (event.runsOffBat == 4 ? 1 : 0),
        sixes: batter.sixes + (event.runsOffBat == 6 ? 1 : 0),
      );

      final currentBowler =
          bowling[event.bowlerId] ?? BowlingStats(playerId: event.bowlerId);
      var bOvers = currentBowler.overs;
      var bBalls = currentBowler.ballsInOver;
      if (event.isLegalDelivery) {
        bBalls++;
        if (bBalls == 6) {
          bOvers++;
          bBalls = 0;
        }
      }
      final conceded = event.extraType == ExtraType.bye ||
              event.extraType == ExtraType.legBye
          ? event.runsOffBat
          : event.totalRuns;
      final creditedWicket = event.isWicket &&
          event.wicketType != WicketType.runOut &&
          event.wicketType != WicketType.retiredOut;
      bowling[event.bowlerId] = currentBowler.copyWith(
        overs: bOvers,
        ballsInOver: bBalls,
        runsConceded: currentBowler.runsConceded + conceded,
        wickets: currentBowler.wickets + (creditedWicket ? 1 : 0),
        wides: currentBowler.wides +
            (event.extraType == ExtraType.wide ? event.extraRuns : 0),
        noBalls: currentBowler.noBalls +
            (event.extraType == ExtraType.noBall ? event.extraRuns : 0),
      );

      if (event.isWicket) {
        wickets++;
        final dismissed = event.dismissedPlayerId ?? event.strikerId;
        final dismissedStats =
            batting[dismissed] ?? BattingStats(playerId: dismissed);
        batting[dismissed] = dismissedStats.copyWith(
          isOut: event.wicketType != WicketType.retiredOut,
          dismissalText: _dismissalText(event),
        );
        fows.add(FallOfWicket(
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

      final total = event.totalRuns;
      if (total.isOdd) {
        final tmp = striker;
        striker = nonStriker;
        nonStriker = tmp;
      }
      if (event.isLegalDelivery && ballsInOver == 0 && overs > 0) {
        final tmp = striker;
        striker = nonStriker;
        nonStriker = tmp;
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
          penalty: penalty),
      batting: batting,
      bowling: bowling,
      fallOfWickets: fows,
      target: target,
    );
  }

  String _dismissalText(BallEvent event) {
    switch (event.wicketType) {
      case WicketType.bowled:
        return 'b ${event.bowlerId}';
      case WicketType.caught:
        return event.fielderId == null
            ? 'c & b ${event.bowlerId}'
            : 'c ${event.fielderId} b ${event.bowlerId}';
      case WicketType.lbw:
        return 'lbw b ${event.bowlerId}';
      case WicketType.runOut:
        return event.fielderId == null
            ? 'run out'
            : 'run out (${event.fielderId})';
      case WicketType.stumped:
        return 'st ${event.fielderId ?? ''} b ${event.bowlerId}';
      case WicketType.retiredOut:
        return 'retired out';
      default:
        return event.wicketType?.name ?? 'out';
    }
  }

  static LiveMatchState fromEvents(
      {required MatchConfig config, required List<BallEvent> events}) {
    final engine = ScoringEngine(config: config);
    engine._events.addAll(events);
    return engine.state;
  }
}
