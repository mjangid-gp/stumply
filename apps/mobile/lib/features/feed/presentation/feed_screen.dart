import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../data/feed_repository.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb) return;
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, _) { ad.dispose(); },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(iconColor: Colors.white),
        title: const Text('Cricket Feed'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<LiveCricketMatch>>(
              stream: ref.watch(liveCricketRepositoryProvider).watchLiveMatches(),
              builder: (context, liveSnapshot) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ref.watch(feedRepositoryProvider).watchFeed(),
                  builder: (context, feedSnapshot) {
                    if (feedSnapshot.connectionState == ConnectionState.waiting &&
                        liveSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final posts = feedSnapshot.data ?? [];
                    final liveMatches = liveSnapshot.data ?? [];
                    if (posts.isEmpty && liveMatches.isEmpty) {
                      return const Center(child: Text('No live matches or posts right now.'));
                    }
                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (liveMatches.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: Colors.red, size: 12),
                                SizedBox(width: 8),
                                Text('LIVE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                                Spacer(),
                                Text('Updates every 3 sec'),
                              ],
                            ),
                          ),
                          ...liveMatches.map((match) => _LiveMatchCard(match: match)),
                        ],
                        ...posts.map((post) => Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(post['title'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    Text(post['body'] as String? ?? ''),
                                    if (post['type'] == 'poll') const Chip(label: Text('Poll')),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_bannerAd != null)
            SizedBox(width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
        ],
      ),
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  const _LiveMatchCard({required this.match});
  final LiveCricketMatch match;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(match.status, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...match.scores.map((score) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(score, style: Theme.of(context).textTheme.titleLarge),
                )),
            if (match.venue != null) Text(match.venue!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
