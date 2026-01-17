package com.tahram.gunlukduahadis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Broadcast receiver to reschedule notifications after device reboot
 * or app update
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val CHANNEL = "com.tahram.gunlukduahadis/notification"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Device boot completed - rescheduling notifications")
                rescheduleNotifications(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "App updated - rescheduling notifications")
                rescheduleNotifications(context)
            }
            "android.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Quick boot completed - rescheduling notifications")
                rescheduleNotifications(context)
            }
        }
    }

    private fun rescheduleNotifications(context: Context) {
        try {
            // Get SharedPreferences to check if reminders are enabled
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val reminderEnabled = prefs.getBoolean("flutter.reminder_enabled", true)
            
            Log.d(TAG, "Reminder enabled: $reminderEnabled")
            
            if (reminderEnabled) {
                // Start MainActivity to trigger Flutter initialization and reschedule notifications
                val launchIntent = Intent(context, MainActivity::class.java)
                launchIntent.action = "RESCHEDULE_NOTIFICATIONS"
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
                
                Log.d(TAG, "✅ Notification rescheduling initiated")
            } else {
                Log.d(TAG, "⚠️ Reminders are disabled - not rescheduling")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error rescheduling notifications: ${e.message}", e)
        }
    }
}

