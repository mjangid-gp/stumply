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
  final _strikerController = TextEditingController(text: 'Striker');
  final _nonStrikerController = TextEditingController(text: 'Non-striker');
  final _bowlerController = TextEditingController(text: 'Bowler');
  MatchConfig? _config;

  @override
  void dispose() {
    _strikerController.dispose();
    _nonStrikerController.dispose();
    _bowlerController.dispose();
    super.dispose();
  }

  String get _strikerId => _strikerController.text.trim().isEmpty
      ? 'Striker'
      : _strikerController.text.trim();
  String get _nonStrikerId => _nonStrikerController.text.trim().isEmpty
      ? 'Non-striker'
      : _nonStrikerController.text.trim();
  String get _bowlerId => _bowlerController.text.trim().isEmpty
      ? 'Bowler'
      : _bowlerController.text.trim();

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchRepositoryProvider).watchMatch(widget.matchId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Score Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Swap strike',
            onPressed: _swapStrike,
          ),
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

          final engine = ref.read(scoringRepositoryProvider).getEngine(_config!);
          final state = engine.state;
          final isCompleted = state.status == MatchStatus.completed;
          final battingName = state.currentInnings == 1
              ? order.battingTeamName
              : order.bowlingTeamName;
          final recentBalls = engine.events.reversed.take(6).toList();

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
                requiredRunRate: state.requiredRunRate,
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
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      Expanded(child: _PlayerField(label: 'Striker *', controller: _strikerController)),
                      const SizedBox(width: 8),
                      Expanded(child: _PlayerField(label: 'Non-striker', controller: _nonStrikerController)),
                      const SizedBox(width: 8),
                      Expanded(child: _PlayerField(label: 'Bowler', controller: _bowlerController)),
                    ],
                  ),
                ),
                if (recentBalls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recentBalls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final ball = recentBalls[recentBalls.length - 1 - i];
                          return _BallChip(event: ball);
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    state.isFreeHit
                        ? 'FREE HIT — only run out can dismiss a batter'
                        : 'Tap a run, extra, or wicket. Use RO for run out.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
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
                    _RunButton(label: 'WD', color: AppColors.accent, enabled: !isCompleted, onTap: () => _recordExtra(ExtraType.wide)),
                    _RunButton(label: 'NB', color: AppColors.accent, enabled: !isCompleted, onTap: () => _recordExtra(ExtraType.noBall)),
                    _RunButton(label: 'W', color: AppColors.cricketRed, enabled: !isCompleted, onTap: _recordWicket),
                    _RunButton(label: 'RO', color: const Color(0xFFBF360C), enabled: !isCompleted, onTap: _recordRunOut),
                    _RunButton(label: 'BYE', enabled: !isCompleted, onTap: () => _recordExtra(ExtraType.bye)),
                    _RunButton(label: 'LB', enabled: !isCompleted, onTap: () => _recordExtra(ExtraType.legBye)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _shouldRotateStrike({
    required int runs,
    ExtraType? extraType,
    WicketType? wicketType,
  }) {
    if (wicketType != null) return false;
    if (extraType == ExtraType.wide || extraType == ExtraType.noBall) return false;
    return runs.isOdd;
  }

  void _swapStrike() {
    final a = _strikerController.text;
    _strikerController.text = _nonStrikerController.text;
    _nonStrikerController.text = a;
    setState(() {});
  }

  Future<void> _record(
    int runs, {
    ExtraType? extraType,
    int extraRuns = 0,
    WicketType? wicketType,
    String? dismissedPlayerId,
    String? fielderId,
  }) async {
    if (_config == null) return;
    try {
      await ref.read(scoringRepositoryProvider).recordBall(
        config: _config!,
        strikerId: _strikerId,
        nonStrikerId: _nonStrikerId,
        bowlerId: _bowlerId,
        runsOffBat: extraType == ExtraType.bye || extraType == ExtraType.legBye ? 0 : runs,
        extraType: extraType,
        extraRuns: extraRuns,
        wicketType: wicketType,
        dismissedPlayerId: dismissedPlayerId,
        fielderId: fielderId,
      );
      if (_shouldRotateStrike(
        runs: extraType == ExtraType.bye || extraType == ExtraType.legBye ? extraRuns : runs,
        extraType: extraType,
        wicketType: wicketType,
      )) {
        _swapStrike();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ScoringEngineException: ', ''))),
        );
      }
    }
  }

  Future<void> _recordExtra(ExtraType type) async {
    final extraRuns = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _ExtraRunsSheet(type: type),
    );
    if (extraRuns == null) return;
    if (type == ExtraType.noBall) {
      await _record(extraRuns, extraType: ExtraType.noBall, extraRuns: 1);
    } else if (type == ExtraType.wide) {
      await _record(0, extraType: ExtraType.wide, extraRuns: extraRuns);
    } else {
      await _record(0, extraType: type, extraRuns: extraRuns);
    }
  }

  Future<void> _recordWicket() async {
    final result = await showModalBottomSheet<_WicketChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WicketSheet(
        striker: _strikerId,
        nonStriker: _nonStrikerId,
        includeRunOut: false,
      ),
    );
    if (result == null) return;
    await _record(
      0,
      wicketType: result.type,
      dismissedPlayerId: result.dismissedPlayerId,
      fielderId: result.fielder,
    );
  }

  Future<void> _recordRunOut() async {
    final result = await showModalBottomSheet<_WicketChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WicketSheet(
        striker: _strikerId,
        nonStriker: _nonStrikerId,
        includeRunOut: true,
        runOutOnly: true,
      ),
    );
    if (result == null) return;
    await _record(
      result.runsCompleted,
      extraType: result.extraType,
      extraRuns: result.extraRuns,
      wicketType: WicketType.runOut,
      dismissedPlayerId: result.dismissedPlayerId,
      fielderId: result.fielder,
    );
  }
}

