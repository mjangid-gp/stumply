import 'match_status.dart';
import 'scorecard.dart';

class LiveMatchState {
  const LiveMatchState({
    required this.matchId,
    required this.status,
    required this.currentInnings,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.totalRuns,
    required this.wickets,
    required this.overs,
    required this.ballsInOver,
    required this.isFreeHit,
    required this.lastSequence,
    this.target,
    this.inningsScorecards = const [],
    this.result,
    this.battingTeamId,
    this.bowlingTeamId,
  });

  final String matchId;
  final MatchStatus status;
  final int currentInnings;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final int totalRuns;
  final int wickets;
  final int overs;
  final int ballsInOver;
  final bool isFreeHit;
  final int lastSequence;
  final int? target;
  final List<InningsScorecard> inningsScorecards;
  final String? result;
  final String? battingTeamId;
  final String? bowlingTeamId;

  String get oversDisplay => '$overs.$ballsInOver';

  double get runRate {
    final totalBalls = overs * 6 + ballsInOver;
    if (totalBalls == 0) return 0;
    return totalRuns / (totalBalls / 6);
  }

  double? get requiredRunRate {
    if (target == null) return null;
    final remainingRuns = target! - totalRuns;
    final totalBalls = overs * 6 + ballsInOver;
    final maxBalls = inningsScorecards.isNotEmpty
        ? (inningsScorecards.first.overs * 6 +
                inningsScorecards.first.ballsInOver)
        : 120;
    final remainingBalls = maxBalls - totalBalls;
    if (remainingBalls <= 0 || remainingRuns <= 0) return null;
    return remainingRuns / (remainingBalls / 6);
  }

  LiveMatchState copyWith({
    MatchStatus? status,
    int? currentInnings,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    int? totalRuns,
    int? wickets,
    int? overs,
    int? ballsInOver,
    bool? isFreeHit,
    int? lastSequence,
    int? target,
    List<InningsScorecard>? inningsScorecards,
    String? result,
    String? battingTeamId,
    String? bowlingTeamId,
  }) {
    return LiveMatchState(
      matchId: matchId,
      status: status ?? this.status,
      currentInnings: currentInnings ?? this.currentInnings,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      bowlerId: bowlerId ?? this.bowlerId,
      totalRuns: totalRuns ?? this.totalRuns,
      wickets: wickets ?? this.wickets,
      overs: overs ?? this.overs,
      ballsInOver: ballsInOver ?? this.ballsInOver,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      lastSequence: lastSequence ?? this.lastSequence,
      target: target ?? this.target,
      inningsScorecards: inningsScorecards ?? this.inningsScorecards,
      result: result ?? this.result,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
    );
  }
}
