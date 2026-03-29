package com.tahram.gunlukduahadis

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/**
 * Widget hatim verisi: HomeWidgetPreferences + quran_offline.json.
 * Önceki/sonraki geçiş burada (Flutter arka plan eklentisi olmadan).
 */
object WidgetHatimStore {

    private const val TAG = "WidgetHatimStore"
    private const val KEY_INDEX = "widget_hatim_index"
    private const val KEY_EXPIRE_AT = "widget_verse_expire_at"
    private const val KEY_ARABIC = "ayah_arabic"
    private const val KEY_TURKISH = "ayah_turkish"
    private const val KEY_AYAH_NUM = "ayah_number"
    private const val KEY_FOOTER = "ayah_footer"

    private const val MAX_ARABIC_CP = 600
    private const val MAX_TURKISH_CP = 1100

    private var cachedRows: JSONArray? = null

    /** Önceki (-1) / sonraki (+1) — doğrudan BroadcastReceiver’dan. */
    fun navigateRelative(context: Context, delta: Int) {
        if (delta == 0) return
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val rows = loadVerseRows(context) ?: return
            val total = rows.length()
            if (total <= 0) return

            var idx = prefs.getInt(KEY_INDEX, 0)
            var newIdx = idx + delta
            if (newIdx < 0) newIdx = 0
            if (newIdx >= total) newIdx = total - 1

            val row = rows.getJSONArray(newIdx)
            val ed = prefs.edit()
            ed.putInt(KEY_INDEX, newIdx)
            ed.putString(KEY_ARABIC, clipText(row.getString(3), MAX_ARABIC_CP))
            ed.putString(KEY_TURKISH, clipText(row.getString(4), MAX_TURKISH_CP))
            ed.putString(KEY_AYAH_NUM, row.getInt(1).toString())
            ed.putString(KEY_FOOTER, row.getString(5))
            ed.putString(KEY_EXPIRE_AT, "0")
            ed.commit()
            requestWidgetRedraw(context)
        } catch (e: Exception) {
            Log.e(TAG, "navigateRelative başarısız", e)
        }
    }

    fun requestWidgetRedraw(context: Context) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            val cn = ComponentName(context, DailyContentWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(cn)
            if (ids.isEmpty()) return
            val intent = Intent(context, DailyContentWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w(TAG, "requestWidgetRedraw atlandı", e)
        }
    }

    private fun loadVerseRows(context: Context): JSONArray? {
        cachedRows?.let { return it }
        synchronized(this) {
            cachedRows?.let { return it }
            val paths = listOf(
                "flutter_assets/assets/quran_offline.json",
                "assets/quran_offline.json",
            )
            for (p in paths) {
                try {
                    context.assets.open(p).use { input ->
                        val text = input.bufferedReader().use { it.readText() }
                        val root = JSONObject(text)
                        val v = root.getJSONArray("v")
                        cachedRows = v
                        return v
                    }
                } catch (_: Exception) {
                    continue
                }
            }
        }
        return null
    }

    private fun clipText(text: String, maxCodePoints: Int): String {
        var i = 0
        var count = 0
        while (i < text.length) {
            val cp = Character.codePointAt(text, i)
            count++
            if (count > maxCodePoints) {
                return text.substring(0, i) + "…"
            }
            i += Character.charCount(cp)
        }
        return text
    }
}
