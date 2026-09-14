import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/match_repository.dart';

class MyMatchesScreen extends ConsumerWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CrickGradientHeader(
            title: 'My Cricket',
            subtitle: 'Your matches, teams & scores',
            trailing: [
              IconButton(
                icon: const Icon(Icons.groups_outlined, color: Colors.white),
                onPressed: () => context.push('/teams'),
                tooltip: 'My Teams',
              ),
            ],
          ),
          Expanded(
            child: user == null
                ? const EmptyStateView(
                    icon: Icons.login,
                    title: 'Sign in required',
                    message: 'Please sign in to view your matches.',
                  )
                : StreamBuilder(
                    stream: ref.watch(matchRepositoryProvider).watchUserMatches(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return ErrorView(
                          message: 'Could not load matches. Please try again.',
                          onRetry: () => ref.invalidate(matchRepositoryProvider),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(message: 'Loading matches...');
                      }
                      final matches = snapshot.data ?? [];
                      if (matches.isEmpty) {
                        return EmptyStateView(
                          icon: Icons.sports_cricket,
                          title: 'No matches yet',
                          message: 'Start scoring your first match and build your cricket story.',
                          actionLabel: 'Start Match',
                          onAction: () => context.push('/matches/create'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final match = matches[i];
                          final live = match.liveScore;
                          return CrickCard(
                            onTap: () => context.push('/matches/${match.id}'),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.sports_cricket, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${match.teamAName} vs ${match.teamBName}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        match.isLive && live != null
                                            ? '${live['totalRuns']}/${live['wickets']} (${live['overs']}.${live['ballsInOver']} ov)'
                                            : match.result ?? _formatStatus(match.status),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                      if (match.ground.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          match.ground,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (match.isLive)
                                  const LiveBadge()
                                else
                                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/matches/create'),
        icon: const Icon(Icons.add),
        label: const Text('Start Match'),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
