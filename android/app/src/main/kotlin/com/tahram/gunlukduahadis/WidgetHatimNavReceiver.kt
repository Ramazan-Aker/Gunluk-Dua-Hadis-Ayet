package com.tahram.gunlukduahadis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Widget Önceki/Sonraki tıklaması. Flutter arka plan motorunda plugin olmadığı için
 * [HomeWidgetBackgroundWorker] yerine doğrudan prefs + widget yenileme kullanılır.
 */
class WidgetHatimNavReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val delta = intent?.getIntExtra(EXTRA_DELTA, 0) ?: 0
        if (delta == 0) return
        WidgetHatimStore.navigateRelative(context.applicationContext, delta)
    }

    companion object {
        const val EXTRA_DELTA = "delta"

        const val REQ_PREV = 8801
        const val REQ_NEXT = 8802

        fun pendingIntentForDelta(context: Context, delta: Int, requestCode: Int): android.app.PendingIntent {
            val appCtx = context.applicationContext
            val i = Intent(appCtx, WidgetHatimNavReceiver::class.java)
            i.putExtra(EXTRA_DELTA, delta)
            var flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT
            if (android.os.Build.VERSION.SDK_INT >= 23) {
                flags = flags or android.app.PendingIntent.FLAG_IMMUTABLE
            }
            return android.app.PendingIntent.getBroadcast(appCtx, requestCode, i, flags)
        }
    }
}
