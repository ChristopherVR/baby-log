package com.babyapp.baby_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** A user-started feeding timer. Each alarm schedules the next active-time
 * milestone, without a foreground service or a Dart engine in the background. */
object FeedingTimer {
    private const val PREFS = "babylog_feeding_timer"
    private const val ID = 2000000
    private const val INTERVAL = 5 * 60 * 1000L
    private const val CHANNEL = "feeding_timer"
    private const val TICK = "com.babyapp.baby_app.FEEDING_TICK"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun alarms(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun notifications(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun open(context: Context) = PendingIntent.getActivity(context, ID,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun tick(context: Context, origin: Long = 0) = PendingIntent.getBroadcast(context, ID,
        Intent(context, FeedingTimerReceiver::class.java).setAction(TICK).putExtra("origin", origin),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "babylog/feeding_timer").setMethodCallHandler { call, result ->
            if (call.method != "schedule") { result.notImplemented(); return@setMethodCallHandler }
            try {
                val origin = call.argument<Number>("origin")?.toLong() ?: 0L
                // Cancel both the future alarm and any delivered notification.
                alarms(context).cancel(tick(context))
                notifications(context).cancel(ID)
                prefs(context).edit().putLong("origin", origin)
                    .putString("title", call.argument<String>("title"))
                    .putString("body", call.argument<String>("body")).commit()
                if (origin > 0) {
                    if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context,
                            Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("notification_permission", "Allow notifications for feeding reminders", null)
                        return@setMethodCallHandler
                    }
                    scheduleNext(context)
                }
                result.success(null)
            } catch (e: Exception) { result.error("feeding_timer", e.message, null) }
        }
    }

    fun scheduleNext(context: Context) {
        val origin = prefs(context).getLong("origin", 0)
        if (origin <= 0) return
        val now = System.currentTimeMillis()
        val elapsed = (now - origin).coerceAtLeast(0)
        val next = origin + (elapsed / INTERVAL + 1) * INTERVAL
        // Alarm-clock scheduling preserves five-minute spacing in Doze. This is
        // a visible, explicitly enabled user timer, with a quiet single chime.
        alarms(context).setAlarmClock(AlarmManager.AlarmClockInfo(next, open(context)), tick(context, origin))
    }

    fun receive(context: Context, intent: Intent) {
        val saved = prefs(context)
        val origin = saved.getLong("origin", 0)
        if (origin <= 0) return
        if (intent.action == TICK) {
            // Ignore a queued tick from before a pause/resume or a new feed.
            if (intent.getLongExtra("origin", 0) != origin) return
            val manager = notifications(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "Feeding timer", NotificationManager.IMPORTANCE_HIGH))
            }
            if (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context,
                    Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                manager.notify(ID, NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setContentTitle(saved.getString("title", "Feeding check-in"))
                    .setContentText(saved.getString("body", "Another 5 minutes of feeding"))
                    .setStyle(NotificationCompat.BigTextStyle().bigText(saved.getString("body", "")))
                    .setContentIntent(open(context)).setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE).build())
            }
        }
        scheduleNext(context)
    }
}

class FeedingTimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { FeedingTimer.receive(context, intent) }
        catch (e: Exception) { android.util.Log.w("BabyLog", "Feeding reminder unavailable", e) }
    }
}
