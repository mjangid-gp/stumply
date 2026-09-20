import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(firestore: FirebaseFirestore.instance);
});

final liveCricketRepositoryProvider = Provider<LiveCricketRepository>((ref) {
  final repository = LiveCricketRepository(client: http.Client());
  ref.onDispose(repository.dispose);
  return repository;
});

class FeedRepository {
  FeedRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchFeed() {
    return _firestore
        .collection('feedPosts')
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}

enum CricketMatchStatus { live, upcoming, completed }

enum CricketCategory { international, india, domestic, league, other }

class LiveCricketMatch {
  const LiveCricketMatch({
    required this.id,
    required this.provider,
    required this.title,
    required this.seriesName,
    required this.status,
    required this.category,
    required this.scores,
    this.scheduledAt,
    this.venue,
    this.detail,
    this.sourceUrl,
  });

  final String id;
  final String provider;
  final String title;
  final String seriesName;
  final CricketMatchStatus status;
  final CricketCategory category;
  final List<CricketTeamScore> scores;
  final DateTime? scheduledAt;
  final String? venue;
  final String? detail;
  final String? sourceUrl;

  bool get isLive => status == CricketMatchStatus.live;
  bool get isUpcoming => status == CricketMatchStatus.upcoming;
}

class CricketTeamScore {
  const CricketTeamScore({
    required this.name,
    this.abbreviation,
    this.score,
    this.isWinner = false,
  });

  final String name;
  final String? abbreviation;
  final String? score;
  final bool isWinner;
}

class CricketNewsArticle {
  const CricketNewsArticle({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.publishedAt,
    this.summary,
    this.imageUrl,
    this.sourceUrl,
    this.category = CricketCategory.other,
  });

  final String id;
  final String title;
  final String sourceName;
  final DateTime? publishedAt;
  final String? summary;
  final String? imageUrl;
  final String? sourceUrl;
  final CricketCategory category;
}

class CricketFeedSnapshot {
  const CricketFeedSnapshot({
    required this.matches,
    required this.news,
    required this.updatedAt,
    this.errorMessage,
  });

  final List<LiveCricketMatch> matches;
  final List<CricketNewsArticle> news;
  final DateTime updatedAt;
  final String? errorMessage;

  List<LiveCricketMatch> get liveMatches =>
      matches.where((match) => match.isLive).toList();

  List<LiveCricketMatch> get upcomingMatches =>
      matches.where((match) => match.isUpcoming).toList();
}

/// Free, keyless cricket feed provider.
///
/// This uses public ESPN endpoints rather than a paid API key. ESPN's cricket
/// endpoints are public/undocumented and can change, so this class is isolated
/// behind a repository and can be replaced later without changing the UI.
class LiveCricketRepository {
  LiveCricketRepository({required http.Client client}) : _client = client;

  final http.Client _client;

  static const _headerUrl =
      'https://site.web.api.espn.com/apis/personalized/v2/scoreboard/header';
  static const _scoreboardBaseUrl =
      'https://site.api.espn.com/apis/site/v2/sports/cricket';
  static const _coreEventsBaseUrl =
      'https://sports.core.api.espn.com/v2/sports/cricket/leagues';

  static const _refreshInterval = Duration(seconds: 60);
  static const _newsRefreshInterval = Duration(minutes: 10);

  DateTime? _lastNewsFetch;
  List<CricketNewsArticle> _newsCache = const [];

  Stream<CricketFeedSnapshot> watchCricketFeed() async* {
    CricketFeedSnapshot? lastSnapshot;

    while (true) {
      final snapshot = await fetchCricketFeed();
      if (snapshot.matches.isNotEmpty ||
          snapshot.news.isNotEmpty ||
          lastSnapshot == null) {
        lastSnapshot = snapshot;
      }

      yield lastSnapshot ?? snapshot;
      await Future<void>.delayed(_refreshInterval);
    }
  }

  Future<CricketFeedSnapshot> fetchCricketFeed() async {
    try {
      final leagues = await _discoverActiveLeagues();
      final matches = await _fetchMatches(leagues);

      if (_lastNewsFetch == null ||
          DateTime.now().difference(_lastNewsFetch!) >= _newsRefreshInterval) {
        _newsCache = await _fetchNews(leagues);
        _lastNewsFetch = DateTime.now();
      }

      return CricketFeedSnapshot(
        matches: _sortMatches(matches),
        news: _newsCache,
        updatedAt: DateTime.now(),
      );
    } catch (error) {
      return CricketFeedSnapshot(
        matches: const [],
        news: _newsCache,
        updatedAt: DateTime.now(),
        errorMessage: 'Cricket feed temporarily unavailable.',
      );
    }
  }

