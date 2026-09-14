import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

class ProfileRepository {
  ProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<void> updateProfile(String uid, UserProfile profile) async {
    await _firestore.collection('users').doc(uid).update(profile.toMap());
    await _firestore.collection('players').doc(uid).set({
      'displayName': profile.displayName,
      'city': profile.city,
      'battingStyle': profile.battingStyle,
      'bowlingStyle': profile.bowlingStyle,
    }, SetOptions(merge: true));
  }

  Future<String?> uploadPhoto(String uid, Uint8List bytes) async {
    final ref = _storage.ref().child('users/$uid/avatar.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Stream<Map<String, dynamic>> watchPlayerStats(String uid) {
    return _firestore.collection('players').doc(uid).snapshots().map((snap) {
      return snap.data() ?? {};
    });
  }

  Future<List<Map<String, dynamic>>> getMatchHistory(String uid) async {
    final snap = await _firestore
        .collection('matches')
        .where('teamAPlayers', arrayContains: uid)
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
