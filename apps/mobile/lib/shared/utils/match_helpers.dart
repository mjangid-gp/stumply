import '../models/match_model.dart';

class MatchBattingOrder {
  const MatchBattingOrder({
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.battingTeamName,
    required this.bowlingTeamName,
  });

  final String battingTeamId;
  final String bowlingTeamId;
  final String battingTeamName;
  final String bowlingTeamName;
}

MatchBattingOrder battingOrderForMatch(MatchModel match) {
  if (match.tossWinnerId == null || match.tossDecision == null) {
    return MatchBattingOrder(
      battingTeamId: match.teamAId,
      bowlingTeamId: match.teamBId,
      battingTeamName: match.teamAName,
      bowlingTeamName: match.teamBName,
    );
  }

  final winnerIsA = match.tossWinnerId == match.teamAId;
  final winnerName = winnerIsA ? match.teamAName : match.teamBName;
  final otherId = winnerIsA ? match.teamBId : match.teamAId;
  final otherName = winnerIsA ? match.teamBName : match.teamAName;

  if (match.tossDecision == 'bat') {
    return MatchBattingOrder(
      battingTeamId: match.tossWinnerId!,
      bowlingTeamId: otherId,
      battingTeamName: winnerName,
      bowlingTeamName: otherName,
    );
  }

  return MatchBattingOrder(
    battingTeamId: otherId,
    bowlingTeamId: match.tossWinnerId!,
    battingTeamName: otherName,
    bowlingTeamName: winnerName,
  );
}

String tossSummary(MatchModel match) {
  if (match.tossWinnerId == null || match.tossDecision == null) {
    return 'Toss not done';
  }
  final winnerName =
      match.tossWinnerId == match.teamAId ? match.teamAName : match.teamBName;
  final decision = match.tossDecision == 'bat' ? 'bat first' : 'bowl first';
  return '$winnerName won toss, elected to $decision';
}
