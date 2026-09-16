import 'package:flutter/material.dart';

class YoutubeEmbedPlayer extends StatelessWidget {
  const YoutubeEmbedPlayer({
    super.key,
    required this.videoId,
    this.onReady,
    this.onError,
  });

  final String videoId;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onError?.call('YouTube playback is not supported on this device.');
    });
    return const SizedBox.shrink();
  }
}
