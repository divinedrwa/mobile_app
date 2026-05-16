package com.app.gatepass

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        // Enable edge-to-edge: content draws behind system bars.
        // Flutter's SafeArea widgets handle the insets on the Dart side.
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
