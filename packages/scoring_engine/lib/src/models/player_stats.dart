class BattingStats {
  const BattingStats({
    required this.playerId,
    this.runs = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalText = 'not out',
  });

  final String playerId;
  final int runs;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final bool isOut;
  final String dismissalText;

  double get strikeRate =>
      ballsFaced == 0 ? 0 : (runs / ballsFaced) * 100;

  BattingStats copyWith({
    int? runs,
    int? ballsFaced,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissalText,
  }) {
    return BattingStats(
      playerId: playerId,
      runs: runs ?? this.runs,
      ballsFaced: ballsFaced ?? this.ballsFaced,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissalText: dismissalText ?? this.dismissalText,
    );
  }
}

class BowlingStats {
  const BowlingStats({
    required this.playerId,
    this.overs = 0,
    this.ballsInOver = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.maidens = 0,
  });

  final String playerId;
  final int overs;
  final int ballsInOver;
  final int runsConceded;
  final int wickets;
  final int wides;
  final int noBalls;
  final int maidens;

  double get economy {
    final totalBalls = overs * 6 + ballsInOver;
    if (totalBalls == 0) return 0;
    return runsConceded / (totalBalls / 6);
  }

  String get oversDisplay => '$overs.$ballsInOver';

  BowlingStats copyWith({
    int? overs,
    int? ballsInOver,
    int? runsConceded,
    int? wickets,
    int? wides,
    int? noBalls,
    int? maidens,
  }) {
    return BowlingStats(
      playerId: playerId,
      overs: overs ?? this.overs,
      ballsInOver: ballsInOver ?? this.ballsInOver,
      runsConceded: runsConceded ?? this.runsConceded,
      wickets: wickets ?? this.wickets,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      maidens: maidens ?? this.maidens,
    );
  }
}