class _PlayerField extends StatelessWidget {
  const _PlayerField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class _BallChip extends StatelessWidget {
  const _BallChip({required this.event});
  final BallEvent event;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (event.wicketType == WicketType.runOut) {
      label = 'RO';
      color = const Color(0xFFBF360C);
    } else if (event.wicketType != null) {
      label = 'W';
      color = AppColors.cricketRed;
    } else if (event.extraType == ExtraType.wide) {
      label = 'Wd';
      color = AppColors.accent;
    } else if (event.extraType == ExtraType.noBall) {
      label = 'Nb';
      color = AppColors.accent;
    } else if (event.runsOffBat == 4) {
      label = '4';
      color = const Color(0xFF1565C0);
    } else if (event.runsOffBat == 6) {
      label = '6';
      color = const Color(0xFF6A1B9A);
    } else {
      label = '${event.totalRuns}';
      color = AppColors.primary;
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _WicketChoice {
  const _WicketChoice({
    required this.type,
    required this.dismissedPlayerId,
    this.fielder,
    this.runsCompleted = 0,
  }) : extraType = null : extraRuns = 0;

  final WicketType type;
  final String dismissedPlayerId;
  final String? fielder;
  final int runsCompleted;
  final ExtraType? extraType;
  final int extraRuns;
}

class _WicketSheet extends StatefulWidget {
  const _WicketSheet({
    required this.striker,
    required this.nonStriker,
    this.includeRunOut = true,
    this.runOutOnly = false,
  });

  final String striker;
  final String nonStriker;
  final bool includeRunOut;
  final bool runOutOnly;

  @override
  State<_WicketSheet> createState() => _WicketSheetState();
}

class _WicketSheetState extends State<_WicketSheet> {
  late WicketType _type;
  late String _outPlayer;
  final _fielderController = TextEditingController();
  int _runsCompleted = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.runOutOnly ? WicketType.runOut : WicketType.bowled;
    _outPlayer = widget.striker;
  }

  @override
  void dispose() {
    _fielderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.runOutOnly
        ? const [WicketType.runOut]
        : [
            WicketType.bowled,
            WicketType.caught,
            WicketType.lbw,
            if (widget.includeRunOut) WicketType.runOut,
            WicketType.stumped,
            WicketType.hitWicket,
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.runOutOnly ? 'Run out' : 'How was the batter out?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final selected = _type == type;
              return ChoiceChip(
                label: Text(_labelFor(type)),
                selected: selected,
                onSelected: (_) => setState(() => _type = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Who is out?', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            dense: true,
            title: Text('Striker (${widget.striker})'),
            value: widget.striker,
            groupValue: _outPlayer,
            onChanged: (v) => setState(() => _outPlayer = v!),
          ),
          if (_type == WicketType.runOut)
            RadioListTile<String>(
              dense: true,
              title: Text('Non-striker (${widget.nonStriker})'),
              value: widget.nonStriker,
              groupValue: _outPlayer,
              onChanged: (v) => setState(() => _outPlayer = v!),
            ),
          if (_type == WicketType.runOut) ...[
            const SizedBox(height: 8),
            Text('Runs completed before run out', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [0, 1, 2, 3].map((runs) {
                return ChoiceChip(
                  label: Text('$runs'),
                  selected: _runsCompleted == runs,
                  onSelected: (_) => setState(() => _runsCompleted = runs),
                );
              }).toList(),
            ),
          ],
          if (_type == WicketType.caught ||
              _type == WicketType.runOut ||
              _type == WicketType.stumped) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _fielderController,
              decoration: InputDecoration(
                labelText: _type == WicketType.stumped ? 'Wicketkeeper (optional)' : 'Fielder (optional)',
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _WicketChoice(
                  type: _type,
                  dismissedPlayerId: _outPlayer,
                  fielder: _fielderController.text.trim().isEmpty
                      ? null
                      : _fielderController.text.trim(),
                  runsCompleted: _type == WicketType.runOut ? _runsCompleted : 0,
                ),
              );
            },
            child: Text(widget.runOutOnly ? 'Confirm run out' : 'Confirm wicket'),
          ),
        ],
      ),
    );
  }

  String _labelFor(WicketType type) {
    switch (type) {
      case WicketType.bowled:
        return 'Bowled';
      case WicketType.caught:
        return 'Caught';
      case WicketType.lbw:
        return 'LBW';
      case WicketType.runOut:
        return 'Run out';
      case WicketType.stumped:
        return 'Stumped';
      case WicketType.hitWicket:
        return 'Hit wicket';
      default:
        return type.name;
    }
  }
}

class _ExtraRunsSheet extends StatelessWidget {
  const _ExtraRunsSheet({required this.type});
  final ExtraType type;

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      ExtraType.wide => 'Wide extra runs',
      ExtraType.noBall => 'No-ball + runs off bat',
      ExtraType.bye => 'Bye runs',
      ExtraType.legBye => 'Leg-bye runs',
      ExtraType.penalty => 'Penalty runs',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            type == ExtraType.noBall
                ? '1 is already added as the no-ball. Choose extra runs scored off the bat.'
                : 'Includes the automatic extra run for wides.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final n in type == ExtraType.noBall ? [0, 1, 2, 3, 4, 6] : [1, 2, 3, 4, 5])
                ActionChip(
                  label: Text('$n'),
                  onPressed: () => Navigator.pop(context, n),
                ),
            ],
          ),
        ],
      ),
    );
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
    this.requiredRunRate,
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
  final double? requiredRunRate;

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
                  ? 'Target $target · Need $runsNeeded${requiredRunRate != null ? ' · RRR ${requiredRunRate!.toStringAsFixed(2)}' : ''}'
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
