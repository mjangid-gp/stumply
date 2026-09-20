import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
    required this._firestore,
    required FirebaseStorage storage,
  }) : _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<void> updateProfile(String uid, UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(profile.toMap(), SetOptions(merge: true));
    await _firestore.collection('players').doc(uid).set({
      'displayName': profile.displayName,
      'city': profile.city,
      'battingStyle': profile.battingStyle,
      'bowlingStyle': profile.bowlingStyle,
      'photoUrl': profile.photoUrl,
    }, SetOptions(merge: true));
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _firestore.collection('users').doc(uid).set({
      'photoUrl': photoUrl,
    }, SetOptions(merge: true));
    await _firestore.collection('players').doc(uid).set({
      'photoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  Future<String> saveGalleryPhoto(String uid, Uint8List bytes) async {
    var photoBytes = bytes;
    if (photoBytes.lengthInBytes > 220000) {
      throw Exception('Photo is too large. Choose a smaller image.');
    }

    if (!kIsWeb) {
      try {
        final ref = _storage.ref().child('users/$uid/avatar.jpg');
        await ref
            .putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'))
            .timeout(const Duration(seconds: 8));
        return await ref.getDownloadURL().timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint('Storage upload failed, saving photo in profile: $error');
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(photoBytes)}';
  }
}
