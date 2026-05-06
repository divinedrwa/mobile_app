# Firebase (Analytics + Cloud Messaging) on release builds

The app expects Firebase config files next to the Flutter project:

| Platform | File |
|----------|------|
| Android | `android/app/google-services.json` |
| iOS | `ios/Runner/GoogleService-Info.plist` |

## Production setup

1. In [Firebase Console](https://console.firebase.google.com), create or select your project.
2. Add an **Android** app with package name matching `applicationId` in `android/app/build.gradle.kts` (currently `com.app.society`). Download `google-services.json` into `android/app/`.
3. Add an **iOS** app with bundle ID matching Xcode (`Runner` target). Download `GoogleService-Info.plist` into `ios/Runner/`.
4. Enable **Google Analytics** and **Cloud Messaging** for the project if you use those features.

The Android Gradle plugin `com.google.gms.google-services` is already applied in `android/app/build.gradle.kts`, which merges Analytics + FCM metadata into the build.

For repeatable setups across machines, you can use [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/overview) (`flutterfire configure`) to regenerate options; still keep the JSON/plist files in place for native tooling.

**Security:** Treat downloaded JSON/plist as sensitive in public repositories. Use CI secrets or a private config bucket for production keys if you do not want them in git.
