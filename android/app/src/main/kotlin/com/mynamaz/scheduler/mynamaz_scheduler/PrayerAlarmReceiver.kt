package com.mynamaz.scheduler.mynamaz_scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class PrayerAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PRAYER_ALARM = "com.mynamaz.scheduler.ACTION_PRAYER_ALARM"
        const val ACTION_STOP_ALARM = "com.mynamaz.scheduler.ACTION_STOP_ALARM"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TITLE = "prayer_title"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_EVENT_TYPE = "event_type"
        const val EXTRA_SOUND_TYPE = "sound_type"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        when (action) {
            ACTION_PRAYER_ALARM -> {
                val serviceIntent = Intent(context, PrayerAlarmService::class.java).apply {
                    setAction(ACTION_PRAYER_ALARM)
                    putExtras(intent)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
            ACTION_STOP_ALARM -> {
                PrayerAlarmService.stopAlarm(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Handled when app is launched or rescheduled
            }
        }
    }
}
