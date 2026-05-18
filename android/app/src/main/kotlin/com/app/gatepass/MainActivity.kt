package com.app.gatepass

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // -- Platform channel: expose physical screen info to Dart ----------------

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.app.gatepass/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "getNativeScreenInfo") {
                    val stableDpi = DisplayMetrics.DENSITY_DEVICE_STABLE
                    if (stableDpi > 0) {
                        val realMetrics = DisplayMetrics()
                        @Suppress("DEPRECATION")
                        windowManager.defaultDisplay.getRealMetrics(realMetrics)
                        result.success(mapOf(
                            "nativeWidth" to realMetrics.widthPixels.toDouble(),
                            "nativeHeight" to realMetrics.heightPixels.toDouble(),
                            "nativeScale" to (stableDpi.toDouble() / 160.0),
                        ))
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // -- Lock font scale + display density at every level ----------------

    /** Fix the base context so the Activity starts with fontScale = 1.0. */
    override fun attachBaseContext(newBase: Context) {
        val config = Configuration(newBase.resources.configuration)
        config.fontScale = 1.0f
        if (DisplayMetrics.DENSITY_DEVICE_STABLE > 0) {
            config.densityDpi = DisplayMetrics.DENSITY_DEVICE_STABLE
        }
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    /** Ensure every getResources() call returns fixed values. */
    override fun getResources(): Resources {
        val res = super.getResources()
        val needsFix = res.configuration.fontScale != 1.0f ||
            (DisplayMetrics.DENSITY_DEVICE_STABLE > 0 &&
             res.configuration.densityDpi != DisplayMetrics.DENSITY_DEVICE_STABLE)

        if (needsFix) {
            val config = Configuration(res.configuration)
            config.fontScale = 1.0f
            if (DisplayMetrics.DENSITY_DEVICE_STABLE > 0) {
                config.densityDpi = DisplayMetrics.DENSITY_DEVICE_STABLE
            }
            return createConfigurationContext(config).resources
        }
        return res
    }

    /**
     * Intercept runtime configuration changes (the manifest declares
     * `fontScale|density` in `configChanges`). Flutter's engine receives
     * this Configuration directly, so we patch it before passing it on.
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        val fixedConfig = Configuration(newConfig)
        fixedConfig.fontScale = 1.0f
        if (DisplayMetrics.DENSITY_DEVICE_STABLE > 0) {
            fixedConfig.densityDpi = DisplayMetrics.DENSITY_DEVICE_STABLE
        }
        super.onConfigurationChanged(fixedConfig)
    }

    // -- Normal lifecycle ------------------------------------------------

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        // Draw content behind system bars; Flutter SafeArea handles insets.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        ensureDefaultFcmChannel()
        super.onCreate(savedInstanceState)
    }

    /**
     * FCM expects channel `default` (see backend + Flutter). Creating it natively guarantees
     * system notifications appear even before Dart runs (cold start).
     */
    private fun ensureDefaultFcmChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val id = "default"
        if (nm.getNotificationChannel(id) != null) return

        NotificationChannel(
            id,
            "General",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Visitor alerts, approvals, and society updates"
            enableVibration(true)
            setShowBadge(true)
        }.also { nm.createNotificationChannel(it) }
    }
}
