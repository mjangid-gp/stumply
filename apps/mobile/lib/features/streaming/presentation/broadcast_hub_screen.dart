import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../matches/data/match_repository.dart';

class BroadcastHubScreen extends ConsumerWidget {
  const BroadcastHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final agoraConfigured = !AppConstants.agoraAppIdPlaceholder.startsWith('YOUR_');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(iconColor: AppColors.primary),
        title: const Text('Broadcast Studio'),
      ),
      body: user == null
          ? const EmptyStateView(
              icon: Icons.login,
              title: 'Sign in required',
              message: 'Sign in to start or watch live broadcasts.',
            )
          : StreamBuilder(
              stream: ref.watch(matchRepositoryProvider).watchUserMatches(user.uid),
              builder: (context, snapshot) {
                final matches = (snapshot.data ?? []).where((m) => m.isLive).toList();

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    CrickCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.videocam, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Go live from a match',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  agoraConfigured
                                      ? 'Pick a live match below to start your camera broadcast.'
                                      : 'Add your Agora App ID in AppConstants to enable real streaming.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your live matches',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (matches.isEmpty)
                      const EmptyStateView(
                        icon: Icons.live_tv_outlined,
                        title: 'No live matches',
                        message: 'Start scoring a match first, then come back here to broadcast it.',
                      )
                    else
                      ...matches.map(
                        (match) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CrickCard(
                            child: ListTile(
                              leading: const LiveBadge(),
                              title: Text('${match.teamAName} vs ${match.teamBName}'),
                              subtitle: Text(match.ground.isNotEmpty ? match.ground : '${match.totalOvers} overs'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/streaming/${match.id}'),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.sports_cricket_outlined),
                      label: const Text('Go to My Matches'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
