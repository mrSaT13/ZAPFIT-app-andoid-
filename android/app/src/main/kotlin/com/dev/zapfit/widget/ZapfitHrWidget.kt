package com.dev.zapfit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.dev.zapfit.R

class ZapfitHrWidget : AppWidgetProvider() {

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
            val ids = manager.getAppWidgetIds(android.content.ComponentName(context, ZapfitHrWidget::class.java))
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
            val views = RemoteViews(context.packageName, R.layout.zapfit_hr_widget)

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val currentHr = prefs.getLong("flutter.hr_current", 0).toInt()
            val restingHr = prefs.getLong("flutter.hr_resting", 0).toInt()
            val maxHr = prefs.getLong("flutter.hr_max", 0).toInt()
            val lastUpdate = prefs.getString("flutter.last_update", "") ?: ""

            val hasData = currentHr > 0 || restingHr > 0

            if (hasData) {
                views.setTextViewText(R.id.widget_hr_current, if (currentHr > 0) currentHr.toString() else "—")
                views.setTextViewText(R.id.widget_hr_resting, if (restingHr > 0) "$restingHr bpm" else "— bpm")
                views.setTextViewText(R.id.widget_hr_max, if (maxHr > 0) "$maxHr bpm" else "— bpm")
            } else {
                views.setTextViewText(R.id.widget_hr_current, "—")
                views.setTextViewText(R.id.widget_hr_resting, "— bpm")
                views.setTextViewText(R.id.widget_hr_max, "— bpm")
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
            views.setOnClickPendingIntent(R.id.widget_hr_current, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
