import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/crick_ui.dart';
import '../data/feed_repository.dart';

enum _FeedFilter { all, live, upcoming, news }

enum _CategoryFilter { all, india, international, domestic, league }

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
    )..load();
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
          _filters(),
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
                if (data == null)
                  return const _EmptyFeed(message: 'Loading cricket feed...');

                final matches = _filterMatches(data.matches);
                final news = _filterNews(data.news);
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ref.watch(feedRepositoryProvider).watchFeed(),
                  builder: (context, postSnapshot) {
                    final posts = _filter == _FeedFilter.news
                        ? const <Map<String, dynamic>>[]
                        : (postSnapshot.data ?? const []);
                    final children = <Widget>[];

                    if (_filter != _FeedFilter.news) {
                      final live = matches.where((m) => m.isLive).toList();
                      final indiaLive = live
                          .where((m) => m.category == CricketCategory.india)
                          .toList();
                      final indiaUpcoming = matches
                          .where(
                            (m) =>
                                m.isUpcoming &&
                                m.category == CricketCategory.india,
                          )
                          .toList();
                      final international = matches
                          .where(
                            (m) => m.category == CricketCategory.international,
                          )
                          .toList();
                      final domestic = matches
                          .where((m) => m.category == CricketCategory.domestic)
                          .toList();
                      final leagues = matches
                          .where((m) => m.category == CricketCategory.league)
                          .toList();

                      if (_category == _CategoryFilter.all ||
                          _category == _CategoryFilter.india) {
                        if (indiaLive.isNotEmpty) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.circle,
                              iconColor: Colors.red,
                              title: 'INDIA · LIVE NOW',
                              trailing: '60 sec refresh',
                            ),
                          );
                          children.addAll(indiaLive.map(_LiveMatchCard.new));
                        }
                        if (indiaUpcoming.isNotEmpty &&
                            (_filter == _FeedFilter.all ||
                                _filter == _FeedFilter.upcoming)) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.flag,
                              title: 'INDIA · UPCOMING',
                            ),
                          );
                          children.addAll(
                            indiaUpcoming.map(_UpcomingMatchCard.new),
                          );
                        }
                      }

                      if (_filter != _FeedFilter.live) {
                        if ((_category == _CategoryFilter.all ||
                                _category == _CategoryFilter.international) &&
                            international.isNotEmpty) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.public,
                              title: 'INTERNATIONAL',
                            ),
                          );
                          children.addAll(
                            international.map(_matchCardForStatus),
                          );
                        }
                        if ((_category == _CategoryFilter.all ||
                                _category == _CategoryFilter.domestic) &&
                            domestic.isNotEmpty) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.location_city,
                              title: 'DOMESTIC CRICKET',
                            ),
                          );
                          children.addAll(domestic.map(_matchCardForStatus));
                        }
                        if ((_category == _CategoryFilter.all ||
                                _category == _CategoryFilter.league) &&
                            leagues.isNotEmpty) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.emoji_events,
                              title: 'T20 & OTHER LEAGUES',
                            ),
                          );
                          children.addAll(leagues.map(_matchCardForStatus));
                        }
                      }

                      if (_filter == _FeedFilter.live &&
                          live.isNotEmpty &&
                          _category == _CategoryFilter.all) {
                        final otherLive = live
                            .where((m) => m.category != CricketCategory.india)
                            .toList();
                        if (otherLive.isNotEmpty) {
                          children.add(
                            const _SectionHeader(
                              icon: Icons.circle,
                              iconColor: Colors.red,
                              title: 'OTHER LIVE MATCHES',
                            ),
                          );
                          children.addAll(otherLive.map(_LiveMatchCard.new));
                        }
                      }
                    }

                    if (_filter == _FeedFilter.all ||
                        _filter == _FeedFilter.news) {
                      if (news.isNotEmpty) {
                        children.add(
                          const _SectionHeader(
                            icon: Icons.article_outlined,
                            title: 'CRICKET NEWS',
                          ),
                        );
                        children.addAll(news.map(_NewsCard.new));
                      }
                      if (_filter == _FeedFilter.all && posts.isNotEmpty) {
                        children.add(
                          const _SectionHeader(
                            icon: Icons.groups_outlined,
                            title: 'STUMPLY COMMUNITY',
                          ),
                        );
                        children.addAll(
                          posts.map((p) => _CommunityPostCard(post: p)),
                        );
                      }
                    }

                    if (children.isEmpty) {
                      return _EmptyFeed(
                        message:
                            data.errorMessage ??
                            'No cricket matches or news found right now. Pull to refresh.',
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
                        children: children,
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

  Widget _filters() => Material(
    elevation: 1,
    child: Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            children: [
              _CategoryChip(
                label: 'All',
                selected: _category == _CategoryFilter.all,
                onSelected: () =>
                    setState(() => _category = _CategoryFilter.all),
              ),
              _CategoryChip(
                label: '🇮🇳 India',
                selected: _category == _CategoryFilter.india,
                onSelected: () =>
                    setState(() => _category = _CategoryFilter.india),
              ),
              _CategoryChip(
                label: 'International',
                selected: _category == _CategoryFilter.international,
                onSelected: () =>
                    setState(() => _category = _CategoryFilter.international),
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

  List<LiveCricketMatch> _filterMatches(List<LiveCricketMatch> matches) =>
      matches.where((m) {
        final status = switch (_filter) {
          _FeedFilter.all => true,
          _FeedFilter.live => m.isLive,
          _FeedFilter.upcoming => m.isUpcoming,
          _FeedFilter.news => false,
        };
        return status && _categoryMatches(m.category);
      }).toList();

  List<CricketNewsArticle> _filterNews(List<CricketNewsArticle> news) =>
      (_filter == _FeedFilter.live || _filter == _FeedFilter.upcoming)
      ? const []
      : news.where((n) => _categoryMatches(n.category)).toList();

  bool _categoryMatches(CricketCategory c) => switch (_category) {
    _CategoryFilter.all => true,
    _CategoryFilter.india => c == CricketCategory.india,
    _CategoryFilter.international => c == CricketCategory.international,
    _CategoryFilter.domestic => c == CricketCategory.domestic,
    _CategoryFilter.league => c == CricketCategory.league,
  };

  Widget _matchCardForStatus(LiveCricketMatch m) =>
      m.isLive ? _LiveMatchCard(m) : _UpcomingMatchCard(m);
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
  Widget build(BuildContext context) => Padding(
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

class _LiveMatchCard extends StatelessWidget {
  const _LiveMatchCard(this.match);
  final LiveCricketMatch match;
  @override
  Widget build(BuildContext context) => Card(
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
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(s.name)),
                  Text(
                    s.score ?? '-',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (match.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                match.detail!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (match.venue != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                match.venue!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
  );
}

class _UpcomingMatchCard extends StatelessWidget {
  const _UpcomingMatchCard(this.match);
  final LiveCricketMatch match;
  @override
  Widget build(BuildContext context) {
    final scheduledAt = match.scheduledAt;
    final scheduleText = scheduledAt == null
        ? 'Time TBA'
        : _formatDateTime(scheduledAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: Text(match.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${match.seriesName}\n$scheduleText'),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: article.sourceUrl == null
            ? null
            : () async {
                final u = Uri.tryParse(article.sourceUrl!);
                if (u != null && await canLaunchUrl(u))
                  await launchUrl(u, mode: LaunchMode.externalApplication);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl?.isNotEmpty == true)
              Image.network(
                article.imageUrl!,
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
                  if (article.summary?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        article.summary!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (article.publishedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _formatDateTime(article.publishedAt!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
  Widget build(BuildContext context) => Card(
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
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

String _categoryLabel(CricketCategory c) => switch (c) {
  CricketCategory.international => 'International',
  CricketCategory.india => 'India',
  CricketCategory.domestic => 'Domestic',
  CricketCategory.league => 'League',
  CricketCategory.other => 'Cricket',
};
String _formatDateTime(DateTime d) {
  final x = d.toLocal();
  final h = x.hour == 0
      ? 12
      : x.hour > 12
      ? x.hour - 12
      : x.hour;
  final m = x.minute.toString().padLeft(2, '0');
  return '${x.day}/${x.month}/${x.year} $h:$m ${x.hour >= 12 ? 'PM' : 'AM'}';
}
