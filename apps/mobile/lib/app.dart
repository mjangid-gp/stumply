import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/matches/presentation/create_match_screen.dart';
import '../../features/matches/presentation/match_detail_screen.dart';
import '../../features/matches/presentation/my_matches_screen.dart';
import '../../features/matches/presentation/select_players_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/scoring/presentation/live_score_screen.dart';
import '../../features/scoring/presentation/scoring_screen.dart';
import '../../features/store/presentation/store_screen.dart';
import '../../features/streaming/presentation/broadcast_hub_screen.dart';
import '../../features/streaming/presentation/streaming_screen.dart';
import '../../features/subscription/presentation/pro_screen.dart';
import '../../features/teams/presentation/create_team_screen.dart';
import '../../features/teams/presentation/teams_screen.dart';
import '../../features/tournaments/presentation/create_tournament_screen.dart';
import '../../features/tournaments/presentation/tournament_detail_screen.dart';
import '../../features/tournaments/presentation/tournaments_screen.dart';
import '../../shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const MyMatchesScreen()),
          GoRoute(
            path: '/tournaments',
            builder: (_, __) => const TournamentsScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (_, __) => const DiscoverScreen(),
          ),
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/broadcast',
            builder: (_, __) => const BroadcastHubScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(path: '/teams', builder: (_, __) => const TeamsScreen()),
      GoRoute(
        path: '/teams/create',
        builder: (_, __) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/matches/create',
        builder: (_, __) => const CreateMatchScreen(),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (_, state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/squad',
        builder: (_, state) =>
            SelectPlayersScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/score',
        builder: (_, state) =>
            ScoringScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/live',
        builder: (_, state) =>
            LiveScoreScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments/create',
        builder: (_, __) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (_, state) =>
            TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/pro', builder: (_, __) => const ProScreen()),
      GoRoute(path: '/store', builder: (_, __) => const StoreScreen()),
      GoRoute(
        path: '/streaming/:matchId',
        builder: (_, state) =>
            StreamingScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
    ],
  );
});

class CrickApp extends ConsumerWidget {
  const CrickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Stumply',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    );
  }
}
