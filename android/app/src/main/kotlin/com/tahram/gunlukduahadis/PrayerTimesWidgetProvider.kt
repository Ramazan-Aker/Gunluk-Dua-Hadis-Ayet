package com.tahram.gunlukduahadis

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

class PrayerTimesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val schedule = readSchedule(data)
        appWidgetIds.forEach { widgetId ->
            try {
                updateWidget(context, appWidgetManager, widgetId, data, schedule)
            } catch (error: Exception) {
                Log.e(TAG, "Namaz widget guncellenemedi", error)
            }
        }
        scheduleNextTransition(context, schedule)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = HomeWidgetPlugin.getData(context)
        val schedule = readSchedule(data)
        updateWidget(context, appWidgetManager, appWidgetId, data, schedule, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_PRAYER_TRANSITION) return
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, PrayerTimesWidgetProvider::class.java))
        if (ids.isNotEmpty()) {
            onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
        schedule: List<PrayerMoment>,
        options: Bundle = appWidgetManager.getAppWidgetOptions(widgetId),
    ) {
        val fontScale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        fun sized(width: Int, height: Int): RemoteViews = buildViews(
            context, widgetData, schedule, layoutFor((width / fontScale).toInt(), (height / fontScale).toInt()))
        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) RemoteViews(sizes.associateWith { sized(it.width.toInt(), it.height.toInt()) })
            else sized(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250), options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 80))
        } else {
            val portrait = sized(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250), options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 80))
            val landscape = sized(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 250), options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 80))
            RemoteViews(landscape, portrait)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun layoutFor(width: Int, height: Int): Int = when {
        height < 120 || width < 150 -> R.layout.prayer_times_widget
        width < 300 -> R.layout.prayer_times_widget_narrow
        else -> R.layout.prayer_times_widget_expanded
    }

    private fun buildViews(
        context: Context,
        widgetData: SharedPreferences,
        schedule: List<PrayerMoment>,
        layoutId: Int,
    ): RemoteViews {
        val now = System.currentTimeMillis()
        val next = schedule.firstOrNull { it.at > now }
        val today = schedule.filter { isSameDay(it.at, now) }.associateBy { it.name }
        val openPrayer =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("hergunislam://prayer"),
            )

        return RemoteViews(context.packageName, layoutId).apply {
            setTextViewText(
                R.id.prayer_widget_city,
                widgetData.getString(CITY_KEY, null) ?: context.getString(R.string.prayer_widget_city_placeholder),
            )
            setTextViewText(
                R.id.prayer_widget_next_name,
                next?.name ?: context.getString(R.string.prayer_widget_open_app),
            )
            setTextViewText(R.id.prayer_widget_next_time, next?.time ?: "--:--")
            setPrayerTime(R.id.prayer_widget_imsak, today["İmsak"]?.time ?: today["Sabah"]?.time)
            setPrayerTime(R.id.prayer_widget_sabah, today["Güneş"]?.time)
            setPrayerTime(R.id.prayer_widget_ogle, today["Öğle"]?.time)
            setPrayerTime(R.id.prayer_widget_ikindi, today["İkindi"]?.time)
            setPrayerTime(R.id.prayer_widget_aksam, today["Akşam"]?.time)
            setPrayerTime(R.id.prayer_widget_yatsi, today["Yatsı"]?.time)

            if (next != null) {
                val base = SystemClock.elapsedRealtime() + (next.at - now).coerceAtLeast(0)
                setViewVisibility(R.id.prayer_widget_countdown, View.VISIBLE)
                setChronometer(R.id.prayer_widget_countdown, base, null, true)
            } else {
                setChronometer(R.id.prayer_widget_countdown, SystemClock.elapsedRealtime(), null, false)
                setTextViewText(R.id.prayer_widget_countdown, context.getString(R.string.prayer_widget_refresh))
            }

            setOnClickPendingIntent(R.id.prayer_widget_root, openPrayer)
        }
    }

    private fun RemoteViews.setPrayerTime(viewId: Int, time: String?) {
        setTextViewText(viewId, time ?: "--:--")
    }

    private fun readSchedule(data: SharedPreferences): List<PrayerMoment> {
        val raw = data.getString(SCHEDULE_KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val name = item.optString("name")
                    val time = item.optString("time")
                    val at = item.optLong("at")
                    if (name.isNotBlank() && time.isNotBlank() && at > 0) {
                        add(PrayerMoment(name, time, at))
                    }
                }
            }.sortedBy { it.at }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun scheduleNextTransition(context: Context, schedule: List<PrayerMoment>) {
        val next = schedule.firstOrNull { it.at > System.currentTimeMillis() } ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, PrayerTimesWidgetProvider::class.java).apply {
            action = ACTION_PRAYER_TRANSITION
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(context, TRANSITION_REQUEST_CODE, intent, flags)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.at + 1_000, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, next.at + 1_000, pendingIntent)
        }
    }

    private fun isSameDay(first: Long, second: Long): Boolean {
        val a = Calendar.getInstance().apply { timeInMillis = first }
        val b = Calendar.getInstance().apply { timeInMillis = second }
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    private data class PrayerMoment(val name: String, val time: String, val at: Long)

    companion object {
        private const val TAG = "PrayerTimesWidget"
        private const val CITY_KEY = "prayer_widget_city"
        private const val SCHEDULE_KEY = "prayer_widget_schedule_json"
        private const val ACTION_PRAYER_TRANSITION =
            "com.tahram.gunlukduahadis.PRAYER_WIDGET_TRANSITION"
        private const val TRANSITION_REQUEST_CODE = 920_001
    }
}
