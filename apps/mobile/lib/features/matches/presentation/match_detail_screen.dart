import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/match_helpers.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../../shared/models/match_model.dart';
import '../data/match_repository.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  String? _tossWinnerId;
  String _tossDecision = 'bat';
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder(
        stream: ref.watch(matchRepositoryProvider).watchMatch(widget.matchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final match = snapshot.data;
          if (match == null) {
            return const EmptyStateView(
              icon: Icons.error_outline,
              title: 'Match not found',
              message: 'This match may have been deleted.',
            );
          }

          _tossWinnerId ??= match.teamAId;

          return Column(
            children: [
              CrickGradientHeader(
                title: '${match.teamAName} vs ${match.teamBName}',
                subtitle: match.ground.isNotEmpty ? match.ground : '${match.totalOvers} overs',
                child: match.isLive
                    ? const Align(alignment: Alignment.centerLeft, child: LiveBadge())
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CrickCard(
                        child: Column(
                          children: [
                            _InfoRow(label: 'Status', value: _statusLabel(match.status)),
                            const Divider(),
                            _InfoRow(label: 'Format', value: '${match.totalOvers} overs'),
                            if (match.tossWinnerId != null) ...[
                              const Divider(),
                              _InfoRow(label: 'Toss', value: tossSummary(match)),
                            ],
                            if (match.result != null) ...[
                              const Divider(),
                              _InfoRow(label: 'Result', value: match.result!, highlight: true),
                            ],
                          ],
                        ),
                      ),
                      if (match.status == 'scheduled') ...[
                        const SizedBox(height: 20),
                        CrickCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toss',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Who won the toss and what did they choose?',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              Text('Toss winner', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(value: match.teamAId, label: Text(match.teamAName)),
                                  ButtonSegment(value: match.teamBId, label: Text(match.teamBName)),
                                ],
                                selected: {_tossWinnerId!},
                                onSelectionChanged: (s) => setState(() => _tossWinnerId = s.first),
                              ),
                              const SizedBox(height: 16),
                              Text('Elected to', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'bat', label: Text('Bat'), icon: Icon(Icons.sports_cricket)),
                                  ButtonSegment(value: 'bowl', label: Text('Bowl'), icon: Icon(Icons.sports_baseball)),
                                ],
                                selected: {_tossDecision},
                                onSelectionChanged: (s) => setState(() => _tossDecision = s.first),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (match.status == 'scheduled')
                        ElevatedButton.icon(
                          onPressed: _starting ? null : () => _startMatch(context, match),
                          icon: _starting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(_starting ? 'Starting...' : 'Start Match & Score'),
                        ),
                      if (match.isLive) ...[
                        ElevatedButton.icon(
                          onPressed: () => context.push('/matches/${widget.matchId}/score'),
                          icon: const Icon(Icons.sports_cricket),
                          label: const Text('Continue Scoring'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/matches/${widget.matchId}/live'),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Live Score'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startMatch(BuildContext context, MatchModel match) async {
    setState(() => _starting = true);
    try {
      await ref.read(matchRepositoryProvider).startMatch(
        widget.matchId,
        tossWinnerId: _tossWinnerId!,
        tossDecision: _tossDecision,
      );
      if (context.mounted) context.push('/matches/${widget.matchId}/score');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'Live';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
