import 'player_stats.dart';

class InningsScorecard {
  const InningsScorecard({
    required this.inningsNumber,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.totalRuns,
    required this.wickets,
    required this.overs,
    required this.ballsInOver,
    required this.extras,
    required this.batting,
    required this.bowling,
    required this.fallOfWickets,
    this.target,
    this.result,
  });

  final int inningsNumber;
  final String battingTeamId;
  final String bowlingTeamId;
  final int totalRuns;
  final int wickets;
  final int overs;
  final int ballsInOver;
  final ExtrasBreakdown extras;
  final Map<String, BattingStats> batting;
  final Map<String, BowlingStats> bowling;
  final List<FallOfWicket> fallOfWickets;
  final int? target;
  final String? result;

  String get oversDisplay => '$overs.$ballsInOver';

  double get runRate {
    final totalBalls = overs * 6 + ballsInOver;
    if (totalBalls == 0) return 0;
    return totalRuns / (totalBalls / 6);
  }
}

class ExtrasBreakdown {
  const ExtrasBreakdown({
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penalty = 0,
  });

  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penalty;

  int get total => wides + noBalls + byes + legByes + penalty;
}

class FallOfWicket {
  const FallOfWicket({
    required this.wicketNumber,
    required this.runs,
    required this.playerId,
    required this.overDisplay,
  });

  final int wicketNumber;
  final int runs;
  final String playerId;
  final String overDisplay;
}
