// Generated to match `android/app/google-services.json` and
// `ios/Runner/GoogleService-Info.plist` (project: society-e1a2e).
// Re-run `flutterfire configure` if you change Firebase apps.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web in this app.');
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFDpDrnX9WqtkQpDNvVk0O7cb-NTDRVW8',
    appId: '1:508579954527:android:b8329479772c10a14300ea',
    messagingSenderId: '508579954527',
    projectId: 'society-e1a2e',
    storageBucket: 'society-e1a2e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBfC4irUOsKni6Kg5hvUvaM70DOTT81ifE',
    appId: '1:508579954527:ios:70437d1a7ba673184300ea',
    messagingSenderId: '508579954527',
    projectId: 'society-e1a2e',
    storageBucket: 'society-e1a2e.firebasestorage.app',
    iosBundleId: 'com.app.society',
  );
}
