package com.mynamaz.scheduler

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** AlarmManager clears alarms on reboot, so retain their details for the boot receiver. */
object PersistedAlarmScheduler {
    private const val PREFS = "native_alarm_schedule"
    private const val KEY = "alarms"

    @Synchronized
    fun schedule(context: Context, id: Int, timeMs: Long, name: String, title: String,
                 eventType: String, soundType: String) {
        if (timeMs <= System.currentTimeMillis()) return
        val alarms = read(context)
        alarms.put(id, JSONObject().apply {
            put("id", id)
            put("timeMs", timeMs)
            put("name", name)
            put("title", title)
            put("eventType", eventType)
            put("soundType", soundType)
        })
        scheduleSystemAlarm(context, alarms.getValue(id))
        write(context, alarms)
    }

    @Synchronized
    fun cancel(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmIntent(context, id))
        val alarms = read(context)
        alarms.remove(id)
        write(context, alarms)
    }

    @Synchronized
    fun restore(context: Context) {
        val alarms = read(context)
        val now = System.currentTimeMillis()
        val active = alarms.filterValues { it.optLong("timeMs") > now }
        active.values.forEach { alarm ->
            try {
                scheduleSystemAlarm(context, alarm)
            } catch (e: Exception) {
                android.util.Log.e("PersistedAlarmScheduler", "Could not restore alarm", e)
            }
        }
        write(context, active)
    }

    private fun scheduleSystemAlarm(context: Context, alarm: JSONObject) {
        val id = alarm.getInt("id")
        val timeMs = alarm.getLong("timeMs")
        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context, 0, showIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // setAlarmClock wakes the device and permits the receiver to start adhan playback.
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(timeMs, showPendingIntent), alarmIntent(context, id, alarm)
        )
    }

    private fun alarmIntent(context: Context, id: Int, alarm: JSONObject? = null): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmReceiver.ACTION_PRAYER_ALARM
            if (alarm != null) {
                putExtra(PrayerAlarmReceiver.EXTRA_ALARM_ID, id)
                putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, alarm.optString("name", "Namaz"))
                putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TITLE, alarm.optString("title", "Prayer time"))
                putExtra(PrayerAlarmReceiver.EXTRA_EVENT_TYPE, alarm.optString("eventType", "AZAN"))
                putExtra(PrayerAlarmReceiver.EXTRA_SOUND_TYPE, alarm.optString("soundType", "ADHAN"))
            }
        }
        return PendingIntent.getBroadcast(
            context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun read(context: Context): MutableMap<Int, JSONObject> {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]"
        val result = mutableMapOf<Int, JSONObject>()
        val array = JSONArray(stored)
        for (index in 0 until array.length()) {
            val alarm = array.getJSONObject(index)
            result[alarm.getInt("id")] = alarm
        }
        return result
    }

    private fun write(context: Context, alarms: Map<Int, JSONObject>) {
        val array = JSONArray()
        alarms.values.forEach { array.put(it) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, array.toString()).commit()
    }
}
