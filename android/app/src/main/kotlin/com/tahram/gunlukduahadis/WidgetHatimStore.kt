package com.tahram.gunlukduahadis

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.random.Random
import org.json.JSONArray
import org.json.JSONObject

/**
 * Widget ayet verisi: HomeWidget prefs + assets/quran_offline.json.
 * Rastgele ayet; süre dolunca (launcher periyodik güncellemesi vb.) yenilenir.
 */
object WidgetHatimStore {

    private const val TAG = "WidgetHatimStore"
    private const val KEY_INDEX = "widget_hatim_index"
    private const val KEY_EXPIRE_AT = "widget_verse_expire_at"
    private const val KEY_ARABIC = "ayah_arabic"
    private const val KEY_TURKISH = "ayah_turkish"
    private const val KEY_AYAH_NUM = "ayah_number"
    private const val KEY_FOOTER = "ayah_footer"

    /** Flutter [HomeScreenWidgetService] ile aynı (ms). */
    private const val ROTATE_MS = 6L * 60L * 60L * 1000L

    private const val MAX_TURKISH_CP = 1100

    private var cachedRows: JSONArray? = null

    /**
     * Süre dolduysa veya metin boşsa rastgele yeni ayet yazar.
     * [DailyContentWidgetProvider.onUpdate] başında çağrılır; uygulama kapalıyken de sistem güncellemesiyle döner.
     */
    fun maybeRollRandomVerseIfExpired(context: Context) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val rows = loadVerseRows(context) ?: return
            val total = rows.length()
            if (total <= 0) return

            val expireStr = prefs.getString(KEY_EXPIRE_AT, "0") ?: "0"
            val expireAt = expireStr.toLongOrNull() ?: 0L
            val now = System.currentTimeMillis()
            val turkish = prefs.getString(KEY_TURKISH, null)

            if (now < expireAt && expireAt > 0 && !turkish.isNullOrBlank()) {
                return
            }

            val idx = Random.nextInt(total)
            val row = rows.getJSONArray(idx)
            val ed = prefs.edit()
            ed.putInt(KEY_INDEX, idx)
            ed.putString(KEY_ARABIC, "")
            ed.putString(KEY_TURKISH, clipText(row.getString(4), MAX_TURKISH_CP))
            ed.putString(KEY_AYAH_NUM, row.getInt(1).toString())
            ed.putString(KEY_FOOTER, row.getString(5))
            ed.putString(KEY_EXPIRE_AT, (now + ROTATE_MS).toString())
            ed.commit()
        } catch (e: Exception) {
            Log.e(TAG, "maybeRollRandomVerseIfExpired başarısız", e)
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
