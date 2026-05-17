package com.app.gatepass

import android.app.Application
import android.content.res.Configuration
import android.content.res.Resources
import android.util.DisplayMetrics

/**
 * Custom Application that forces fontScale = 1.0 and the device's physical
 * display density regardless of the user's "Font size" and "Display size"
 * settings.
 *
 * Flutter's engine reads [fontScale] from
 * `context.getApplicationContext().getResources().getConfiguration()` — so
 * overriding at the Activity level alone is not enough.
 */
class GatePassApplication : Application() {

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
}
