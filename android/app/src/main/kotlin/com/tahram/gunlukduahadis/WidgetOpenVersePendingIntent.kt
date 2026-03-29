package com.tahram.gunlukduahadis

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Widget metin alanına tıklanınca [MainActivity] açılır.
 * URI + extra ile indeks taşınır; [requestCode] = base + listIndex olunca PendingIntent’ler birbirini ezmez.
 */
object WidgetOpenVersePendingIntent {
    const val EXTRA_LIST_INDEX: String = "widget_verse_list_index"
    private const val REQ_CODE_BASE = 910_000

    fun create(context: Context, listIndex: Int): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("hergunislam://widgetVerse?i=$listIndex")
                putExtra(EXTRA_LIST_INDEX, listIndex)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val req = REQ_CODE_BASE + listIndex.coerceIn(0, 50_000)
        return PendingIntent.getActivity(context, req, intent, flags)
    }
}
