package com.tahram.gunlukduahadis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class DailyContentWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetHatimStore.maybeRollRandomVerseIfExpired(context)
        val data = HomeWidgetPlugin.getData(context)

        appWidgetIds.forEach { widgetId ->
            try {
                val listIndex = data.getInt("widget_hatim_index", 0)
                val openFullVerse = WidgetOpenVersePendingIntent.create(context, listIndex)
                val views = buildViews(context, data, openFullVerse)
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Widget güncellenemedi", e)
                try {
                    val openApp =
                        HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("hergunislam://home"),
                        )
                    val fallback = RemoteViews(context.packageName, R.layout.widget_fallback)
                    fallback.setOnClickPendingIntent(R.id.widget_fallback_text, openApp)
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (e2: Exception) {
                    Log.e(TAG, "Yedek widget da başarısız", e2)
                }
            }
        }
    }

    private fun buildViews(
        context: Context,
        widgetData: SharedPreferences,
        openFullVerse: android.app.PendingIntent,
    ): RemoteViews {
        val turkish = widgetData.getString("ayah_turkish", null)
        val footer = widgetData.getString("ayah_footer", null)

        return RemoteViews(context.packageName, R.layout.daily_content_widget).apply {
            setTextViewText(
                R.id.widget_turkish,
                turkish ?: context.getString(R.string.widget_placeholder_turkish),
            )
            setTextViewText(
                R.id.widget_footer,
                footer ?: context.getString(R.string.widget_placeholder_footer),
            )

            setOnClickPendingIntent(R.id.widget_root, openFullVerse)
            setOnClickPendingIntent(R.id.widget_left_column, openFullVerse)
            setOnClickPendingIntent(R.id.widget_footer, openFullVerse)
            setOnClickPendingIntent(R.id.widget_turkish, openFullVerse)
        }
    }

    companion object {
        private const val TAG = "DailyContentWidget"
    }
}
