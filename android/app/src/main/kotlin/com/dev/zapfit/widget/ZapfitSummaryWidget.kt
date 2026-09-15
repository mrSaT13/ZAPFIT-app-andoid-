package com.dev.zapfit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.dev.zapfit.R

class ZapfitSummaryWidget : AppWidgetProvider() {

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
            val ids = manager.getAppWidgetIds(android.content.ComponentName(context, ZapfitSummaryWidget::class.java))
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
            val views = RemoteViews(context.packageName, R.layout.zapfit_summary_widget)

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val steps = prefs.getLong("flutter.today_steps", 0).toInt()
            val water = prefs.getString("flutter.water_today", "0") ?: "0"
            val distance = prefs.getString("flutter.distance_today", "0") ?: "0"
            val lastUpdate = prefs.getString("flutter.last_update", "") ?: ""

            val hasData = steps > 0

            if (hasData) {
                views.setTextViewText(R.id.widget_steps, steps.toString())
                views.setTextViewText(R.id.widget_distance, distance)
                views.setTextViewText(R.id.widget_water, water)
            } else {
                views.setTextViewText(R.id.widget_steps, "—")
                views.setTextViewText(R.id.widget_distance, "—")
                views.setTextViewText(R.id.widget_water, "—")
            }

            if (lastUpdate.isNotEmpty()) {
                views.setTextViewText(R.id.widget_update, "Обновлено: $lastUpdate")
            } else {
                views.setTextViewText(R.id.widget_update, "Откройте приложение для данных")
            }

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_steps, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
