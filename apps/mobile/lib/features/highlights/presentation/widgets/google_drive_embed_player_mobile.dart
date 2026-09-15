import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/google_drive_video.dart';

class GoogleDriveEmbedPlayer extends StatefulWidget {
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
  State<GoogleDriveEmbedPlayer> createState() => _GoogleDriveEmbedPlayerState();
}

class _GoogleDriveEmbedPlayerState extends State<GoogleDriveEmbedPlayer> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final previewUrl = GoogleDriveVideo.previewUrl(widget.fileId);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => widget.onLoaded?.call(),
            onWebResourceError: (error) {
              if (error.isForMainFrame ?? false) {
                widget.onError?.call('Unable to load highlight video.');
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(previewUrl));

      if (mounted) {
        setState(() => _controller = controller);
      }
    } catch (_) {
      widget.onError?.call('Unable to start video player.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }
    return WebViewWidget(controller: _controller!);
  }
}
