import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Run `flutterfire configure` to replace with your project credentials.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:00000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'crick-app-dev',
    authDomain: 'crick-app-dev.firebaseapp.com',
    storageBucket: 'crick-app-dev.appspot.com',
    databaseURL: 'https://crick-app-dev-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:00000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'crick-app-dev',
    storageBucket: 'crick-app-dev.appspot.com',
    databaseURL: 'https://crick-app-dev-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:00000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'crick-app-dev',
    storageBucket: 'crick-app-dev.appspot.com',
    databaseURL: 'https://crick-app-dev-default-rtdb.firebaseio.com',
    iosBundleId: 'com.crick.app',
  );
}
