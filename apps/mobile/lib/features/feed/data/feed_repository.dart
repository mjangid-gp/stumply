import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(firestore: FirebaseFirestore.instance);
});

class FeedRepository {
  FeedRepository({required FirebaseFirestore firestore}) : _firestore = firestore;
  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchFeed() {
    return _firestore
        .collection('feedPosts')
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
