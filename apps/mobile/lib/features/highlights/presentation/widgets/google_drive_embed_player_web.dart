import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  static int _viewCounter = 0;
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'hanga-highlight-${widget.fileId}-${_viewCounter++}';
    _registerPlayer();
  }

  void _registerPlayer() {
    try {
      final previewUrl = GoogleDriveVideo.previewUrl(widget.fileId);
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = previewUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..setAttribute('allow', 'autoplay; fullscreen');

        return iframe;
      });
      _registered = true;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) widget.onLoaded?.call();
      });
    } catch (_) {
      widget.onError?.call('Unable to load highlight video.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: _viewType);
  }
}
