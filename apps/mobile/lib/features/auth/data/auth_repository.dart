import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(authRepositoryProvider).watchProfile(user.uid);
});

class AuthRepository {
  AuthRepository({
    required this._auth,
    required FirebaseFirestore firestore,
    required this._functions,
  }) : _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  GoogleSignIn? _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> sendRegistrationOtp({
    required String email,
    required String displayName,
  }) async {
    await _functions.httpsCallable('sendRegistrationOtp').call({
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
    });
  }

  Future<UserCredential> registerWithEmailOtp({
    required String email,
    required String password,
    required String displayName,
    required String otp,
  }) async {
    final result = await _functions.httpsCallable('registerWithEmailOtp').call({
      'email': email.trim().toLowerCase(),
      'password': password,
      'displayName': displayName.trim(),
      'otp': otp.trim(),
    });

    final token = (result.data as Map)['token'] as String;
    final credential = await _auth.signInWithCustomToken(token);
    await _ensureUserDoc(credential.user!, displayName: displayName);
    return credential;
  }

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user!);
    return result;
  }

  GoogleSignIn _createGoogleSignIn() {
    if (AppConstants.googleWebClientId.isNotEmpty) {
      return GoogleSignIn(serverClientId: AppConstants.googleWebClientId);
    }
    return GoogleSignIn();
  }

  Future<UserCredential> signInWithGoogle() async {
    _googleSignIn ??= _createGoogleSignIn();
    final googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user!);
    return result;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(result.user!);
    return result;
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    await result.user!.updateDisplayName(displayName.trim());
    try {
      await result.user!.sendEmailVerification();
    } catch (_) {
      // Verification email is optional when SMTP is not configured.
    }
    await _ensureUserDoc(result.user!, displayName: displayName.trim());
    return result;
  }

  Future<void> _ensureUserDoc(User user, {String? displayName}) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': displayName ?? user.displayName ?? 'Player',
        'email': user.email,
        'phone': user.phoneNumber,
        'photoUrl': user.photoURL,
        'role': 'player',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(snap.id, snap.data()!);
    });
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }
}
