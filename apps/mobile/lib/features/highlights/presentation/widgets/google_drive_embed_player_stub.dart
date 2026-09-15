import 'package:flutter/material.dart';

/// Fallback when platform implementation is unavailable.
class GoogleDriveEmbedPlayer extends StatelessWidget {
  const GoogleDriveEmbedPlayer({
    super.key,
    required this.fileId,
    this.onLoaded,
    this.onError,
  });

  final String fileId;
  final VoidCallback? onLoaded;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onError?.call('Video playback is not supported on this device.');
    });
    return const SizedBox.shrink();
  }
}
