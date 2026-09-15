package com.dev.zapfit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.dev.zapfit.R

class ZapfitDailyWidget : AppWidgetProvider() {

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
            val ids = manager.getAppWidgetIds(android.content.ComponentName(context, ZapfitDailyWidget::class.java))
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
            val views = RemoteViews(context.packageName, R.layout.zapfit_daily_widget)

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val steps = prefs.getLong("flutter.today_steps", 0).toInt()
            val goal = prefs.getLong("flutter.today_goal", 10000).toInt()
            val lastUpdate = prefs.getString("flutter.last_update", "") ?: ""

            val hasData = steps > 0 || goal > 0

            if (hasData) {
                views.setTextViewText(R.id.widget_steps, steps.toString())
                views.setTextViewText(R.id.widget_goal, "Цель: $goal")
                views.setViewVisibility(R.id.widget_steps, View.VISIBLE)
                views.setViewVisibility(R.id.widget_steps_label, View.VISIBLE)
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                views.setViewVisibility(R.id.widget_goal, View.VISIBLE)

                val progress = if (goal > 0) ((steps.toFloat() / goal) * 100).toInt().coerceIn(0, 100) else 0
                views.setProgressBar(R.id.widget_progress, 100, progress, false)

                if (lastUpdate.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_update, "Обновлено: $lastUpdate")
                }
            } else {
                views.setTextViewText(R.id.widget_steps, "—")
                views.setViewVisibility(R.id.widget_steps_label, View.VISIBLE)
                views.setViewVisibility(R.id.widget_progress, View.GONE)
                views.setViewVisibility(R.id.widget_goal, View.GONE)
                views.setTextViewText(R.id.widget_update, "Откройте приложение для данных")
            }

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_steps, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
