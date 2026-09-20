import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_engine/scoring_engine.dart';

import 'local_scoring_database.dart';

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) {
  return ScoringRepository(
    rtdb: FirebaseDatabase.instance,
    firestore: FirebaseFirestore.instance,
    localDb: LocalScoringDatabase(),
    connectivity: Connectivity(),
  );
});

class ScoringRepository {
  ScoringRepository({
    required FirebaseDatabase rtdb,
    required FirebaseFirestore firestore,
    required LocalScoringDatabase localDb,
    required Connectivity connectivity,
  }) : _rtdb = rtdb,
       _firestore = firestore,
       _localDb = localDb,
       _connectivity = connectivity;

  final FirebaseDatabase _rtdb;
  final FirebaseFirestore _firestore;
  final LocalScoringDatabase _localDb;
  final Connectivity _connectivity;

  final Map<String, ScoringEngine> _engines = {};

  ScoringEngine getEngine(MatchConfig config) {
    return _engines.putIfAbsent(
      config.matchId,
      () => ScoringEngine(config: config),
    );
  }

  Future<BallEvent> recordBall({
    required MatchConfig config,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
    required int runsOffBat,
    ExtraType? extraType,
    int extraRuns = 0,
    WicketType? wicketType,
    String? dismissedPlayerId,
    String? fielderId,
  }) async {
    final engine = getEngine(config);

    final event = engine.recordBall(
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      bowlerId: bowlerId,
      runsOffBat: runsOffBat,
      extraType: extraType,
      extraRuns: extraRuns,
      wicketType: wicketType,
      dismissedPlayerId: dismissedPlayerId,
      fielderId: fielderId,
    );

    await _localDb.saveEvent(config.matchId, event);

    await _syncPendingEvents(config: config, engine: engine);

    return event;
  }

  Future<void> undoLastBall(String matchId) async {
    final engine = _engines[matchId];

    if (engine == null) {
      return;
    }

    final removed = engine.undoLastBall();

    if (removed == null) {
      return;
    }

    await _localDb.deleteLastEvent(matchId);

    final connectivity = await _connectivity.checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      return;
    }

