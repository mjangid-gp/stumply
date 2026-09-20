import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
    client: http.Client(),
  );
});

class DiscoverRepository {
  DiscoverRepository({
    required this._firestore,
    required FirebaseFunctions functions,
    required http.Client client,
  }) : _functions = functions,
       _client = client;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final http.Client _client;

  static const _overpassEndpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? type,
  }) async {
    if (query.isEmpty) return [];
    try {
      final callable = _functions.httpsCallable('searchEntities');
      final result = await callable.call({
        'query': query.toLowerCase(),
        'type': type,
      });
      return List<Map<String, dynamic>>.from(result.data['results'] ?? []);
    } catch (_) {
      return _localSearch(query, type);
    }
  }

  Future<List<Map<String, dynamic>>> _localSearch(
    String query,
    String? type,
  ) async {
    final collections = type != null
        ? [type]
        : ['players', 'teams', 'tournaments', 'grounds'];
    final results = <Map<String, dynamic>>[];
    for (final col in collections) {
      final snap = await _firestore.collection(col).limit(20).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['displayName'] ?? '') as String;
        if (name.toLowerCase().contains(query.toLowerCase())) {
          results.add({'id': doc.id, 'type': col, ...data});
        }
      }
    }
    return results;
  }

  Future<void> follow(
    String followerId,
    String targetId,
    String targetType,
  ) async {
    await _firestore.collection('follows').add({
      'followerId': followerId,
      'targetId': targetId,
      'targetType': targetType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollow(String followerId, String targetId) async {
    final snap = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: followerId)
        .where('targetId', isEqualTo: targetId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<Map<String, dynamic>>> watchGrounds() {
    return _firestore
        .collection('grounds')
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> postLookingFor({
    required String authorId,
    required String title,
    required String description,
    required String city,
    String type = 'match',
  }) async {
    await _firestore.collection('lookingFor').add({
      'authorId': authorId,
      'title': title,
      'description': description,
      'city': city,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<NearbyGround>> findNearbyCricketGrounds({
    required double latitude,
    required double longitude,
    double radiusMeters = 10000,
  }) async {
    final radius = radiusMeters.clamp(1000, 25000).round();
    final query =
        '''
[out:json][timeout:20];
(
  nwr["sport"="cricket"](around:$radius,$latitude,$longitude);
  nwr["leisure"="pitch"]["sport"="cricket"](around:$radius,$latitude,$longitude);
  nwr["leisure"="stadium"]["sport"="cricket"](around:$radius,$latitude,$longitude);
  nwr["leisure"="sports_centre"]["sport"="cricket"](around:$radius,$latitude,$longitude);
);
out center tags;
''';

    Object? lastError;
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'Stumply/1.0 (cricket app)',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          throw Exception('Overpass returned ${response.statusCode}');
        }

        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('Invalid Overpass response');
        }

        final elements = payload['elements'];
        if (elements is! List) return const [];

        final results = <NearbyGround>[];
        final seen = <String>{};
        for (final raw in elements.whereType<Map<String, dynamic>>()) {
          final id = '${raw['type'] ?? 'osm'}:${raw['id'] ?? ''}';
          if (!seen.add(id)) continue;

          final tags = raw['tags'];
          final tagMap = tags is Map<String, dynamic>
              ? tags
              : <String, dynamic>{};
          final center = raw['center'];
          final centerMap = center is Map<String, dynamic> ? center : null;
          final lat = _asDouble(raw['lat'] ?? centerMap?['lat']);
          final lon = _asDouble(raw['lon'] ?? centerMap?['lon']);
          if (lat == null || lon == null) continue;

          final name = _firstNonEmpty([
            tagMap['name'],
            tagMap['official_name'],
            tagMap['short_name'],
          ]);
          if (name == null) continue;

          final distance = _distanceMeters(latitude, longitude, lat, lon);
          if (distance > radiusMeters) continue;

          results.add(
            NearbyGround(
              id: id,
              name: name,
              latitude: lat,
              longitude: lon,
              distanceMeters: distance,
              address: _firstNonEmpty([
                tagMap['addr:street'],
                tagMap['addr:suburb'],
                tagMap['addr:city'],
              ]),
              surface: tagMap['surface']?.toString(),
              sourceUrl:
                  'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon',
            ),
          );
        }

        results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return results.take(30).toList();
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('Nearby grounds unavailable: $lastError');
  }

  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PermissionDeniedException('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double value) => value * math.pi / 180;
}

class NearbyGround {
  const NearbyGround({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.address,
    this.surface,
    this.sourceUrl,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String? address;
  final String? surface;
  final String? sourceUrl;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
