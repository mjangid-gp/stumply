import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crick_app/core/utils/auth_error_message.dart';

void main() {
  test('returns friendly message for weak password', () {
    final error = FirebaseAuthException(code: 'weak-password');
    expect(friendlyAuthError(error), 'Password must be at least 6 characters.');
  });

  test('returns friendly message for invalid credential', () {
    final error = FirebaseAuthException(code: 'invalid-credential');
    expect(friendlyAuthError(error), 'Incorrect email or password.');
  });

  test('returns generic message for unknown errors', () {
    expect(friendlyAuthError(Exception('fail')), 'Something went wrong. Please try again.');
  });
}
