import 'package:firebase_auth/firebase_auth.dart';

String friendlyAuthError(Object error) {
  final message = error.toString();

  if (message.contains('CONFIGURATION_NOT_FOUND')) {
    return 'Authentication is not set up yet. In Firebase Console open '
        'Authentication → Sign-in method and enable Email/Password.';
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled. Enable it in Firebase Console → Authentication → Sign-in method.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password does not meet the required security rules.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'no-current-user':
        return error.message ?? 'Please sign in again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  if (message.contains('Google sign-in cancelled')) {
    return 'Google sign-in was cancelled.';
  }

  if (message.contains('ApiException: 10') ||
      message.contains('DEVELOPER_ERROR')) {
    return 'Google Sign-In is not configured. Add your SHA-1 fingerprint in Firebase Console.';
  }

  return 'Something went wrong. Please try again.';
}
