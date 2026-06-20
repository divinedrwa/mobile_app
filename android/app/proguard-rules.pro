# Proguard / R8 rules for divine_app release builds. Default Flutter +
# Firebase + plugin keeps live in the AGP `proguard-android-optimize.txt`
# file we layer on top of; this file only needs to cover what isn't already
# safe by default.

# --- Flutter -----------------------------------------------------------------
# The Flutter engine resolves Dart→JNI symbols by name; reflection breaks if
# they're renamed.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase / Google Play services ----------------------------------------
# Firebase reflectively reads model classes; AGP keeps annotated fields by
# default, but explicit -keepclasseswithmembernames covers @Keep variants
# Firebase ships in transitive deps.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Google Play Core (in_app_update / app-update) --------------------------
# Play Core is NOT under gms.* — R8 strips it without explicit keeps, which
# crashes release builds the first time checkForUpdate() runs after install.
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# --- in_app_update plugin ---------------------------------------------------
-keep class de.ffuf.in_app_update.** { *; }

# --- Kotlin / Coroutines metadata -------------------------------------------
-keep class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# --- AndroidX core --------------------------------------------------------
-keep class androidx.core.app.CoreComponentFactory { *; }

# --- App-specific (com.app.gatepass) ----------------------------------------
# Plugins that use reflection on plugin-channel handler classes are usually
# annotated @Keep upstream; if we add Java/Kotlin native code with reflective
# entry points later, register their packages here so R8 doesn't strip them.
