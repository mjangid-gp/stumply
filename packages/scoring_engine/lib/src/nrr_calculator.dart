/// Net Run Rate calculator for tournament points tables.
class NrrCalculator {
  static double calculate({
    required int runsScored,
    required double oversFaced,
    required int runsConceded,
    required double oversBowled,
  }) {
    if (oversFaced == 0 || oversBowled == 0) return 0;
    final runRate = runsScored / oversFaced;
    final concededRate = runsConceded / oversBowled;
    return runRate - concededRate;
  }

  static double oversToDecimal(int overs, int balls) => overs + balls / 6;

  /// What margin (runs or balls) does chasing team need for target NRR?
  static int? runsNeededForNrr({
    required int currentRuns,
    required double currentOvers,
    required int targetNrrRuns,
    required double oversRemaining,
    required int runsConcededSoFar,
    required double oversBowledSoFar,
  }) {
    if (oversRemaining <= 0) return null;
    // Simplified: runs needed = (target RR * total overs) - current runs
    final totalOvers = currentOvers + oversRemaining;
    final requiredTotal = (targetNrrRuns / totalOvers) * totalOvers;
    return (requiredTotal - currentRuns).ceil();
  }
}

class PointsTableEntry {
  const PointsTableEntry({
    required this.teamId,
    required this.played,
    required this.won,
    required this.lost,
    required this.tied,
    required this.noResult,
    required this.runsScored,
    required this.oversFaced,
    required this.runsConceded,
    required this.oversBowled,
    this.points = 0,
  });

  final String teamId;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int runsScored;
  final double oversFaced;
  final int runsConceded;
  final double oversBowled;
  final int points;

  double get nrr => NrrCalculator.calculate(
        runsScored: runsScored,
        oversFaced: oversFaced,
        runsConceded: runsConceded,
        oversBowled: oversBowled,
      );

  int get totalPoints => won * 2 + tied;

  PointsTableEntry copyWith({
    int? played,
    int? won,
    int? lost,
    int? tied,
    int? noResult,
    int? runsScored,
    double? oversFaced,
    int? runsConceded,
    double? oversBowled,
  }) {
    return PointsTableEntry(
      teamId: teamId,
      played: played ?? this.played,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      tied: tied ?? this.tied,
      noResult: noResult ?? this.noResult,
      runsScored: runsScored ?? this.runsScored,
      oversFaced: oversFaced ?? this.oversFaced,
      runsConceded: runsConceded ?? this.runsConceded,
      oversBowled: oversBowled ?? this.oversBowled,
    );
  }
}
