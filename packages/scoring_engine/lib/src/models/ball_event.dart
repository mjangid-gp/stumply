import 'extra_type.dart';
import 'wicket_type.dart';

/// Immutable ball-level event in the match event log.
class BallEvent {
  const BallEvent({
    required this.sequence,
    required this.inningsNumber,
    required this.overNumber,
    required this.ballInOver,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.runsOffBat,
    this.extraType,
    this.extraRuns = 0,
    this.wicketType,
    this.dismissedPlayerId,
    this.fielderId,
    this.isFreeHit = false,
    this.timestamp,
    this.commentary,
  });

  final int sequence;
  final int inningsNumber;
  final int overNumber;
  final int ballInOver;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final int runsOffBat;
  final ExtraType? extraType;
  final int extraRuns;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? fielderId;
  final bool isFreeHit;
  final DateTime? timestamp;
  final String? commentary;

  int get totalRuns => runsOffBat + extraRuns;

  bool get isLegalDelivery =>
      extraType != ExtraType.wide && extraType != ExtraType.noBall;

  bool get isWicket =>
      wicketType != null &&
      wicketType != WicketType.retiredOut &&
      !(isFreeHit && wicketType != WicketType.runOut);

  BallEvent copyWith({
    int? sequence,
    String? commentary,
  }) {
    return BallEvent(
      sequence: sequence ?? this.sequence,
      inningsNumber: inningsNumber,
      overNumber: overNumber,
      ballInOver: ballInOver,
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
      timestamp: timestamp,
      commentary: commentary ?? this.commentary,
    );
  }

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'inningsNumber': inningsNumber,
        'overNumber': overNumber,
        'ballInOver': ballInOver,
        'strikerId': strikerId,
        'nonStrikerId': nonStrikerId,
        'bowlerId': bowlerId,
        'runsOffBat': runsOffBat,
        'extraType': extraType?.name,
        'extraRuns': extraRuns,
        'wicketType': wicketType?.name,
        'dismissedPlayerId': dismissedPlayerId,
        'fielderId': fielderId,
        'isFreeHit': isFreeHit,
        'timestamp': timestamp?.toIso8601String(),
        'commentary': commentary,
      };

  factory BallEvent.fromJson(Map<String, dynamic> json) => BallEvent(
        sequence: json['sequence'] as int,
        inningsNumber: json['inningsNumber'] as int,
        overNumber: json['overNumber'] as int,
        ballInOver: json['ballInOver'] as int,
        strikerId: json['strikerId'] as String,
        nonStrikerId: json['nonStrikerId'] as String,
        bowlerId: json['bowlerId'] as String,
        runsOffBat: json['runsOffBat'] as int? ?? 0,
        extraType: json['extraType'] != null
            ? ExtraType.values.byName(json['extraType'] as String)
            : null,
        extraRuns: json['extraRuns'] as int? ?? 0,
        wicketType: json['wicketType'] != null
            ? WicketType.values.byName(json['wicketType'] as String)
            : null,
        dismissedPlayerId: json['dismissedPlayerId'] as String?,
        fielderId: json['fielderId'] as String?,
        isFreeHit: json['isFreeHit'] as bool? ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        commentary: json['commentary'] as String?,
      );
}
