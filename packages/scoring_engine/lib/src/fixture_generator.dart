/// Tournament fixture generation utilities.
class FixtureGenerator {
  /// Round-robin: each team plays every other team once.
  static List<Fixture> roundRobin(List<String> teamIds) {
    if (teamIds.length < 2) return [];
    final teams = List<String>.from(teamIds);
    if (teams.length % 2 != 0) teams.add('BYE');

    final n = teams.length;
    final rounds = n - 1;
    final fixtures = <Fixture>[];
    var roundTeams = List<String>.from(teams);

    for (var round = 0; round < rounds; round++) {
      for (var i = 0; i < n / 2; i++) {
        final home = roundTeams[i];
        final away = roundTeams[n - 1 - i];
        if (home != 'BYE' && away != 'BYE') {
          fixtures.add(Fixture(
            round: round + 1,
            homeTeamId: home,
            awayTeamId: away,
          ));
        }
      }
      final last = roundTeams.removeLast();
      roundTeams.insert(1, last);
    }
    return fixtures;
  }

  /// Single elimination knockout bracket.
  static List<Fixture> knockout(List<String> teamIds) {
    if (teamIds.length < 2) return [];
    final fixtures = <Fixture>[];
    var round = 1;
    var current = List<String>.from(teamIds);

    while (current.length > 1) {
      if (current.length % 2 != 0) {
        current.add('BYE');
      }
      final nextRound = <String>[];
      for (var i = 0; i < current.length; i += 2) {
        final home = current[i];
        final away = current[i + 1];
        if (home != 'BYE' && away != 'BYE') {
          fixtures.add(Fixture(
            round: round,
            homeTeamId: home,
            awayTeamId: away,
            isKnockout: true,
          ));
          nextRound.add('TBD_${round}_$i');
        } else {
          nextRound.add(home == 'BYE' ? away : home);
        }
      }
      current = nextRound;
      round++;
    }
    return fixtures;
  }
}

class Fixture {
  const Fixture({
    required this.round,
    required this.homeTeamId,
    required this.awayTeamId,
    this.isKnockout = false,
    this.scheduledAt,
  });

  final int round;
  final String homeTeamId;
  final String awayTeamId;
  final bool isKnockout;
  final DateTime? scheduledAt;

  Map<String, dynamic> toJson() => {
        'round': round,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'isKnockout': isKnockout,
        'scheduledAt': scheduledAt?.toIso8601String(),
      };
}
