import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/crick_ui.dart';
import '../data/feed_repository.dart';

enum _FeedFilter { all, live, upcoming, news }

enum _CategoryFilter { all, international, india, domestic, league }

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  BannerAd? _bannerAd;
  _FeedFilter _filter = _FeedFilter.all;
  _CategoryFilter _category = _CategoryFilter.all;

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
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
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
          _buildFilters(),
          Expanded(
            child: StreamBuilder<CricketFeedSnapshot>(
              stream: ref
                  .watch(liveCricketRepositoryProvider)
                  .watchCricketFeed(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null) {
                  return const _EmptyFeed(message: 'Loading cricket feed...');
                }

                final matches = _filterMatches(data.matches);
                final news = _filterNews(data.news);

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ref.watch(feedRepositoryProvider).watchFeed(),
                  builder: (context, postSnapshot) {
                    final communityPosts = _filter == _FeedFilter.news
                        ? const <Map<String, dynamic>>[]
                        : (postSnapshot.data ?? const <Map<String, dynamic>>[]);
                    final hasContent =
                        matches.isNotEmpty ||
                        news.isNotEmpty ||
                        communityPosts.isNotEmpty;

                    if (!hasContent) {
                      return _EmptyFeed(
                        message:
                            data.errorMessage ??
                            'No live matches, upcoming matches or cricket news right now.',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(liveCricketRepositoryProvider)
                            .fetchCricketFeed();
                        if (mounted) setState(() {});
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        children: [
                          if (_filter != _FeedFilter.news) ...[
                            if (matches.any((match) => match.isLive))
                              _SectionHeader(
                                icon: Icons.circle,
                                iconColor: Colors.red,
                                title: 'LIVE NOW',
                                trailing: 'Auto refresh: 60 sec',
                              ),
                            ...matches
                                .where((match) => match.isLive)
                                .map(_LiveMatchCard.new),
                            if (_filter == _FeedFilter.all ||
                                _filter == _FeedFilter.upcoming) ...[
                              if (matches.any((match) => match.isUpcoming))
                                const _SectionHeader(
                                  icon: Icons.calendar_month,
                                  title: 'UPCOMING MATCHES',
                                ),
                              ...matches
                                  .where((match) => match.isUpcoming)
                                  .map(_UpcomingMatchCard.new),
                            ],
                          ],
                          if (_filter == _FeedFilter.all ||
                              _filter == _FeedFilter.news) ...[
                            if (news.isNotEmpty)
                              const _SectionHeader(
                                icon: Icons.article_outlined,
                                title: 'CRICKET NEWS',
                              ),
                            ...news.map(_NewsCard.new),
                          ],
                          if (_filter == _FeedFilter.all &&
                              communityPosts.isNotEmpty) ...[
                            const _SectionHeader(
                              icon: Icons.groups_outlined,
                              title: 'STUMPLY COMMUNITY',
                            ),
                            ...communityPosts.map(
                              (post) => _CommunityPostCard(post: post),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Material(
      elevation: 1,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _FeedFilter.all,
                  onSelected: () => setState(() => _filter = _FeedFilter.all),
                ),
                _FilterChip(
                  label: '🔴 Live',
                  selected: _filter == _FeedFilter.live,
                  onSelected: () => setState(() => _filter = _FeedFilter.live),
                ),
                _FilterChip(
                  label: 'Upcoming',
                  selected: _filter == _FeedFilter.upcoming,
                  onSelected: () =>
                      setState(() => _filter = _FeedFilter.upcoming),
                ),
                _FilterChip(
                  label: 'News',
                  selected: _filter == _FeedFilter.news,
                  onSelected: () => setState(() => _filter = _FeedFilter.news),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _category == _CategoryFilter.all,
                  onSelected: () =>
                      setState(() => _category = _CategoryFilter.all),
                ),
                _CategoryChip(
                  label: 'International',
                  selected: _category == _CategoryFilter.international,
                  onSelected: () =>
                      setState(() => _category = _CategoryFilter.international),
                ),
                _CategoryChip(
                  label: 'India',
                  selected: _category == _CategoryFilter.india,
                  onSelected: () =>
                      setState(() => _category = _CategoryFilter.india),
                ),
                _CategoryChip(
                  label: 'Domestic',
                  selected: _category == _CategoryFilter.domestic,
                  onSelected: () =>
                      setState(() => _category = _CategoryFilter.domestic),
                ),
                _CategoryChip(
                  label: 'Leagues',
                  selected: _category == _CategoryFilter.league,
                  onSelected: () =>
                      setState(() => _category = _CategoryFilter.league),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<LiveCricketMatch> _filterMatches(List<LiveCricketMatch> matches) {
    return matches.where((match) {
      final statusMatches = switch (_filter) {
        _FeedFilter.all => true,
        _FeedFilter.live => match.isLive,
        _FeedFilter.upcoming => match.isUpcoming,
        _FeedFilter.news => false,
      };
      return statusMatches && _categoryMatches(match.category);
    }).toList();
  }

  List<CricketNewsArticle> _filterNews(List<CricketNewsArticle> news) {
    if (_filter == _FeedFilter.live || _filter == _FeedFilter.upcoming) {
      return const [];
    }
    return news.where((article) => _categoryMatches(article.category)).toList();
  }

  bool _categoryMatches(CricketCategory category) {
    return switch (_category) {
      _CategoryFilter.all => true,
      _CategoryFilter.international =>
        category == CricketCategory.international,
      _CategoryFilter.india => category == CricketCategory.india,
      _CategoryFilter.domestic => category == CricketCategory.domestic,
      _CategoryFilter.league => category == CricketCategory.league,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  const _LiveMatchCard(this.match);

  final LiveCricketMatch match;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.red, size: 9),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    match.seriesName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  _categoryLabel(match.category),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              match.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...match.scores.map(
              (score) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(score.name)),
                    Text(
                      score.score ?? '-',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (match.detail != null) ...[
              const SizedBox(height: 3),
              Text(
                match.detail!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (match.venue != null) ...[
              const SizedBox(height: 5),
              Text(match.venue!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingMatchCard extends StatelessWidget {
  const _UpcomingMatchCard(this.match);

  final LiveCricketMatch match;

  @override
  Widget build(BuildContext context) {
    final scheduled = match.scheduledAt;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: Text(match.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${match.seriesName}\n${scheduled == null ? 'Time TBA' : _formatDateTime(scheduled)}',
        ),
        isThreeLine: true,
        trailing: Text(_categoryLabel(match.category)),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.article);

  final CricketNewsArticle article;

  @override
  Widget build(BuildContext context) {
    final image = article.imageUrl;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: article.sourceUrl == null
            ? null
            : () async {
                final uri = Uri.tryParse(article.sourceUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              Image.network(
                image,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          article.sourceName,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Text(
                        _categoryLabel(article.category),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (article.summary != null &&
                      article.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (article.publishedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(article.publishedAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(post['body'] as String? ?? ''),
            if (post['type'] == 'poll')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Chip(label: Text('Poll')),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_cricket, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(CricketCategory category) {
  return switch (category) {
    CricketCategory.international => 'International',
    CricketCategory.india => 'India',
    CricketCategory.domestic => 'Domestic',
    CricketCategory.league => 'League',
    CricketCategory.other => 'Cricket',
  };
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
}
