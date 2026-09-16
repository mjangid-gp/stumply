import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  static int _viewCounter = 0;
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-embed-${widget.videoId}-${_viewCounter++}';
    _register();
  }

  void _register() {
    try {
      final src = YoutubeVideo.embedUrl(widget.videoId);
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        return web.HTMLIFrameElement()
          ..src = src
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..setAttribute(
            'allow',
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen',
          );
      });
      _registered = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onReady?.call();
      });
    } catch (_) {
      widget.onError?.call('Unable to start YouTube player.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) return const SizedBox.shrink();
    return HtmlElementView(viewType: _viewType);
  }
}
