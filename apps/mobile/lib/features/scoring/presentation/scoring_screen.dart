import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_engine/scoring_engine.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/match_helpers.dart';
import '../../matches/data/match_repository.dart';
import '../data/scoring_repository.dart';

class ScoringScreen extends ConsumerStatefulWidget {
  const ScoringScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  String _strikerId = 'player1';
  String _nonStrikerId = 'player2';
  String _bowlerId = 'bowler1';
  MatchConfig? _config;

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchRepositoryProvider).watchMatch(widget.matchId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Score Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last ball',
            onPressed: () async {
              await ref.read(scoringRepositoryProvider).undoLastBall(widget.matchId);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: matchAsync,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final match = snapshot.data!;
          final order = battingOrderForMatch(match);

          if (match.tossWinnerId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Complete the toss on the match screen before scoring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
              ),
            );
          }

          _config = MatchConfig(
            matchId: widget.matchId,
            totalOvers: match.totalOvers,
            battingTeamId: order.battingTeamId,
            bowlingTeamId: order.bowlingTeamId,
          );

          final state = ref.read(scoringRepositoryProvider).getLocalState(_config!);
          final isCompleted = state.status == MatchStatus.completed;
          final battingName = state.currentInnings == 1
              ? order.battingTeamName
              : order.bowlingTeamName;

          return Column(
            children: [
              _ScoreHeader(
                teamA: match.teamAName,
                teamB: match.teamBName,
                battingTeam: battingName,
                innings: state.currentInnings,
                runs: state.totalRuns,
                wickets: state.wickets,
                overs: state.oversDisplay,
                runRate: state.runRate.toStringAsFixed(2),
                target: state.target,
                isFreeHit: state.isFreeHit,
                result: state.result,
              ),
              if (isCompleted)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.result ?? 'Match completed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Tap to record each ball',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(12),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  children: [
                    _RunButton(label: '0', enabled: !isCompleted, onTap: () => _record(0)),
                    _RunButton(label: '1', enabled: !isCompleted, onTap: () => _record(1)),
                    _RunButton(label: '2', enabled: !isCompleted, onTap: () => _record(2)),
                    _RunButton(label: '3', enabled: !isCompleted, onTap: () => _record(3)),
                    _RunButton(label: '4', color: const Color(0xFF1565C0), enabled: !isCompleted, onTap: () => _record(4)),
                    _RunButton(label: '6', color: const Color(0xFF6A1B9A), enabled: !isCompleted, onTap: () => _record(6)),
                    _RunButton(label: 'WD', color: AppColors.accent, enabled: !isCompleted, onTap: () => _record(0, extraType: ExtraType.wide, extraRuns: 1)),
                    _RunButton(label: 'NB', color: AppColors.accent, enabled: !isCompleted, onTap: () => _record(0, extraType: ExtraType.noBall, extraRuns: 1)),
                    _RunButton(label: 'W', color: AppColors.cricketRed, enabled: !isCompleted, onTap: _recordWicket),
                    _RunButton(label: 'BYE', enabled: !isCompleted, onTap: () => _record(0, extraType: ExtraType.bye, extraRuns: 1)),
                    _RunButton(label: 'LB', enabled: !isCompleted, onTap: () => _record(0, extraType: ExtraType.legBye, extraRuns: 1)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _record(int runs, {ExtraType? extraType, int extraRuns = 0}) async {
    if (_config == null) return;
    try {
      await ref.read(scoringRepositoryProvider).recordBall(
        config: _config!,
        strikerId: _strikerId,
        nonStrikerId: _nonStrikerId,
        bowlerId: _bowlerId,
        runsOffBat: runs,
        extraType: extraType,
        extraRuns: extraRuns,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ScoringEngineException: ', ''))),
        );
      }
    }
  }

  Future<void> _recordWicket() async {
    if (_config == null) return;
    try {
      await ref.read(scoringRepositoryProvider).recordBall(
        config: _config!,
        strikerId: _strikerId,
        nonStrikerId: _nonStrikerId,
        bowlerId: _bowlerId,
        runsOffBat: 0,
        wicketType: WicketType.bowled,
        dismissedPlayerId: _strikerId,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ScoringEngineException: ', ''))),
        );
      }
    }
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.teamA,
    required this.teamB,
    required this.battingTeam,
    required this.innings,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.runRate,
    required this.isFreeHit,
    this.target,
    this.result,
  });

  final String teamA;
  final String teamB;
  final String battingTeam;
  final int innings;
  final int runs;
  final int wickets;
  final String overs;
  final String runRate;
  final int? target;
  final bool isFreeHit;
  final String? result;

  @override
  Widget build(BuildContext context) {
    final runsNeeded = target != null && innings == 2 ? target! - runs : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.headerGradient),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Text(
            '$teamA vs $teamB',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Innings $innings · $battingTeam',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$runs/$wickets',
            style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold, height: 1),
          ),
          const SizedBox(height: 4),
          Text('($overs ov)  ·  RR $runRate', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          if (target != null && innings == 2) ...[
            const SizedBox(height: 8),
            Text(
              runsNeeded != null && runsNeeded > 0
                  ? 'Target $target · Need $runsNeeded runs'
                  : 'Target $target',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ],
          if (isFreeHit) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('FREE HIT', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  const _RunButton({
    required this.label,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? (color ?? AppColors.primary) : Colors.grey.shade400;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      elevation: enabled ? 2 : 0,
      shadowColor: bg.withValues(alpha: 0.4),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