    await _syncEngineState(matchId: matchId, engine: engine);
  }

  Future<void> _syncPendingEvents({
    required MatchConfig config,
    required ScoringEngine engine,
  }) async {
    final connectivity = await _connectivity.checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return;
    }

    final matchId = config.matchId;

    final pending = await _localDb.getUnsyncedEvents(matchId);

    final ref = _rtdb.ref('liveMatches/$matchId');

    final scorerSnap = await ref.child('scorerId').get();

    if (!scorerSnap.exists) {
      await ref.child('scorerId').set(userId);
    }

    for (final event in pending) {
      await ref.child('events/${event.sequence}').set(event.toJson());

      await _localDb.markSynced(matchId, event.sequence);
    }

    await _syncEngineState(matchId: matchId, engine: engine);
  }

  Future<void> _syncEngineState({
    required String matchId,
    required ScoringEngine engine,
  }) async {
    final state = engine.state;

    final ref = _rtdb.ref('liveMatches/$matchId');

    /*
     * Keep the RTDB state as the realtime source for the scorer UI.
     */
    await ref.child('state').set({
      'matchId': state.matchId,
      'status': state.status.name,
      'currentInnings': state.currentInnings,
      'strikerId': state.strikerId,
      'nonStrikerId': state.nonStrikerId,
      'bowlerId': state.bowlerId,
      'totalRuns': state.totalRuns,
      'wickets': state.wickets,
      'overs': state.overs,
      'ballsInOver': state.ballsInOver,
      'isFreeHit': state.isFreeHit,
      'lastSequence': state.lastSequence,
      'target': state.target,
      'result': state.result,
      'battingTeamId': state.battingTeamId,
      'bowlingTeamId': state.bowlingTeamId,
      'updatedAt': ServerValue.timestamp,
    });

    /*
     * IMPORTANT:
     *
     * Cloud Functions cannot be used on the current Spark plan.
     *
     * Therefore the Flutter scorer itself finalizes the Firestore match
     * when the scoring engine reports MatchStatus.completed.
     */
    if (state.status == MatchStatus.completed) {
      await _finalizeMatch(matchId: matchId, state: state);
    } else {
      /*
       * Keep Firestore liveScore synchronized while the match is running.
       * This also makes the match list/detail screen reflect the current
       * score without requiring a Cloud Function.
       */
      await _updateLiveMatch(matchId: matchId, state: state);
    }
  }

  Future<void> _updateLiveMatch({
    required String matchId,
    required LiveMatchState state,
  }) async {
    final matchRef = _firestore.collection('matches').doc(matchId);

    await matchRef.update({
      'status': 'in_progress',
      'liveScore': _stateToMap(state),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _finalizeMatch({
    required String matchId,
    required LiveMatchState state,
  }) async {
    final matchRef = _firestore.collection('matches').doc(matchId);

    final snapshot = await matchRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Cannot finalize match: match $matchId was not found.');
    }

    final match = snapshot.data()!;

    /*
     * Avoid repeatedly finalizing an already completed match.
     */
    if (match['status'] == 'completed') {
      return;
    }

    final teamAId = match['teamAId'] as String? ?? '';
    final teamBId = match['teamBId'] as String? ?? '';

    String? winnerId;
    String? loserId;
    bool isTie = false;

    final result = state.result ?? 'Match completed';

    if (_isTieResult(result)) {
      isTie = true;
    } else if (state.battingTeamId != null && state.bowlingTeamId != null) {
      /*
       * The scoring engine's current batting team is the winner when
       * the second innings successfully chases the target.
       *
       * If the second innings finishes without reaching the target,
       * the bowling team is the winner.
       */
      final secondInningsScorecard = state.inningsScorecards.length >= 2
          ? state.inningsScorecards.last
          : null;

      if (secondInningsScorecard != null &&
          state.target != null &&
          secondInningsScorecard.totalRuns >= state.target!) {
        winnerId = state.battingTeamId;
        loserId = state.bowlingTeamId;
      } else {
        winnerId = state.bowlingTeamId;
        loserId = state.battingTeamId;
      }
    }

    /*
     * Safety check: only use IDs that actually belong to this match.
     */
    if (winnerId != null && winnerId != teamAId && winnerId != teamBId) {
      winnerId = null;
    }

    if (loserId != null && loserId != teamAId && loserId != teamBId) {
      loserId = null;
    }

    final update = <String, dynamic>{
      'status': 'completed',
      'result': result,
      'isTie': isTie,
      'liveScore': _stateToMap(state),
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (winnerId != null) {
      update['winnerId'] = winnerId;
    } else {
      update['winnerId'] = null;
    }

    if (loserId != null) {
      update['loserId'] = loserId;
    } else {
      update['loserId'] = null;
    }

    await matchRef.update(update);
  }

  bool _isTieResult(String result) {
    return result.toLowerCase().contains('tied');
  }

  Map<String, dynamic> _stateToMap(LiveMatchState state) {
    return {
      'matchId': state.matchId,
      'status': state.status.name,
      'currentInnings': state.currentInnings,
      'strikerId': state.strikerId,
      'nonStrikerId': state.nonStrikerId,
      'bowlerId': state.bowlerId,
      'totalRuns': state.totalRuns,
      'wickets': state.wickets,
      'overs': state.overs,
      'ballsInOver': state.ballsInOver,
      'isFreeHit': state.isFreeHit,
      'lastSequence': state.lastSequence,
      'target': state.target,
      'result': state.result,
      'battingTeamId': state.battingTeamId,
      'bowlingTeamId': state.bowlingTeamId,
      'inningsScorecards': state.inningsScorecards
          .map(_scorecardToMap)
          .toList(),
    };
  }

  Map<String, dynamic> _scorecardToMap(InningsScorecard scorecard) {
    return {
      'inningsNumber': scorecard.inningsNumber,
      'battingTeamId': scorecard.battingTeamId,
      'bowlingTeamId': scorecard.bowlingTeamId,
      'totalRuns': scorecard.totalRuns,
      'wickets': scorecard.wickets,
      'overs': scorecard.overs,
      'ballsInOver': scorecard.ballsInOver,
      'target': scorecard.target,
      'result': scorecard.result,
      'extras': {
        'wides': scorecard.extras.wides,
        'noBalls': scorecard.extras.noBalls,
        'byes': scorecard.extras.byes,
        'legByes': scorecard.extras.legByes,
        'penalty': scorecard.extras.penalty,
        'total': scorecard.extras.total,
      },
      'fallOfWickets': scorecard.fallOfWickets
          .map(
            (fall) => {
              'wicketNumber': fall.wicketNumber,
              'runs': fall.runs,
              'playerId': fall.playerId,
              'overDisplay': fall.overDisplay,
            },
          )
          .toList(),
    };
  }

  Stream<LiveMatchState?> watchLiveState(String matchId) {
    return _rtdb.ref('liveMatches/$matchId/state').onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null) {
        return null;
      }

      if (value is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(value);

      final statusName = data['status'] as String? ?? 'inProgress';

      final status = MatchStatus.values
          .where((item) => item.name == statusName)
          .firstWhere((item) => true, orElse: () => MatchStatus.inProgress);

      return LiveMatchState(
        matchId: matchId,
        status: status,
        currentInnings: _asInt(data['currentInnings']) ?? 1,
        strikerId: data['strikerId'] as String? ?? '',
        nonStrikerId: data['nonStrikerId'] as String? ?? '',
        bowlerId: data['bowlerId'] as String? ?? '',
        totalRuns: _asInt(data['totalRuns']) ?? 0,
        wickets: _asInt(data['wickets']) ?? 0,
        overs: _asInt(data['overs']) ?? 0,
        ballsInOver: _asInt(data['ballsInOver']) ?? 0,
        isFreeHit: data['isFreeHit'] as bool? ?? false,
        lastSequence: _asInt(data['lastSequence']) ?? 0,
        target: _asInt(data['target']),
        result: data['result'] as String?,
      );
    });
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
  }

  LiveMatchState getLocalState(MatchConfig config) {
    return getEngine(config).state;
  }
}
