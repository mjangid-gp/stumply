class MatchConfig {
  const MatchConfig({
    required this.matchId,
    required this.totalOvers,
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.maxOversPerBowler,
    this.superOver = false,
    this.powerplayOvers = 0,
    this.allowFreeHit = true,
    this.playersPerSide = 11,
  });

  final String matchId;
  final int totalOvers;
  final String battingTeamId;
  final String bowlingTeamId;
  final int? maxOversPerBowler;
  final bool superOver;
  final int powerplayOvers;
  final bool allowFreeHit;
  final int playersPerSide;

  MatchConfig copyWith({
    String? battingTeamId,
    String? bowlingTeamId,
    bool? superOver,
  }) {
    return MatchConfig(
      matchId: matchId,
      totalOvers: totalOvers,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
      maxOversPerBowler: maxOversPerBowler,
      superOver: superOver ?? this.superOver,
      powerplayOvers: powerplayOvers,
      allowFreeHit: allowFreeHit,
      playersPerSide: playersPerSide,
    );
  }
}
