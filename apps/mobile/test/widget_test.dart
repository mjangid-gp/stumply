import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crick_app/app.dart';
import 'package:crick_app/features/auth/data/auth_repository.dart';

void main() {
  testWidgets('App renders login screen when not authenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const CrickApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stumply'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
