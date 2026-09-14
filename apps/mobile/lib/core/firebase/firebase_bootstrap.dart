import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

class FirebaseBootstrap {
  static bool initialized = false;
  static bool useEmulators = false;

  static Future<void> initialize() async {
    if (initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kDebugMode) {
        await _connectEmulators();
      } else if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      initialized = true;
    } catch (e) {
      debugPrint('Firebase init skipped (configure with flutterfire): $e');
    }
  }

  static Future<void> _connectEmulators() async {
    final host = kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux
        ? 'localhost'
        : '10.0.2.2';
    try {
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instanceFor(region: 'asia-south1')
          .useFunctionsEmulator(host, 5001);
      useEmulators = true;
      debugPrint('Connected to Firebase emulators at $host');
    } catch (e) {
      debugPrint('Emulator connection skipped: $e');
    }
  }
}
