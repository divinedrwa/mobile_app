import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing config is loaded from android/key.properties (gitignored).
// Local devs without the file get debug-signed release builds (so
// `flutter run --release` still works); CI / Play Store uploads must
// populate key.properties from secret storage before building.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.app.gatepass"
    compileSdk = flutter.compileSdkVersion
    // Pin to NDK r28+ explicitly so 16 KB memory-page support is always on.
    // Google Play (May 31, 2026) requires apps targeting Android 15+ to ship
    // 16 KB-aligned native libraries; NDK r28 produces 16 KB-aligned `.so`
    // files by default. Reading `flutter.ndkVersion` is safe today (3.41 ships
    // r28.2) but pinning here protects against a downgrade if a future Flutter
    // SDK or a plugin overrides the project NDK.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Pack `.so` files uncompressed and page-aligned inside the APK/AAB. AGP
    // 8.x already defaults to uncompressed jniLibs, but making it explicit
    // means the build will fail loudly if a plugin or future AGP toggles
    // legacy packaging back on (legacy packaging compresses the libs and
    // breaks 16 KB load alignment at install time).
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    defaultConfig {
        applicationId = "com.app.gatepass"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config when key.properties is present;
            // fall back to debug otherwise so `flutter run --release` still
            // works for local devs without the keystore on disk.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 shrinking + obfuscation. Keep rules in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
}