  Future<List<_CricketLeague>> _discoverActiveLeagues() async {
    final uri = Uri.parse(_headerUrl).replace(
      queryParameters: const {
        'sport': 'cricket',
        'region': 'in',
        'lang': 'en',
        'tz': 'Asia/Calcutta',
      },
    );

    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('ESPN header returned ${response.statusCode}');
    }

    final payload = _decodeMap(response.body);
    final sports = payload['sports'];
    if (sports is! List) return const [];

    final leagues = <_CricketLeague>[];
    for (final sport in sports.whereType<Map<String, dynamic>>()) {
      final sportName = '${sport['name'] ?? ''} ${sport['slug'] ?? ''}'
          .toLowerCase();
      if (!sportName.contains('cricket')) continue;

      final rawLeagues = sport['leagues'];
      if (rawLeagues is! List) continue;

      for (final league in rawLeagues.whereType<Map<String, dynamic>>()) {
        final id = '${league['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;

        final events = league['events'];
        final eventCount = events is List ? events.length : 0;
        leagues.add(
          _CricketLeague(
            id: id,
            name: '${league['name'] ?? league['abbreviation'] ?? 'Cricket'}',
            eventCount: eventCount,
            headerEvents: events is List
                ? events.whereType<Map<String, dynamic>>().toList()
                : const [],
          ),
        );
      }
    }

    final seen = <String>{};
    return leagues.where((league) => seen.add(league.id)).take(12).toList();
  }

  Future<List<LiveCricketMatch>> _fetchMatches(
    List<_CricketLeague> leagues,
  ) async {
    if (leagues.isEmpty) return const [];

    final results = await Future.wait(
      leagues.map(_fetchLeagueMatches),
      eagerError: false,
    );

    final seen = <String>{};
    final matches = <LiveCricketMatch>[];
    for (final result in results) {
      for (final match in result) {
        if (seen.add(match.id)) matches.add(match);
      }
    }
    return matches;
  }

  Future<List<LiveCricketMatch>> _fetchLeagueMatches(
    _CricketLeague league,
  ) async {
    try {
      final uri = Uri.parse('$_scoreboardBaseUrl/${league.id}/scoreboard');
      final response = await _get(uri);
      if (response.statusCode != 200) {
        final headerMatches = _headerEventMatches(league);
        if (headerMatches.isNotEmpty) return headerMatches;
        return _fetchCoreLeagueEvents(league);
      }

      final payload = _decodeMap(response.body);
      final events = payload['events'];
      if (events is! List) {
        final headerMatches = _headerEventMatches(league);
        if (headerMatches.isNotEmpty) return headerMatches;
        return _fetchCoreLeagueEvents(league);
      }

      return events
          .whereType<Map<String, dynamic>>()
          .map((event) => _toMatch(event, league))
          .whereType<LiveCricketMatch>()
          .where(
            (match) =>
                match.status == CricketMatchStatus.live ||
                match.status == CricketMatchStatus.upcoming,
          )
          .toList();
    } catch (_) {
      final headerMatches = _headerEventMatches(league);
      if (headerMatches.isNotEmpty) return headerMatches;
      return _fetchCoreLeagueEvents(league);
    }
  }

  List<LiveCricketMatch> _headerEventMatches(_CricketLeague league) {
    return league.headerEvents
        .map((event) => _toMatch(event, league))
        .whereType<LiveCricketMatch>()
        .where(
          (match) =>
              match.status == CricketMatchStatus.live ||
              match.status == CricketMatchStatus.upcoming,
        )
        .toList();
  }

