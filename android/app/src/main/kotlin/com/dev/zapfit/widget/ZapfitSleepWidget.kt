package com.dev.zapfit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.dev.zapfit.R

class ZapfitSleepWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        try {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(android.content.ComponentName(context, ZapfitSleepWidget::class.java))
            for (id in ids) {
                updateAppWidget(context, manager, id)
            }
        } catch (_: Exception) {}
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.zapfit_sleep_widget)

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val totalMin = prefs.getLong("flutter.sleep_total_min", 0).toInt()
            val deepMin = prefs.getLong("flutter.sleep_deep_min", 0).toInt()
            val lightMin = prefs.getLong("flutter.sleep_light_min", 0).toInt()
            val remMin = prefs.getLong("flutter.sleep_rem_min", 0).toInt()
            val score = prefs.getLong("flutter.sleep_score", 0).toInt()
            val range = prefs.getString("flutter.sleep_range", "") ?: ""
            val lastUpdate = prefs.getString("flutter.last_update", "") ?: ""

            val hasData = totalMin > 0 || score > 0

            if (hasData) {
                val hours = totalMin / 60
                val mins = totalMin % 60

                views.setTextViewText(R.id.widget_sleep_score, score.toString())
                views.setTextViewText(R.id.widget_sleep_range, range)
                views.setTextViewText(R.id.widget_sleep_total, "${hours}ч ${mins}м")
                views.setTextViewText(R.id.widget_sleep_deep, "Г: ${deepMin}м")
                views.setTextViewText(R.id.widget_sleep_light, "Л: ${lightMin}м")
                views.setTextViewText(R.id.widget_sleep_rem, "REM: ${remMin}м")

                views.setViewVisibility(R.id.widget_sleep_score, View.VISIBLE)
                views.setViewVisibility(R.id.widget_sleep_total, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.widget_sleep_score, "—")
                views.setTextViewText(R.id.widget_sleep_range, "Нет данных")
                views.setViewVisibility(R.id.widget_sleep_total, View.GONE)
                views.setViewVisibility(R.id.widget_sleep_deep, View.GONE)
                views.setViewVisibility(R.id.widget_sleep_light, View.GONE)
                views.setViewVisibility(R.id.widget_sleep_rem, View.GONE)
            }

            if (lastUpdate.isNotEmpty()) {
                views.setTextViewText(R.id.widget_update, "Обновлено: $lastUpdate")
            }

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_sleep_score, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
