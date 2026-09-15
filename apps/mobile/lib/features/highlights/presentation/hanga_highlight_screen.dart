import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/google_drive_embed_player.dart';

class HangaHighlightScreen extends StatefulWidget {
  const HangaHighlightScreen({super.key});

  @override
  State<HangaHighlightScreen> createState() => _HangaHighlightScreenState();
}

class _HangaHighlightScreenState extends State<HangaHighlightScreen> {
  static const _fileId = AppConstants.hangaHighlightDriveFileId;

  bool _loading = true;
  String? _error;
  Timer? _loadTimeout;
  int _attempt = 0;

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  void _startLoadTimer() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = _userMessage;
        });
      }
    });
  }

  static const _userMessage =
      'Unable to play this highlight right now. Please try again.';

  void _onLoaded() {
    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  void _onError(String _) {
    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() {
      _loading = false;
      _error = _userMessage;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _attempt++;
    });
    _startLoadTimer();
  }

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hanga Highlight'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? _ErrorView(message: _error!, onRetry: _retry)
          : Stack(
              fit: StackFit.expand,
              children: [
                GoogleDriveEmbedPlayer(
                  key: ValueKey('hanga-highlight-$_attempt'),
                  fileId: _fileId,
                  onLoaded: _onLoaded,
                  onError: _onError,
                ),
                if (_loading)
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.accent),
                          SizedBox(height: 16),
                          Text(
                            'Loading highlight...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
