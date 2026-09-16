import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/youtube_video.dart';

class YoutubeEmbedPlayer extends StatefulWidget {
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
  State<YoutubeEmbedPlayer> createState() => _YoutubeEmbedPlayerState();
}

class _YoutubeEmbedPlayerState extends State<YoutubeEmbedPlayer> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => widget.onReady?.call(),
            onWebResourceError: (error) {
              if (error.isForMainFrame ?? false) {
                widget.onError?.call('Unable to load this YouTube stream.');
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(YoutubeVideo.embedUrl(widget.videoId)));
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      widget.onError?.call('Unable to start YouTube player.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();
    return WebViewWidget(controller: _controller!);
  }
}
