import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../matches/data/match_repository.dart';
import '../data/streaming_repository.dart';

class StreamingScreen extends ConsumerStatefulWidget {
  const StreamingScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends ConsumerState<StreamingScreen> {
  bool _broadcasting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final streaming = ref.watch(streamingRepositoryProvider);
    final matchAsync = ref.watch(matchRepositoryProvider).watchMatch(widget.matchId);
    final agoraConfigured = !AppConstants.agoraAppIdPlaceholder.startsWith('YOUR_');

    return Scaffold(
      appBar: AppBar(title: const Text('Live Broadcast')),
      body: StreamBuilder(
        stream: matchAsync,
        builder: (context, snapshot) {
          final match = snapshot.data;
          if (match == null) {
            return const EmptyStateView(
              icon: Icons.error_outline,
              title: 'Match not found',
              message: 'This match may have been deleted.',
            );
          }

          if (!match.isLive) {
            return EmptyStateView(
              icon: Icons.videocam_off_outlined,
              title: 'Match not live',
              message: 'Start the match and begin scoring before you can broadcast.',
              actionLabel: 'Open Match',
              onAction: () => Navigator.of(context).pop(),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CrickCard(
                  child: Column(
                    children: [
                      Text(
                        '${match.teamAName} vs ${match.teamBName}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const LiveBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _broadcasting ? Icons.videocam : Icons.videocam_off_outlined,
                          size: 72,
                          color: _broadcasting ? Colors.redAccent : Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _broadcasting ? 'You are live' : 'Camera preview',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        if (!agoraConfigured) ...[
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Set your Agora App ID in AppConstants to enable real camera streaming.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (user != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: agoraConfigured
                          ? () async {
                              if (_broadcasting) {
                                await streaming.stopBroadcast();
                              } else {
                                await streaming.startBroadcast(
                                  matchId: widget.matchId,
                                  userId: user.uid,
                                );
                              }
                              setState(() => _broadcasting = streaming.isBroadcasting);
                            }
                          : null,
                      icon: Icon(_broadcasting ? Icons.stop : Icons.play_arrow),
                      label: Text(_broadcasting ? 'Stop Broadcast' : 'Start Broadcast'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: agoraConfigured
                          ? () => streaming.joinAsViewer(
                                matchId: widget.matchId,
                                userId: user.uid,
                              )
                          : null,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Watch as Viewer'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
