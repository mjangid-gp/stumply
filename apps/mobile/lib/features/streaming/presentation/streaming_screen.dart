import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Live Stream')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _broadcasting ? Icons.videocam : Icons.videocam_off,
              size: 80,
              color: _broadcasting ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(_broadcasting ? 'Broadcasting live' : 'Stream not active'),
            const SizedBox(height: 24),
            if (user != null)
              ElevatedButton(
                onPressed: () async {
                  if (_broadcasting) {
                    await streaming.stopBroadcast();
                  } else {
                    await streaming.startBroadcast(matchId: widget.matchId, userId: user.uid);
                  }
                  setState(() => _broadcasting = streaming.isBroadcasting);
                },
                child: Text(_broadcasting ? 'Stop Broadcast' : 'Start Broadcast'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => streaming.joinAsViewer(matchId: widget.matchId, userId: user?.uid ?? 'guest'),
              child: const Text('Watch as Viewer'),
            ),
            const SizedBox(height: 24),
            const Text('Configure Agora App ID in AppConstants', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
