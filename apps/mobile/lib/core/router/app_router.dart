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
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MyMatchesScreen()),
          GoRoute(
            path: '/tournaments',
            builder: (_, _) => const TournamentsScreen(),
          ),
          GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
          GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/broadcast',
            builder: (_, _) => const BroadcastHubScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(path: '/teams', builder: (_, _) => const TeamsScreen()),
      GoRoute(
        path: '/teams/create',
        builder: (_, _) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/matches/create',
        builder: (_, _) => const CreateMatchScreen(),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (_, state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
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
        builder: (_, _) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (_, state) =>
            TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
      GoRoute(path: '/pro', builder: (_, _) => const ProScreen()),
      GoRoute(path: '/store', builder: (_, _) => const StoreScreen()),
      GoRoute(
        path: '/streaming/:matchId',
        builder: (_, state) =>
            StreamingScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
});
