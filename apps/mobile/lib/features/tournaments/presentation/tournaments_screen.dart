import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/tournament_repository.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const CrickGradientHeader(
            title: 'Tournaments',
            subtitle: 'Organize leagues & track standings',
            leading: DrawerMenuButton(),
          ),
          Expanded(
            child: StreamBuilder(
              stream: ref.watch(tournamentRepositoryProvider).watchTournaments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading tournaments...');
                }
                if (snapshot.hasError) {
                  return ErrorView(message: 'Could not load tournaments.', onRetry: () => ref.invalidate(tournamentRepositoryProvider));
                }
                final tournaments = snapshot.data ?? [];
                if (tournaments.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.emoji_events_outlined,
                    title: 'No tournaments yet',
                    message: 'Create a tournament and invite teams to compete.',
                    actionLabel: 'Create Tournament',
                    onAction: () => context.push('/tournaments/create'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tournaments.length,
                  itemBuilder: (context, i) {
                    final t = tournaments[i];
                    return CrickCard(
                      onTap: () => context.push('/tournaments/${t.id}'),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.emoji_events, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  '${t.city.isNotEmpty ? '${t.city} · ' : ''}${_formatLabel(t.format)} · ${t.teamIds.length} teams',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.status,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
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
        onPressed: () => context.push('/tournaments/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  String _formatLabel(String format) {
    switch (format) {
      case 'round_robin':
        return 'Round Robin';
      case 'knockout':
        return 'Knockout';
      default:
        return format;
    }
  }
}
