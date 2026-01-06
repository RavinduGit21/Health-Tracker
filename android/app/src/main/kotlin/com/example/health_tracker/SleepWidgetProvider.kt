package com.example.health_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import com.example.health_tracker.R

class SleepWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = context.getSharedPreferences("HomeWidgetPausedData", Context.MODE_PRIVATE)
            val isSleeping = widgetData.getBoolean("is_sleeping", false)
            val elapsedMillis = widgetData.getLong("elapsed_millis", 0L)

            val views = RemoteViews(context.packageName, R.layout.sleep_widget_layout).apply {
                if (isSleeping) {
                    setTextViewText(R.id.tv_status, "Sleeping...")
                    setTextViewText(R.id.btn_action, "END SLEEP")
                    setViewVisibility(R.id.widget_chronometer, View.VISIBLE)
                    val base = SystemClock.elapsedRealtime() - elapsedMillis
                    setChronometer(R.id.widget_chronometer, base, null, true)
                } else {
                    setTextViewText(R.id.tv_status, "Ready to rest")
                    setTextViewText(R.id.btn_action, "START SLEEP")
                    setViewVisibility(R.id.widget_chronometer, View.GONE)
                    setChronometer(R.id.widget_chronometer, SystemClock.elapsedRealtime(), null, false)
                }

                // Action to toggle sleep
                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("homeWidgetSleep://toggle")
                )
                setOnClickPendingIntent(R.id.btn_action, intent)

                // Action to open app
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.tv_title, launchIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
    }
}
