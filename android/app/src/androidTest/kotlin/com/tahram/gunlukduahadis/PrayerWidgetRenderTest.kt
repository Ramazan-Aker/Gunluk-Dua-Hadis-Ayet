package com.tahram.gunlukduahadis

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.Calendar

/** Inflate real RemoteViews on Android, including actions and autosizing. */
@RunWith(AndroidJUnit4::class)
class PrayerWidgetRenderTest {
    @Test fun allSizesShowImsakAndKeepTextInsideBounds() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val base = instrumentation.targetContext
        val data = base.getSharedPreferences("qa_widget_render", Context.MODE_PRIVATE)
        val clock = Calendar.getInstance()
        val names = listOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
        val times = listOf("05:10", "06:35", "13:05", "16:40", "19:30", "20:50")
        val schedule = JSONArray()
        names.forEachIndexed { i, name ->
            clock.set(Calendar.HOUR_OF_DAY, times[i].substringBefore(':').toInt())
            clock.set(Calendar.MINUTE, times[i].substringAfter(':').toInt())
            clock.set(Calendar.SECOND, 0)
            schedule.put(JSONObject().put("name", name).put("time", times[i]).put("at", clock.timeInMillis))
        }
        data.edit().putString("prayer_widget_city", "Afyonkarahisar")
            .putString("prayer_widget_schedule_json", schedule.toString()).commit()
        try {
            instrumentation.runOnMainSync {
                val provider = PrayerTimesWidgetProvider()
                val read = provider.javaClass.declaredMethods.single { it.name == "readSchedule" }.apply { isAccessible = true }
                val layout = provider.javaClass.declaredMethods.single { it.name == "layoutFor" }.apply { isAccessible = true }
                val build = provider.javaClass.declaredMethods.single { it.name == "buildViews" }.apply { isAccessible = true }
                val moments = read.invoke(provider, data)
                for (scale in listOf(1f, 2f)) {
                    val config = Configuration(base.resources.configuration).apply { fontScale = scale }
                    val context = base.createConfigurationContext(config)
                    for ((width, height) in listOf(150 to 64, 250 to 80, 180 to 180, 280 to 140, 340 to 150, 400 to 250)) {
                        val label = "widget_${width}x${height}_font$scale"
                        val layoutId = layout.invoke(provider, (width / scale).toInt(), (height / scale).toInt()) as Int
                        val views = build.invoke(provider, context, data, moments, layoutId) as RemoteViews
                        val parent = FrameLayout(context)
                        val root = views.apply(context, parent)
                        parent.addView(root)
                        val density = context.resources.displayMetrics.density
                        val w = (width * density).toInt()
                        val h = (height * density).toInt()
                        parent.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
                        parent.layout(0, 0, w, h)
                        val imsak = root.findViewById<TextView>(R.id.prayer_widget_imsak)
                        assertEquals(label, "05:10", imsak.text.toString())
                        fun check(view: View, ancestorsVisible: Boolean) {
                            val visible = ancestorsVisible && view.visibility == View.VISIBLE
                            if (!visible) return
                            if (view is TextView && view.text.isNotEmpty()) {
                                val bounds = Rect(0, 0, view.width, view.height)
                                parent.offsetDescendantRectToMyCoords(view, bounds)
                                assertTrue("$label: ${view.text} has no space", view.width > 0 && view.height > 0)
                                assertTrue("$label: ${view.text} outside $bounds / ${w}x$h", bounds.left >= 0 && bounds.top >= 0 && bounds.right <= w && bounds.bottom <= h)
                                val textLayout = view.layout
                                if (textLayout != null && (view.text.toString().matches(Regex("[0-9]{2}:[0-9]{2}")) || view.id == R.id.prayer_label_imsak)) {
                                    assertEquals("$label: clipped prayer time ${view.text}", 0, textLayout.getEllipsisCount(0))
                                }
                            }
                            if (view is ViewGroup) for (i in 0 until view.childCount) check(view.getChildAt(i), visible)
                        }
                        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        parent.draw(Canvas(bitmap))
                        val folder = File(base.getExternalFilesDir(null), "qa").apply { mkdirs() }
                        File(folder, "$label.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        bitmap.recycle()
                        check(root, true)
                    }
                }
            }
        } finally { data.edit().clear().commit() }
    }
}
