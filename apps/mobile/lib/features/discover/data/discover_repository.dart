import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

class DiscoverRepository {
  DiscoverRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<Map<String, dynamic>>> search(String query, {String? type}) async {
    if (query.isEmpty) return [];
    try {
      final callable = _functions.httpsCallable('searchEntities');
      final result = await callable.call({'query': query.toLowerCase(), 'type': type});
      return List<Map<String, dynamic>>.from(result.data['results'] ?? []);
    } catch (_) {
      return _localSearch(query, type);
    }
  }

  Future<List<Map<String, dynamic>>> _localSearch(String query, String? type) async {
    final collections = type != null ? [type] : ['players', 'teams', 'tournaments', 'grounds'];
    final results = <Map<String, dynamic>>[];
    for (final col in collections) {
      final snap = await _firestore.collection(col).limit(20).get();
      for (final doc in snap.docs) {
        final name = (doc.data()['name'] ?? doc.data()['displayName'] ?? '') as String;
        if (name.toLowerCase().contains(query.toLowerCase())) {
          results.add({'id': doc.id, 'type': col, ...doc.data()});
        }
      }
    }
    return results;
  }

  Future<void> follow(String followerId, String targetId, String targetType) async {
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
    return _firestore.collection('grounds').limit(50).snapshots().map(
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
}
