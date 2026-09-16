import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class YoutubeStream {
  const YoutubeStream({
    required this.id,
    required this.videoId,
    required this.url,
    required this.title,
    required this.createdBy,
    this.createdByName = '',
  });

  final String id;
  final String videoId;
  final String url;
  final String title;
  final String createdBy;
  final String createdByName;

  factory YoutubeStream.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return YoutubeStream(
      id: doc.id,
      videoId: data['videoId'] as String? ?? '',
      url: data['url'] as String? ?? '',
      title: data['title'] as String? ?? 'YouTube live',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
    );
  }
}

final youtubeStreamRepositoryProvider = Provider<YoutubeStreamRepository>((ref) {
  return YoutubeStreamRepository(FirebaseFirestore.instance);
});

class YoutubeStreamRepository {
  YoutubeStreamRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<List<YoutubeStream>> watchLiveStreams() {
    return _firestore
        .collection('youtubeStreams')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(YoutubeStream.fromDoc).toList());
  }

  Future<void> publish({
    required String videoId,
    required String url,
    required String title,
    required String userId,
    required String userName,
  }) async {
    await _firestore.collection('youtubeStreams').add({
      'videoId': videoId,
      'url': url,
      'title': title,
      'createdBy': userId,
      'createdByName': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
