package com.example.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    companion object {
        // MUST stay byte-identical to ONESIGNAL_ANDROID_CHANNEL_ID in the
        // firmware's config.h — the ESP32 sends this exact string as
        // existing_android_channel_id on every alert push. If the two ever
        // drift, OneSignal silently falls back to its own "Miscellaneous"
        // channel with no error logged anywhere, taking the lock-screen
        // behaviour configured below with it.
        private const val ALERT_CHANNEL_ID = "farm_alerts"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertNotificationChannel()
    }

    /**
     * Farm alerts must be readable from the lock screen without unlocking —
     * the entire point is that a gas or temperature trip reaches whoever is
     * asleep at 3am.
     *
     * OneSignal's default "Miscellaneous" channel is created with PRIVATE
     * lockscreen visibility, which hides the notification's text on the lock
     * screen for any user who has "hide sensitive notification content"
     * enabled in system settings — they see the app name and nothing else.
     * On Android 8+ the CHANNEL's visibility governs and cannot be overridden
     * from the push payload (android_visibility is ignored once a channel
     * applies), so declaring our own PUBLIC channel here is the only fix.
     *
     * Channel behaviour is immutable after first creation — Android hands
     * ownership to the user at that point, and createNotificationChannel()
     * on an existing id updates only the name/description. Changing the
     * importance or visibility later therefore requires a NEW channel id,
     * not an edit to this one.
     */
    private fun createAlertNotificationChannel() {
        // Pre-Oreo has no channels at all; there the per-notification
        // visibility applies and lock-screen content already shows.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "Farm Alerts",
            NotificationManager.IMPORTANCE_HIGH  // heads-up banner + sound
        ).apply {
            description = "Gas, temperature and humidity alerts from your farm controller"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC  // full text on the lock screen
            enableVibration(true)
            setShowBadge(true)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }
}
