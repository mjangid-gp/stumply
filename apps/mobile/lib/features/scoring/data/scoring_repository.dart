import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_engine/scoring_engine.dart';
import 'local_scoring_database.dart';

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) {
  return ScoringRepository(
    rtdb: FirebaseDatabase.instance,
    localDb: LocalScoringDatabase(),
    connectivity: Connectivity(),
  );
});

class ScoringRepository {
  ScoringRepository({
    required FirebaseDatabase rtdb,
    required LocalScoringDatabase localDb,
    required Connectivity connectivity,
  })  : _rtdb = rtdb,
        _localDb = localDb,
        _connectivity = connectivity;

  final FirebaseDatabase _rtdb;
  final LocalScoringDatabase _localDb;
  final Connectivity _connectivity;
  final Map<String, ScoringEngine> _engines = {};

  ScoringEngine getEngine(MatchConfig config) {
    return _engines.putIfAbsent(config.matchId, () => ScoringEngine(config: config));
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
    await _syncPendingEvents(config.matchId);
    return event;
  }

  Future<void> undoLastBall(String matchId) async {
    final engine = _engines[matchId];
    engine?.undoLastBall();
    await _localDb.deleteLastEvent(matchId);
  }

  Future<void> _syncPendingEvents(String matchId) async {
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final pending = await _localDb.getUnsyncedEvents(matchId);
    final ref = _rtdb.ref('liveMatches/$matchId');
    await ref.child('scorerId').set(matchId);

    for (final event in pending) {
      await ref.child('events/${event.sequence}').set(event.toJson());
      await _localDb.markSynced(matchId, event.sequence);
    }

    final engine = _engines[matchId];
    if (engine != null) {
      final state = engine.state;
      await ref.child('state').set({
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
      });
    }
  }

  Stream<LiveMatchState?> watchLiveState(String matchId) {
    return _rtdb.ref('liveMatches/$matchId/state').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return null;
      final data = Map<String, dynamic>.from(val as Map);
      return LiveMatchState(
        matchId: matchId,
        status: MatchStatus.inProgress,
        currentInnings: data['currentInnings'] as int? ?? 1,
        strikerId: data['strikerId'] as String? ?? '',
        nonStrikerId: data['nonStrikerId'] as String? ?? '',
        bowlerId: data['bowlerId'] as String? ?? '',
        totalRuns: data['totalRuns'] as int? ?? 0,
        wickets: data['wickets'] as int? ?? 0,
        overs: data['overs'] as int? ?? 0,
        ballsInOver: data['ballsInOver'] as int? ?? 0,
        isFreeHit: data['isFreeHit'] as bool? ?? false,
        lastSequence: data['lastSequence'] as int? ?? 0,
        target: data['target'] as int?,
        result: data['result'] as String?,
      );
    });
  }

  LiveMatchState getLocalState(MatchConfig config) {
    return getEngine(config).state;
  }
}
