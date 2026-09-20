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
      matches.where((m) => m.isLive).toList();
  List<LiveCricketMatch> get upcomingMatches =>
      matches.where((m) => m.isUpcoming).toList();
}

/// Keyless ESPN-backed cricket feed.
///
/// Important: ESPN's cricket site scoreboard endpoint is not reliable for
/// cricket. We discover active series from the personalized header and use
/// its event data, with the ESPN Core events API as a fallback.
class LiveCricketRepository {
  LiveCricketRepository({required http.Client client}) : _client = client;

  final http.Client _client;

  static const _headerUrl =
      'https://site.api.espn.com/apis/personalized/v2/scoreboard/header';
  static const _coreEventsBaseUrl =
      'https://sports.core.api.espn.com/v2/sports/cricket/leagues';

  static const _refreshInterval = Duration(seconds: 60);
  static const _newsRefreshInterval = Duration(minutes: 10);

  DateTime? _lastNewsFetch;
  List<CricketNewsArticle> _newsCache = const [];
  CricketFeedSnapshot? _lastSnapshot;

  Stream<CricketFeedSnapshot> watchCricketFeed() async* {
    while (true) {
      final snapshot = await fetchCricketFeed();
      if (snapshot.matches.isNotEmpty ||
          snapshot.news.isNotEmpty ||
          _lastSnapshot == null) {
        _lastSnapshot = snapshot;
      }
      yield _lastSnapshot ?? snapshot;
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
        matches: _lastSnapshot?.matches ?? const [],
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
    for (final sport in sports.whereType<Map>()) {
      final sportMap = Map<String, dynamic>.from(sport);
      final sportName = '${sportMap['name'] ?? ''} ${sportMap['slug'] ?? ''}'
          .toLowerCase();
      if (!sportName.contains('cricket')) continue;

      final rawLeagues = sportMap['leagues'];
      if (rawLeagues is! List) continue;

      for (final rawLeague in rawLeagues.whereType<Map>()) {
        final league = Map<String, dynamic>.from(rawLeague);
        final id = '${league['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;

        final rawEvents = league['events'];
        final events = rawEvents is List
            ? rawEvents
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const <Map<String, dynamic>>[];

        leagues.add(
          _CricketLeague(
            id: id,
            name: '${league['name'] ?? league['shortName'] ?? 'Cricket'}',
            eventCount: events.length,
            headerEvents: events,
          ),
        );
      }
    }

    final seen = <String>{};
    final unique = leagues.where((l) => seen.add(l.id)).toList();

    // Keep all active series, but process India-related series first.
    unique.sort((a, b) {
      final ai = _isIndiaText(a.name) ? 0 : 1;
      final bi = _isIndiaText(b.name) ? 0 : 1;
      if (ai != bi) return ai.compareTo(bi);
      return b.eventCount.compareTo(a.eventCount);
    });
    return unique;
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
    final fromHeader = league.headerEvents
        .map((event) => _toMatch(event, league))
        .whereType<LiveCricketMatch>()
        .where((m) => m.isLive || m.isUpcoming)
        .toList();

    if (fromHeader.isNotEmpty) return fromHeader;
    return _fetchCoreLeagueEvents(league);
  }

  Future<List<LiveCricketMatch>> _fetchCoreLeagueEvents(
    _CricketLeague league,
  ) async {
    try {
      final uri = Uri.parse(
        '$_coreEventsBaseUrl/${Uri.encodeComponent(league.id)}/events',
      ).replace(queryParameters: const {'limit': '100'});
      final response = await _get(uri);
      if (response.statusCode != 200) return const [];

      final payload = _decodeMap(response.body);
      final items = payload['items'];
      if (items is! List) return const [];

      final resolved = await Future.wait(
        items.whereType<Map>().take(60).map((item) async {
          final event = Map<String, dynamic>.from(item);
          final direct = _toMatch(event, league);
          if (direct != null) return direct;

          final eventRef = event[r'$ref'];
          if (eventRef is String && eventRef.isNotEmpty) {
            try {
              final eventResponse = await _get(Uri.parse(eventRef));
              if (eventResponse.statusCode == 200) {
                return _toMatch(_decodeMap(eventResponse.body), league);
              }
            } catch (_) {}
          }
          return null;
        }),
        eagerError: false,
      );

      return resolved
          .whereType<LiveCricketMatch>()
          .where((m) => m.isLive || m.isUpcoming)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  LiveCricketMatch? _toMatch(
    Map<String, dynamic> event,
    _CricketLeague league,
  ) {
    final eventId = '${event['id'] ?? ''}'.trim();
    if (eventId.isEmpty) return null;

    final competition = _firstMap(event['competitions']) ?? event;
    final rawCompetitors = competition['competitors'] ?? event['competitors'];
    final competitors = rawCompetitors is List
        ? rawCompetitors
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    final statusRaw = event['status'] ?? competition['status'];
    final status = _parseStatus(statusRaw);
    final scores = competitors.map(_toTeamScore).toList();

    // Some header payloads put teams directly on the event.
    if (scores.isEmpty) {
      final teams = event['teams'];
      if (teams is List) {
        for (final rawTeam in teams.whereType<Map>()) {
          final team = Map<String, dynamic>.from(rawTeam);
          final name = '${team['displayName'] ?? team['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          scores.add(
            CricketTeamScore(
              name: name,
              abbreviation: team['abbreviation'] as String?,
              score: team['score']?.toString(),
              isWinner: team['winner'] == true,
            ),
          );
        }
      }
    }

    final teamNames = scores.map((s) => s.name).toList();
    return LiveCricketMatch(
      id: 'espn_$eventId',
      provider: 'espn',
      title:
          '${event['shortName'] ?? event['name'] ?? (teamNames.isEmpty ? league.name : teamNames.join(' vs '))}',
      seriesName: league.name,
      status: status,
      category: _categorize(seriesName: league.name, teamNames: teamNames),
      scores: scores,
      scheduledAt: _parseDate(event['date'] ?? competition['date']),
      venue: _venueName(competition['venue'] ?? event['venue']),
      detail: _statusDetail(statusRaw),
      sourceUrl: 'https://www.espncricinfo.com/',
    );
  }

  CricketTeamScore _toTeamScore(Map<String, dynamic> competitor) {
    final team = _firstMap(competitor['team']) ?? competitor;
    return CricketTeamScore(
      name:
          '${team['displayName'] ?? team['shortDisplayName'] ?? team['name'] ?? 'Team'}',
      abbreviation: team['abbreviation'] as String?,
      score: competitor['score']?.toString() ?? team['score']?.toString(),
      isWinner: competitor['winner'] == true,
    );
  }

  Future<List<CricketNewsArticle>> _fetchNews(
    List<_CricketLeague> leagues,
  ) async {
    if (leagues.isEmpty) return const [];
    final selected = leagues.take(10).toList();
    final results = await Future.wait(
      selected.map(_fetchLeagueNews),
      eagerError: false,
    );
    final byId = <String, CricketNewsArticle>{};
    for (final articles in results) {
      for (final article in articles) byId[article.id] = article;
    }
    final articles = byId.values.toList()
      ..sort(
        (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
          a.publishedAt ?? DateTime(1970),
        ),
      );
    return articles.take(30).toList();
  }

  Future<List<CricketNewsArticle>> _fetchLeagueNews(
    _CricketLeague league,
  ) async {
    try {
      final uri = Uri.parse(
        'https://site.api.espn.com/apis/site/v2/sports/cricket/${Uri.encodeComponent(league.id)}/news',
      );
      final response = await _get(uri);
      if (response.statusCode != 200) return const [];
      final payload = _decodeMap(response.body);
      final articles = payload['articles'];
      if (articles is! List) return const [];
      return articles
          .whereType<Map>()
          .map((a) => _toNewsArticle(Map<String, dynamic>.from(a), league))
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
    return CricketNewsArticle(
      id: 'espn_news_$id',
      title: title,
      sourceName: 'ESPNcricinfo',
      publishedAt: _parseDate(article['published']),
      summary: '${article['description'] ?? article['summary'] ?? ''}'.trim(),
      imageUrl: _extractImage(article),
      sourceUrl: web?['href'] as String?,
      category: _categorize(seriesName: league.name, teamNames: const []),
    );
  }

  CricketCategory _categorize({
    required String seriesName,
    required List<String> teamNames,
  }) {
    final text = '$seriesName ${teamNames.join(' ')}'.toLowerCase();
    final india =
        _isIndiaText(text) ||
        [
          'ranji',
          'vijay hazare',
          'syed mushtaq',
          'duleep',
          'irani cup',
          'bcci',
          'ipl',
        ].any(text.contains);
    if (india) return CricketCategory.india;

    final international = [
      'international',
      'test match',
      'odi',
      't20i',
      'world cup',
      'champions trophy',
      'asia cup',
      'icc ',
      'bilateral',
      'australia',
      'england',
      'south africa',
      'pakistan',
      'sri lanka',
      'bangladesh',
      'west indies',
      'afghanistan',
      'ireland',
      'new zealand',
      'zimbabwe',
    ].any(text.contains);
    if (international) return CricketCategory.international;

    final league = [
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
    ].any(text.contains);
    if (league) return CricketCategory.league;
    return CricketCategory.domestic;
  }

  static bool _isIndiaText(String text) {
    final value = text.toLowerCase();
    return value.contains('india') ||
        value.contains('india a') ||
        value.contains('india women') ||
        value.contains('india u19') ||
        value.contains('indian');
  }

  List<LiveCricketMatch> _sortMatches(List<LiveCricketMatch> matches) {
    final result = [...matches];
    result.sort((a, b) {
      final aLive = a.isLive ? 0 : 1;
      final bLive = b.isLive ? 0 : 1;
      if (aLive != bLive) return aLive.compareTo(bLive);
      final aIndia = a.category == CricketCategory.india ? 0 : 1;
      final bIndia = b.category == CricketCategory.india ? 0 : 1;
      if (aIndia != bIndia) return aIndia.compareTo(bIndia);
      final aDate = a.scheduledAt ?? DateTime(2099);
      final bDate = b.scheduledAt ?? DateTime(2099);
      return aDate.compareTo(bDate);
    });
    return result;
  }

  CricketMatchStatus _parseStatus(dynamic raw) {
    final map = _firstMap(raw);
    final type = _firstMap(map?['type']);
    final state = '${type?['state'] ?? map?['state'] ?? raw ?? ''}'
        .toLowerCase();
    if (state == 'in' ||
        state == 'live' ||
        state == 'inprogress' ||
        state == 'in_progress')
      return CricketMatchStatus.live;
    if (state == 'post' ||
        state == 'completed' ||
        state == 'complete' ||
        state == 'final')
      return CricketMatchStatus.completed;
    return CricketMatchStatus.upcoming;
  }

  String? _statusDetail(dynamic raw) {
    final map = _firstMap(raw);
    final type = _firstMap(map?['type']);
    return type?['shortDetail'] as String? ??
        type?['detail'] as String? ??
        type?['name'] as String?;
  }

  String? _venueName(dynamic raw) {
    final map = _firstMap(raw);
    return map?['fullName'] as String? ?? map?['name'] as String?;
  }

  DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  Future<http.Response> _get(Uri uri) => _client
      .get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Stumply/1.0',
        },
      )
      .timeout(const Duration(seconds: 10));

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map)
      throw const FormatException('Unexpected cricket API response');
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
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
  for (final key in ['imageUrl', 'image', 'thumbnail']) {
    final value = article[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final images = article['images'];
  if (images is List) {
    for (final item in images.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      for (final key in ['url', 'href', 'src']) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
  }
  final links = article['links'];
  if (links is Map) {
    final linkMap = Map<String, dynamic>.from(links);
    for (final key in ['thumbnail', 'image']) {
      final item = linkMap[key];
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        for (final field in ['href', 'url']) {
          final value = map[field];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
    }
  }
  return null;
}
