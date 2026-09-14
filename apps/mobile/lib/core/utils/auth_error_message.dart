import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String friendlyAuthError(Object error) {
  final message = error.toString();
  if (message.contains('CONFIGURATION_NOT_FOUND')) {
    return 'Authentication is not set up yet. In Firebase Console open '
        'Authentication and click Get started, then enable Email/Password and Google.';
  }

  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'already-exists':
        return 'An account with this email already exists.';
      case 'invalid-argument':
        return error.message ?? 'Please check your details and try again.';
      case 'permission-denied':
        return 'Invalid OTP. Please try again.';
      case 'not-found':
        return 'Email OTP service is not available yet. Use "Create Account" instead.';
      case 'deadline-exceeded':
        return 'OTP expired. Please request a new code.';
      case 'resource-exhausted':
        return error.message ?? 'Too many attempts. Please try again later.';
      case 'unavailable':
        return 'Verification service is offline. Use "Create Account" instead.';
      default:
        return error.message ?? 'Request failed. Please try again.';
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'This sign-in method is disabled. Enable it in Firebase Console → Authentication → Sign-in method.';
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
        return 'Password does not meet security requirements.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  if (message.contains('Google sign-in cancelled')) {
    return 'Google sign-in was cancelled.';
  }
  if (message.contains('ApiException: 10') || message.contains('DEVELOPER_ERROR')) {
    return 'Google Sign-In is not configured. Add your SHA-1 fingerprint in Firebase Console.';
  }

  return 'Something went wrong. Please try again.';
}
