import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/data/auth_repository.dart';
import '../../analytics/data/analytics_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const LoadingView(message: 'Loading profile...'),
        error: (e, _) => ErrorView(message: 'Could not load profile.', onRetry: () => ref.invalidate(currentUserProfileProvider)),
        data: (profile) {
          if (profile == null || user == null) {
            return const EmptyStateView(icon: Icons.person_off, title: 'No profile', message: 'Profile not found.');
          }
          return FutureBuilder(
            future: ref.read(analyticsRepositoryProvider).getPlayerAnalytics(user.uid),
            builder: (context, snapshot) {
              final analytics = snapshot.data;
              final initial = profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?';

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: CrickGradientHeader(
                      title: profile.displayName,
                      subtitle: profile.city.isNotEmpty ? profile.city : 'Cricket Player',
                      trailing: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () => context.push('/notifications'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white),
                          onPressed: () => context.push('/profile/edit'),
                        ),
                      ],
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                            child: profile.photoUrl == null
                                ? Text(initial, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          if (profile.isPro)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('PRO', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            StatChip(label: 'Matches', value: '${analytics?.matches ?? 0}', icon: Icons.sports_cricket),
                            const SizedBox(width: 10),
                            StatChip(label: 'Runs', value: '${analytics?.runs ?? 0}', icon: Icons.trending_up),
                            const SizedBox(width: 10),
                            StatChip(label: 'Wickets', value: '${analytics?.wickets ?? 0}', icon: Icons.sports),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            StatChip(label: 'Avg', value: analytics?.battingAverage.toStringAsFixed(1) ?? '0'),
                            const SizedBox(width: 10),
                            StatChip(label: 'SR', value: analytics?.strikeRate.toStringAsFixed(1) ?? '0'),
                            const SizedBox(width: 10),
                            StatChip(label: 'Econ', value: analytics?.economy.toStringAsFixed(1) ?? '0'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _MenuTile(icon: Icons.insights, title: 'CricInsights', subtitle: 'Advanced analytics', onTap: () => context.push('/analytics')),
                        _MenuTile(icon: Icons.groups, title: 'My Teams', subtitle: 'Manage your squads', onTap: () => context.push('/teams')),
                        _MenuTile(icon: Icons.star, title: 'PRO Club', subtitle: 'Unlock premium features', onTap: () => context.push('/pro')),
                        _MenuTile(icon: Icons.shopping_bag_outlined, title: 'Store', subtitle: 'Cricket gear & apparel', onTap: () => context.push('/store')),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => ref.read(authRepositoryProvider).signOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                        ),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CrickCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
