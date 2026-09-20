import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(firestore: FirebaseFirestore.instance);
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

final liveCricketRepositoryProvider = Provider<LiveCricketRepository>((ref) {
  return LiveCricketRepository(client: http.Client());
});

class LiveCricketMatch {
  const LiveCricketMatch({
    required this.id,
    required this.title,
    required this.status,
    required this.scores,
    this.venue,
  });

  final String id;
  final String title;
  final String status;
  final List<String> scores;
  final String? venue;
}

class LiveCricketRepository {
  LiveCricketRepository({required this._client});

  static const _leagueIds = ['8048', '8047', '8046', '8049', '8039'];
  static const _baseUrl =
      'https://site.api.espn.com/apis/site/v2/sports/cricket';
  final http.Client _client;

  Stream<List<LiveCricketMatch>> watchLiveMatches() async* {
    while (true) {
      yield await fetchLiveMatches();
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<List<LiveCricketMatch>> fetchLiveMatches() async {
    final results = await Future.wait(
      _leagueIds.map(_fetchLeague),
      eagerError: false,
    );
    final matches = results.expand((items) => items).toList();
    final seen = <String>{};
    return matches.where((match) => seen.add(match.id)).toList();
  }

  Future<List<LiveCricketMatch>> _fetchLeague(String leagueId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/$leagueId/scoreboard'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final events = payload['events'];
      if (events is! List) return const [];
      return events
          .whereType<Map<String, dynamic>>()
          .where(_isLive)
          .map(_toMatch)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _isLive(Map<String, dynamic> event) {
    final competitions = event['competitions'];
    if (competitions is! List || competitions.isEmpty) return false;
    final competition = competitions.first;
    if (competition is! Map<String, dynamic>) return false;
    final status = competition['status'];
    final type = status is Map<String, dynamic> ? status['type'] : null;
    return type is Map<String, dynamic> && type['state'] == 'in';
  }

  LiveCricketMatch _toMatch(Map<String, dynamic> event) {
    final competition =
        (event['competitions'] as List).first as Map<String, dynamic>;
    final competitors = (competition['competitors'] as List?) ?? const [];
    final scores = competitors.whereType<Map<String, dynamic>>().map((
      competitor,
    ) {
      final team = competitor['team'] as Map<String, dynamic>?;
      final name = team?['shortDisplayName'] ?? team?['displayName'] ?? 'Team';
      return '$name ${competitor['score'] ?? '-'}';
    }).toList();
    final venue =
        (competition['venue'] as Map<String, dynamic>?)?['fullName'] as String?;
    final status = competition['status'] as Map<String, dynamic>?;
    final statusType = status?['type'] as Map<String, dynamic>?;
    return LiveCricketMatch(
      id: '${event['id']}',
      title:
          event['shortName'] as String? ??
          event['name'] as String? ??
          'Cricket match',
      status: statusType?['shortDetail'] as String? ?? 'Live',
      scores: scores,
      venue: venue,
    );
  }
}
