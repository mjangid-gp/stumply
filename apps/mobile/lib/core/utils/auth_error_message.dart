import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String friendlyAuthError(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'already-exists':
        return 'An account with this email already exists.';
      case 'invalid-argument':
        return error.message ?? 'Please check your details and try again.';
      case 'permission-denied':
        return 'Invalid OTP. Please try again.';
      case 'not-found':
      case 'deadline-exceeded':
        return 'OTP expired. Please request a new code.';
      case 'resource-exhausted':
        return error.message ?? 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Request failed. Please try again.';
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
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
  return 'Something went wrong. Please try again.';
}
