import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_engine/scoring_engine.dart';
import '../data/tournament_repository.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tournamentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: StreamBuilder(
        stream: repo.watchTournament(tournamentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tournament = snapshot.data;
          if (tournament == null) return const Center(child: Text('Not found'));

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(tournament.name, style: Theme.of(context).textTheme.headlineSmall),
                      Text('${tournament.city} · ${tournament.format}'),
                      Text('${tournament.teamIds.length} teams registered'),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Fixtures'),
                    Tab(text: 'Points'),
                    Tab(text: 'Leaderboard'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _FixturesTab(tournamentId: tournamentId, repo: repo),
                      _PointsTab(pointsTable: tournament.pointsTable),
                      _LeaderboardTab(tournamentId: tournamentId),
                    ],
                  ),
                ),
                if (tournament.teamIds.length >= 2)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        await repo.generateFixtures(
                          tournamentId: tournamentId,
                          teamIds: tournament.teamIds,
                          format: tournament.format,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fixtures generated!')),
                        );
                      },
                      child: const Text('Generate Fixtures'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({required this.tournamentId, required this.repo});
  final String tournamentId;
  final TournamentRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repo.watchTournamentMatches(tournamentId),
      builder: (context, snapshot) {
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) return const Center(child: Text('No fixtures yet'));
        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, i) {
            final m = matches[i];
            return ListTile(
              title: Text('${m['teamAName'] ?? m['teamAId']} vs ${m['teamBName'] ?? m['teamBId']}'),
              subtitle: Text('Round ${m['round'] ?? '-'} · ${m['status']}'),
            );
          },
        );
      },
    );
  }
}

class _PointsTab extends StatelessWidget {
  const _PointsTab({required this.pointsTable});
  final Map<String, dynamic> pointsTable;

  @override
  Widget build(BuildContext context) {
    if (pointsTable.isEmpty) {
      return const Center(child: Text('Points table will appear after matches'));
    }
    final entries = pointsTable.entries.toList();
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final data = e.value as Map<String, dynamic>;
        final entry = PointsTableEntry(
          teamId: e.key,
          played: data['played'] as int? ?? 0,
          won: data['won'] as int? ?? 0,
          lost: data['lost'] as int? ?? 0,
          tied: data['tied'] as int? ?? 0,
          noResult: data['noResult'] as int? ?? 0,
          runsScored: data['runsScored'] as int? ?? 0,
          oversFaced: (data['oversFaced'] as num?)?.toDouble() ?? 0,
          runsConceded: data['runsConceded'] as int? ?? 0,
          oversBowled: (data['oversBowled'] as num?)?.toDouble() ?? 0,
        );
        return ListTile(
          leading: Text('${i + 1}'),
          title: Text(e.key),
          subtitle: Text('P${entry.played} W${entry.won} L${entry.lost}'),
          trailing: Text('${entry.totalPoints} pts\nNRR ${entry.nrr.toStringAsFixed(2)}', textAlign: TextAlign.end),
        );
      },
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Boundary tracker & top performers'));
  }
}