  Future<List<LiveCricketMatch>> _fetchCoreLeagueEvents(
    _CricketLeague league,
  ) async {
    try {
      final uri = Uri.parse(
        '$_coreEventsBaseUrl/${Uri.encodeComponent(league.id)}/events',
      );
      final response = await _get(uri);
      if (response.statusCode != 200) return const [];

      final payload = _decodeMap(response.body);
      final items = payload['items'];
      if (items is! List) return const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map((event) => _toCoreMatch(event, league))
          .whereType<LiveCricketMatch>()
          .where(
            (match) =>
                match.status == CricketMatchStatus.live ||
                match.status == CricketMatchStatus.upcoming,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  LiveCricketMatch? _toMatch(
    Map<String, dynamic> event,
    _CricketLeague league,
  ) {
    final competition = _firstMap(event['competitions']);
    final competitors = competition?['competitors'];
    if (competition == null || competitors is! List) return null;

    final status = _parseStatus(competition['status']);
    final scheduledAt = _parseDate(event['date']);
    final scores = competitors
        .whereType<Map<String, dynamic>>()
        .map(_toTeamScore)
        .toList();

    final category = _categorize(
      seriesName: league.name,
      teamNames: scores.map((score) => score.name).toList(),
    );

    final eventId = '${event['id'] ?? ''}';
    if (eventId.isEmpty) return null;

    return LiveCricketMatch(
      id: 'espn_$eventId',
      provider: 'espn',
      title: '${event['shortName'] ?? event['name'] ?? league.name}',
      seriesName: league.name,
      status: status,
      category: category,
      scores: scores,
      scheduledAt: scheduledAt,
      venue: _venueName(competition['venue']),
      detail: _statusDetail(competition['status']),
      sourceUrl: 'https://www.espncricinfo.com/',
    );
  }

  LiveCricketMatch? _toCoreMatch(
    Map<String, dynamic> event,
    _CricketLeague league,
  ) {
    final eventId = '${event['id'] ?? ''}';
    if (eventId.isEmpty) return null;

    final status = _parseStatus(event['status']);
    final competitors = event['competitors'];
    final scores = competitors is List
        ? competitors
              .whereType<Map<String, dynamic>>()
              .map(_toTeamScore)
              .toList()
        : <CricketTeamScore>[];

    final teamNames = scores.map((score) => score.name).toList();
    return LiveCricketMatch(
      id: 'espn_$eventId',
      provider: 'espn',
      title: '${event['name'] ?? league.name}',
      seriesName: league.name,
      status: status,
      category: _categorize(seriesName: league.name, teamNames: teamNames),
      scores: scores,
      scheduledAt: _parseDate(event['date']),
      detail: _statusDetail(event['status']),
      sourceUrl: 'https://www.espncricinfo.com/',
    );
  }

  CricketTeamScore _toTeamScore(Map<String, dynamic> competitor) {
    final team = _firstMap(competitor['team']);
    return CricketTeamScore(
      name: '${team?['displayName'] ?? team?['shortDisplayName'] ?? 'Team'}',
      abbreviation: team?['abbreviation'] as String?,
      score: competitor['score']?.toString(),
      isWinner: competitor['winner'] == true,
    );
  }

  Future<List<CricketNewsArticle>> _fetchNews(
    List<_CricketLeague> leagues,
  ) async {
    final selected = leagues.take(6).toList();
    if (selected.isEmpty) return const [];

    final results = await Future.wait(
      selected.map(_fetchLeagueNews),
      eagerError: false,
    );

    final byId = <String, CricketNewsArticle>{};
    for (final articles in results) {
      for (final article in articles) {
        byId[article.id] = article;
      }
    }

    final articles = byId.values.toList()
      ..sort((a, b) {
        final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return articles.take(20).toList();
  }

  Future<List<CricketNewsArticle>> _fetchLeagueNews(
    _CricketLeague league,
  ) async {
    try {
      final uri = Uri.parse('$_scoreboardBaseUrl/${league.id}/news');
      final response = await _get(uri);
      if (response.statusCode != 200) return const [];

      final payload = _decodeMap(response.body);
      final articles = payload['articles'];
      if (articles is! List) return const [];

      return articles
          .whereType<Map<String, dynamic>>()
          .map((article) => _toNewsArticle(article, league))
          .whereType<CricketNewsArticle>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  CricketNewsArticle? _toNewsArticle(
    Map<String, dynamic> article,
    _CricketLeague league,
  ) {
    final id = '${article['id'] ?? article['nowId'] ?? ''}'.trim();
    final title = '${article['headline'] ?? article['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;

    final links = _firstMap(article['links']);
    final web = _firstMap(links?['web']);
    final imageUrl = _extractImage(article);

    return CricketNewsArticle(
      id: 'espn_news_$id',
      title: title,
      sourceName: 'ESPNcricinfo',
      publishedAt: _parseDate(article['published']),
      summary: '${article['description'] ?? article['summary'] ?? ''}'.trim(),
      imageUrl: imageUrl,
      sourceUrl: web?['href'] as String?,
      category: _categorize(seriesName: league.name, teamNames: const []),
    );
  }

  Future<http.Response> _get(Uri uri) {
    return _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'Stumply/1.0',
          },
        )
        .timeout(const Duration(seconds: 10));
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected cricket API response');
    }
    return decoded;
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  String? _venueName(dynamic venue) {
    final map = _firstMap(venue);
    return map?['fullName'] as String? ?? map?['name'] as String?;
  }

  String? _statusDetail(dynamic status) {
    final map = _firstMap(status);
    final type = _firstMap(map?['type']);
    return type?['shortDetail'] as String? ?? type?['detail'] as String?;
  }

  CricketMatchStatus _parseStatus(dynamic raw) {
    final map = _firstMap(raw);
    final type = _firstMap(map?['type']);
    final state = '${type?['state'] ?? map?['state'] ?? ''}'.toLowerCase();
    if (state == 'in' || state == 'live') return CricketMatchStatus.live;
    if (state == 'post' || state == 'completed') {
      return CricketMatchStatus.completed;
    }
    return CricketMatchStatus.upcoming;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  CricketCategory _categorize({
    required String seriesName,
    required List<String> teamNames,
  }) {
    final text = '$seriesName ${teamNames.join(' ')}'.toLowerCase();

    const internationalKeywords = [
      'international',
      'test match',
      'odi',
      't20i',
      'world cup',
      'champions trophy',
      'asia cup',
      'icc ',
      'bilateral',
      'new zealand',
      'india ',
      'australia ',
      'england ',
      'south africa ',
      'pakistan ',
      'sri lanka ',
      'bangladesh ',
      'west indies',
      'afghanistan ',
      'ireland ',
      'zimbabwe ',
    ];

    if (internationalKeywords.any(text.contains)) {
      return CricketCategory.international;
    }

    const indiaKeywords = [
      'ipl',
      'ranji',
      'vijay hazare',
      'syed mushtaq',
      'duleep',
      'irani cup',
      'india domestic',
      'maharaja trophy',
      'sma trophy',
      'bcci',
    ];
    if (indiaKeywords.any(text.contains)) return CricketCategory.india;

    const leagueKeywords = [
      'league',
      't20 blast',
      'big bash',
      'bbl',
      'psl',
      'cpl',
      'hundred',
      'sa20',
      'mlc',
      'ilt20',
      'super smash',
    ];
    if (leagueKeywords.any(text.contains)) return CricketCategory.league;

    return CricketCategory.domestic;
  }

  List<LiveCricketMatch> _sortMatches(List<LiveCricketMatch> matches) {
    final result = [...matches];
    result.sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      final aDate = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
    return result;
  }

  void dispose() => _client.close();
}

class _CricketLeague {
  const _CricketLeague({
    required this.id,
    required this.name,
    required this.eventCount,
    required this.headerEvents,
  });

  final String id;
  final String name;
  final int eventCount;
  final List<Map<String, dynamic>> headerEvents;
}

String? _extractImage(Map<String, dynamic> article) {
  // Direct image URL fields
  final imageUrl = article['imageUrl'];
  if (imageUrl is String && imageUrl.trim().isNotEmpty) {
    return imageUrl.trim();
  }

  final image = article['image'];
  if (image is String && image.trim().isNotEmpty) {
    return image.trim();
  }

  final thumbnail = article['thumbnail'];
  if (thumbnail is String && thumbnail.trim().isNotEmpty) {
    return thumbnail.trim();
  }

  // ESPN images array
  final images = article['images'];

  if (images is List) {
    for (final item in images) {
      if (item is Map<String, dynamic>) {
        final url = item['url'];

        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }

        final href = item['href'];

        if (href is String && href.trim().isNotEmpty) {
          return href.trim();
        }

        final src = item['src'];

        if (src is String && src.trim().isNotEmpty) {
          return src.trim();
        }
      }
    }
  }

  // ESPN links.thumbnail
  final links = article['links'];

  if (links is Map<String, dynamic>) {
    final thumbnailLink = links['thumbnail'];

    if (thumbnailLink is Map<String, dynamic>) {
      final href = thumbnailLink['href'];

      if (href is String && href.trim().isNotEmpty) {
        return href.trim();
      }

      final url = thumbnailLink['url'];

      if (url is String && url.trim().isNotEmpty) {
        return url.trim();
      }
    }

    // ESPN links.image
    final imageLink = links['image'];

    if (imageLink is Map<String, dynamic>) {
      final href = imageLink['href'];

      if (href is String && href.trim().isNotEmpty) {
        return href.trim();
      }

      final url = imageLink['url'];

      if (url is String && url.trim().isNotEmpty) {
        return url.trim();
      }
    }
  }

  return null;
}
