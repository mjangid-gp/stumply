import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../matches/data/match_repository.dart';
import '../data/scoring_repository.dart';

class LiveScoreScreen extends ConsumerWidget {
  const LiveScoreScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Score')),
      body: StreamBuilder(
        stream: ref.watch(matchRepositoryProvider).watchMatch(matchId),
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) return const Center(child: CircularProgressIndicator());
          final match = matchSnap.data!;

          return StreamBuilder(
            stream: ref.watch(scoringRepositoryProvider).watchLiveState(matchId),
            builder: (context, liveSnap) {
              final live = liveSnap.data;
              final runs = live?.totalRuns ?? match.liveScore?['totalRuns'] ?? 0;
              final wickets = live?.wickets ?? match.liveScore?['wickets'] ?? 0;
              final overs = live?.oversDisplay ?? '${match.liveScore?['overs'] ?? 0}.${match.liveScore?['ballsInOver'] ?? 0}';

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('${match.teamAName} vs ${match.teamBName}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    Text('$runs/$wickets', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
                    Text('($overs overs)', style: Theme.of(context).textTheme.titleMedium),
                    if (live?.target != null) ...[
                      const SizedBox(height: 16),
                      Text('Target: ${live!.target}', style: const TextStyle(fontSize: 18)),
                      if (live.requiredRunRate != null)
                        Text('Required RR: ${live.requiredRunRate!.toStringAsFixed(2)}'),
                    ],
                    if (live != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Striker ${live.strikerId} · Non-striker ${live.nonStrikerId}',
                        textAlign: TextAlign.center,
                      ),
                      Text('Bowler ${live.bowlerId}'),
                    ],
                    const Spacer(),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, color: Colors.red, size: 12),
                        SizedBox(width: 8),
                        Text('LIVE'),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
