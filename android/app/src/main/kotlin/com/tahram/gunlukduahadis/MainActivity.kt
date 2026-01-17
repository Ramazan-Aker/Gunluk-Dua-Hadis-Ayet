package com.tahram.gunlukduahadis

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.tahram.gunlukduahadis/notification"
    private val BATTERY_CHANNEL = "com.tahram.gunlukduahadis/battery"
    private var shouldRescheduleNotifications = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if launched from BootReceiver
        if (intent?.action == "RESCHEDULE_NOTIFICATIONS") {
            shouldRescheduleNotifications = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        // Check if launched from BootReceiver
        if (intent.action == "RESCHEDULE_NOTIFICATIONS") {
            shouldRescheduleNotifications = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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

