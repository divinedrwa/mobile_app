// Generated to match `android/app/google-services.json` and
// `ios/Runner/GoogleService-Info.plist` (project: society-e1a2e).
// Re-run `flutterfire configure` if you change Firebase apps.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: unsupported platform',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBOKLqam_2qy-BQDLQLWrUwN6N7_YfWHr0',
    appId: '1:508579954527:web:143fed6487138a884300ea',
    messagingSenderId: '508579954527',
    projectId: 'society-e1a2e',
    authDomain: 'society-e1a2e.firebaseapp.com',
    storageBucket: 'society-e1a2e.firebasestorage.app',
    measurementId: 'G-FL8MHBKD41',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFDpDrnX9WqtkQpDNvVk0O7cb-NTDRVW8',
    appId: '1:508579954527:android:f0ecfb8ba79778064300ea',
    messagingSenderId: '508579954527',
    projectId: 'society-e1a2e',
    storageBucket: 'society-e1a2e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBfC4irUOsKni6Kg5hvUvaM70DOTT81ifE',
    appId: '1:508579954527:ios:adfa4b032a75bd4a4300ea',
    messagingSenderId: '508579954527',
    projectId: 'society-e1a2e',
    storageBucket: 'society-e1a2e.firebasestorage.app',
    iosBundleId: 'com.app.gatepass',
  );
}
