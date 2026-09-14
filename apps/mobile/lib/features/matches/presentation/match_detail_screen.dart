import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../data/match_repository.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder(
        stream: ref.watch(matchRepositoryProvider).watchMatch(matchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final match = snapshot.data;
          if (match == null) {
            return const EmptyStateView(icon: Icons.error_outline, title: 'Match not found', message: 'This match may have been deleted.');
          }

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
                            if (match.tossDecision != null) ...[
                              const Divider(),
                              _InfoRow(label: 'Toss', value: match.tossDecision!),
                            ],
                            if (match.result != null) ...[
                              const Divider(),
                              _InfoRow(label: 'Result', value: match.result!, highlight: true),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (match.status == 'scheduled')
                        ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(matchRepositoryProvider).startMatch(
                              matchId,
                              tossWinnerId: match.teamAId,
                              tossDecision: 'bat',
                            );
                            if (context.mounted) context.push('/matches/$matchId/score');
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Scoring'),
                        ),
                      if (match.isLive) ...[
                        ElevatedButton.icon(
                          onPressed: () => context.push('/matches/$matchId/score'),
                          icon: const Icon(Icons.sports_cricket),
                          label: const Text('Continue Scoring'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/matches/$matchId/live'),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Live Score'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/streaming/$matchId'),
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Live Stream'),
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
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
