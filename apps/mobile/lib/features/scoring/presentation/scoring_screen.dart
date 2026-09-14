import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_engine/scoring_engine.dart';
import '../../../core/theme/app_theme.dart';
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
          _config = MatchConfig(
            matchId: widget.matchId,
            totalOvers: match.totalOvers,
            battingTeamId: match.teamAId,
            bowlingTeamId: match.teamBId,
          );

          final state = ref.read(scoringRepositoryProvider).getLocalState(_config!);

          return Column(
            children: [
              _ScoreHeader(
                teamA: match.teamAName,
                teamB: match.teamBName,
                runs: state.totalRuns,
                wickets: state.wickets,
                overs: state.oversDisplay,
                runRate: state.runRate.toStringAsFixed(2),
                isFreeHit: state.isFreeHit,
              ),
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
                    _RunButton(label: '0', onTap: () => _record(0)),
                    _RunButton(label: '1', onTap: () => _record(1)),
                    _RunButton(label: '2', onTap: () => _record(2)),
                    _RunButton(label: '3', onTap: () => _record(3)),
                    _RunButton(label: '4', color: const Color(0xFF1565C0), onTap: () => _record(4)),
                    _RunButton(label: '6', color: const Color(0xFF6A1B9A), onTap: () => _record(6)),
                    _RunButton(label: 'WD', color: AppColors.accent, onTap: () => _record(0, extraType: ExtraType.wide, extraRuns: 1)),
                    _RunButton(label: 'NB', color: AppColors.accent, onTap: () => _record(0, extraType: ExtraType.noBall, extraRuns: 1)),
                    _RunButton(label: 'W', color: AppColors.cricketRed, onTap: _recordWicket),
                    _RunButton(label: 'BYE', onTap: () => _record(0, extraType: ExtraType.bye, extraRuns: 1)),
                    _RunButton(label: 'LB', onTap: () => _record(0, extraType: ExtraType.legBye, extraRuns: 1)),
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
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.runRate,
    required this.isFreeHit,
  });

  final String teamA;
  final String teamB;
  final int runs;
  final int wickets;
  final String overs;
  final String runRate;
  final bool isFreeHit;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 8),
          Text(
            '$runs/$wickets',
            style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold, height: 1),
          ),
          const SizedBox(height: 4),
          Text('($overs ov)  ·  RR $runRate', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
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
  const _RunButton({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: bg.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
