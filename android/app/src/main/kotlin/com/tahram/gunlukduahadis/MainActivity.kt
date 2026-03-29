package com.tahram.gunlukduahadis

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.webkit.WebView
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.tahram.gunlukduahadis/notification"
    private val BATTERY_CHANNEL = "com.tahram.gunlukduahadis/battery"
    private val WIDGET_VERSE_CHANNEL = "com.tahram.gunlukduahadis/widget_verse"
    private var shouldRescheduleNotifications = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Reduces Chromium/WebView debug spam when AdMob loads web content (does not silence Play Services).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(false)
        }
        super.onCreate(savedInstanceState)
        captureWidgetVerseIndexFromIntent(intent)
        attachWidgetVerseUriIfMissing(intent)

        // Check if launched from BootReceiver
        if (intent?.action == "RESCHEDULE_NOTIFICATIONS") {
            shouldRescheduleNotifications = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetVerseIndexFromIntent(intent)
        attachWidgetVerseUriIfMissing(intent)

        // Check if launched from BootReceiver
        if (intent.action == "RESCHEDULE_NOTIFICATIONS") {
            shouldRescheduleNotifications = true
        }
    }

    /**
     * Yalnızca tam ayet açılışı: extra, widgetVerse URI veya data bozuksa prefs.
     * [hergunislam://home] gibi genel açılışlarda prefs ile yönlendirme yapılmaz.
     */
    private fun captureWidgetVerseIndexFromIntent(intent: Intent?) {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return
        val data = intent.data
        var idx: Int? = null
        val fromExtra = intent.getIntExtra(WidgetOpenVersePendingIntent.EXTRA_LIST_INDEX, Int.MIN_VALUE)
        if (fromExtra != Int.MIN_VALUE && fromExtra >= 0) {
            idx = fromExtra
        }
        if (idx == null && data?.host == "widgetVerse") {
            data.getQueryParameter("i")?.toIntOrNull()?.let { if (it >= 0) idx = it }
        }
        if (idx == null && data?.host != "home" && (data == null || data.host == "widgetVerse")) {
            try {
                val prefs = applicationContext.getSharedPreferences(
                    "HomeWidgetPreferences",
                    Context.MODE_PRIVATE,
                )
                idx = prefs.getInt("widget_hatim_index", 0)
            } catch (_: Exception) {
            }
        }
        if (idx != null) {
            synchronized(pendingWidgetVerseLock) {
                pendingWidgetVerseListIndex = idx
            }
        }
    }

    /**
     * Bazı cihazlarda widget tıklanınca LAUNCH action gelir ama intent.data boş kalır;
     * home_widget eklentisi URI okuyamaz. Son hatim indeksini prefs’ten URI’ye yazarız.
     */
    private fun attachWidgetVerseUriIfMissing(intent: Intent?) {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return
        if (intent.data != null && intent.data.toString().startsWith("hergunislam://")) return
        try {
            val prefs = applicationContext.getSharedPreferences(
                "HomeWidgetPreferences",
                Context.MODE_PRIVATE,
            )
            val idx = prefs.getInt("widget_hatim_index", 0)
            intent.data = Uri.parse("hergunislam://widgetVerse?i=$idx")
        } catch (_: Exception) {
        }
    }

    companion object {
        private val pendingWidgetVerseLock = Any()
        @Volatile
        private var pendingWidgetVerseListIndex: Int? = null

        @JvmStatic
        fun consumePendingWidgetVerseListIndex(): Int? {
            synchronized(pendingWidgetVerseLock) {
                val v = pendingWidgetVerseListIndex
                pendingWidgetVerseListIndex = null
                return v
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_VERSE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingVerseListIndex" -> {
                    result.success(MainActivity.consumePendingWidgetVerseListIndex())
                }
                else -> result.notImplemented()
            }
        }
        
        // Notification channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shouldRescheduleNotifications" -> {
                    result.success(shouldRescheduleNotifications)
                    shouldRescheduleNotifications = false // Reset flag
                }
                else -> result.notImplemented()
            }
        }
        
        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatterySettings" -> {
                    try {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open battery settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    /**
     * Open battery optimization settings
     * This allows user to exempt the app from battery optimizations
     * so notifications work reliably even when app is in background
     */
    private fun openBatteryOptimizationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Try to open the ignore battery optimization settings for this specific app
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            } else {
                // For older versions, open general battery settings
                val intent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                startActivity(intent)
            }
        } catch (e: Exception) {
            // Fallback to general settings if specific settings not available
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                startActivity(intent)
            } catch (fallbackException: Exception) {
                throw Exception("Unable to open settings: ${fallbackException.message}")
            }
        }
    }
}

