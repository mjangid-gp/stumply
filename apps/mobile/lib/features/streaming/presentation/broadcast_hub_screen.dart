import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/youtube_video.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../matches/data/match_repository.dart';
import '../data/youtube_stream_repository.dart';
import 'widgets/youtube_embed_player.dart';

class BroadcastHubScreen extends ConsumerStatefulWidget {
  const BroadcastHubScreen({super.key});

  @override
  ConsumerState<BroadcastHubScreen> createState() => _BroadcastHubScreenState();
}

class _BroadcastHubScreenState extends ConsumerState<BroadcastHubScreen> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String? _playingVideoId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _playFromField() {
    final id = YoutubeVideo.idFromUrl(_urlController.text);
    if (id == null) {
      setState(() {
        _error = 'Paste a valid YouTube link, for example youtube.com/watch?v=... or youtube.com/live/...';
        _playingVideoId = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _playingVideoId = id;
    });
  }

  Future<void> _shareStream() async {
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(currentUserProfileProvider).value;
    final id = YoutubeVideo.idFromUrl(_urlController.text) ?? _playingVideoId;
    if (user == null || id == null) {
      setState(() => _error = 'Play a valid YouTube link first, then share it.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(youtubeStreamRepositoryProvider).publish(
        videoId: id,
        url: _urlController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? 'YouTube live stream'
            : _titleController.text.trim(),
        userId: user.uid,
        userName: profile?.displayName ?? user.email ?? 'Player',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stream shared in Broadcast Studio')),
        );
      }
    } catch (_) {
      setState(() => _error = 'Could not share this stream. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final agoraConfigured = !AppConstants.agoraAppIdPlaceholder.startsWith('YOUR_');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(iconColor: AppColors.primary),
        title: const Text('Broadcast Studio'),
      ),
      body: user == null
          ? const EmptyStateView(
              icon: Icons.login,
              title: 'Sign in required',
              message: 'Sign in to start or watch live broadcasts.',
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CrickCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Play a YouTube live link',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Paste any YouTube live or video URL. It will play inside Stumply.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'YouTube live link',
                          hintText: 'https://www.youtube.com/watch?v=...',
                          prefixIcon: Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                        onSubmitted: (_) => _playFromField(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Stream title (optional)',
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: AppColors.cricketRed)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _playFromField,
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text('Play in app'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _shareStream,
                              icon: const Icon(Icons.share_outlined),
                              label: Text(_saving ? 'Sharing...' : 'Share stream'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_playingVideoId != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ColoredBox(
                        color: Colors.black,
                        child: YoutubeEmbedPlayer(
                          key: ValueKey(_playingVideoId),
                          videoId: _playingVideoId!,
                          onError: (message) => setState(() => _error = message),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Shared YouTube streams',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: ref.watch(youtubeStreamRepositoryProvider).watchLiveStreams(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Shared streams will appear here after the first link is posted.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    final streams = snapshot.data ?? [];
                    if (streams.isEmpty) {
                      return const Text(
                        'No shared streams yet. Play a YouTube link and tap Share stream.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    return Column(
                      children: streams.map((stream) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CrickCard(
                            onTap: () => setState(() {
                              _playingVideoId = stream.videoId;
                              _urlController.text = stream.url;
                              _titleController.text = stream.title;
                              _error = null;
                            }),
                            child: ListTile(
                              leading: const Icon(Icons.ondemand_video, color: AppColors.cricketRed),
                              title: Text(stream.title),
                              subtitle: Text(
                                stream.createdByName.isEmpty
                                    ? 'Tap to play in app'
                                    : '${stream.createdByName} · Tap to play in app',
                              ),
                              trailing: const Icon(Icons.play_arrow),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Camera broadcast',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: ref.watch(matchRepositoryProvider).watchUserMatches(user.uid),
                  builder: (context, snapshot) {
                    final matches = (snapshot.data ?? []).where((m) => m.isLive).toList();
                    if (matches.isEmpty) {
                      return CrickCard(
                        child: Column(
                          children: [
                            const Text(
                              'Start scoring a match if you also want to open camera broadcast.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/'),
                              icon: const Icon(Icons.sports_cricket_outlined),
                              label: const Text('Go to My Matches'),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        if (!agoraConfigured)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Camera streaming needs an Agora App ID. YouTube links work without it.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ...matches.map(
                          (match) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CrickCard(
                              child: ListTile(
                                leading: const LiveBadge(),
                                title: Text('${match.teamAName} vs ${match.teamBName}'),
                                subtitle: Text(match.ground.isNotEmpty ? match.ground : '${match.totalOvers} overs'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/streaming/${match.id}'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
