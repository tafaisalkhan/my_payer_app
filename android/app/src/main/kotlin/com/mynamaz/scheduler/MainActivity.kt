package com.mynamaz.scheduler

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mynamaz.scheduler/volume"
    private var methodChannel: MethodChannel? = null
    private var previousMusicVolume: Int = -1
    private var previousAlarmVolume: Int = -1
    private var isSoundPlaying: Boolean = false
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onDestroy() {
        abandonExclusiveAudioFocus()
        super.onDestroy()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Intercept any hardware button press (Volume Up, Volume Down, Power, Media, Back)
        if ((isSoundPlaying || PrayerAlarmService.isRinging) && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP,
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_POWER,
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_STOP,
                KeyEvent.KEYCODE_MEDIA_PAUSE,
                KeyEvent.KEYCODE_BACK -> {
                    stopPlayingSound()
                    return true // Consume event so volume stream isn't altered while silencing
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isSoundPlaying || PrayerAlarmService.isRinging) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP,
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_POWER,
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_STOP,
                KeyEvent.KEYCODE_MEDIA_PAUSE,
                KeyEvent.KEYCODE_BACK -> {
                    stopPlayingSound()
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun requestExclusiveAudioFocus(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // 1. Dispatch media pause key event to pause YouTube, Spotify, and other running media players immediately
        try {
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (_: Exception) {}

        // 2. Request exclusive Audio Focus on USAGE_ALARM so other app notifications do not pause or stop Azan
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false) // Never duck or pause for incoming notifications from other apps
                .setOnAudioFocusChangeListener { _ ->
                    // Do NOT stop Azan for other app notifications or transient focus losses.
                    // Azan must ONLY stop when the user explicitly stops it.
                }
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                { /* Do not stop for other app notifications */ },
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonExclusiveAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
                audioFocusRequest = null
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun resumePreviousMedia() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Dispatch media play key event to resume previous app (YouTube, Spotify, etc.)
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY))
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY))
        } catch (_: Exception) {}
    }

    private fun stopPlayingSound() {
        PrayerAlarmService.stopAlarm(this)
        if (isSoundPlaying) {
            isSoundPlaying = false
            abandonExclusiveAudioFocus()
            restoreDeviceVolume()
            resumePreviousMedia()
            runOnUiThread {
                methodChannel?.invokeMethod("stopSound", null)
            }
        }
    }

    private fun restoreDeviceVolume() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (previousAlarmVolume != -1) {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previousAlarmVolume, 0)
            previousAlarmVolume = -1
        }
        if (previousMusicVolume != -1) {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previousMusicVolume, 0)
            previousMusicVolume = -1
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createSystemAlarmChannels()

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "getSystemAlarmUri" -> {
                    try {
                        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            ?: Settings.System.DEFAULT_ALARM_ALERT_URI
                        result.success(alarmUri.toString())
                    } catch (e: Exception) {
                        result.success(Settings.System.DEFAULT_ALARM_ALERT_URI.toString())
                    }
                }
                "setSoundPlaying" -> {
                    val playing = call.argument<Boolean>("isPlaying") ?: false
                    isSoundPlaying = playing
                    if (playing) {
                        requestExclusiveAudioFocus()
                    } else {
                        abandonExclusiveAudioFocus()
                        restoreDeviceVolume()
                    }
                    result.success(true)
                }
                "boostVolume" -> {
                    try {
                        isSoundPlaying = true
                        requestExclusiveAudioFocus()

                        val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        
                        if (previousAlarmVolume == -1) {
                            previousAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                        }
                        if (previousMusicVolume == -1) {
                            previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        }

                        // Temporarily boost volume to maximum for Azan
                        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "restoreVolume" -> {
                    try {
                        isSoundPlaying = false
                        abandonExclusiveAudioFocus()
                        restoreDeviceVolume()
                        resumePreviousMedia()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "scheduleNativePrayerAlarms" -> {
                    try {
                        val alarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        for (alarm in alarms) {
                            val id = (alarm["id"] as? Number)?.toInt() ?: continue
                            val timeMs = (alarm["timeMs"] as? Number)?.toLong() ?: continue
                            val name = alarm["name"] as? String ?: "Namaz"
                            val title = alarm["title"] as? String ?: "Time for $name Prayer"
                            val eventType = alarm["eventType"] as? String ?: "AZAN"
                            val soundType = alarm["soundType"] as? String ?: "ADHAN"

                            PersistedAlarmScheduler.schedule(this, id, timeMs, name, title, eventType, soundType)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_SCHEDULE_ERROR", e.message, null)
                    }
                }
                "scheduleNativeAlarm" -> {
                    try {
                        val id = (call.argument<Number>("id"))?.toInt() ?: 0
                        val timeMs = (call.argument<Number>("timeMs"))?.toLong() ?: 0L
                        val name = call.argument<String>("name") ?: "Alarm"
                        val title = call.argument<String>("title") ?: "Reminder"
                        val eventType = call.argument<String>("eventType") ?: "AZAN"
                        val soundType = call.argument<String>("soundType") ?: "ADHAN"

                        PersistedAlarmScheduler.schedule(this, id, timeMs, name, title, eventType, soundType)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelNativePrayerAlarms" -> {
                    try {
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        for (id in ids) {
                            PersistedAlarmScheduler.cancel(this, id)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_CANCEL_ERROR", e.message, null)
                    }
                }
                "isNativeAlarmRinging" -> {
                    result.success(PrayerAlarmService.isRinging)
                }
                "stopNativePrayerAlarm" -> {
                    PrayerAlarmService.stopAlarm(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createSystemAlarmChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    ?: Settings.System.DEFAULT_ALARM_ALERT_URI

                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()

                // Clean up older v4 channels
                try {
                    notificationManager.deleteNotificationChannel("namaz_prayer_channel_v4")
                    notificationManager.deleteNotificationChannel("quran_recitation_channel_v4")
                    notificationManager.deleteNotificationChannel("work_task_channel_v4")
                } catch (_: Exception) {}

                // 1. Quran Recitation Alarm Channel (Using Device's Default Clock Alarm)
                val quranChannel = NotificationChannel(
                    "quran_recitation_channel_v5",
                    "Quran Recitation Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Device clock alarm for scheduled Quran recitation"
                    setSound(alarmUri, audioAttributes)
                    enableVibration(true)
                    setBypassDnd(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }

                // 2. Work Task Alarm Channel (Using Device's Default Clock Alarm)
                val taskChannel = NotificationChannel(
                    "work_task_channel_v5",
                    "Work Task Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Device clock alarm for scheduled work tasks"
                    setSound(alarmUri, audioAttributes)
                    enableVibration(true)
                    setBypassDnd(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }

                // 3. Namaz Prayer Adhan Channel (Using Azan Voice)
                val resId = resources.getIdentifier("short_adhan", "raw", packageName)
                val adhanUri: Uri = if (resId != 0) {
                    Uri.parse("android.resource://$packageName/$resId")
                } else {
                    Uri.parse("android.resource://$packageName/raw/short_adhan")
                }

                val adhanAudioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()

                val namazChannel = NotificationChannel(
                    "namaz_prayer_channel_v5",
                    "Namaz Prayer Adhan Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Time-sensitive Adhan voice alarms for 5 daily prayer times"
                    setSound(adhanUri, adhanAudioAttributes)
                    enableVibration(true)
                    setBypassDnd(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }

                notificationManager.createNotificationChannel(namazChannel)
                notificationManager.createNotificationChannel(quranChannel)
                notificationManager.createNotificationChannel(taskChannel)
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to createSystemAlarmChannels: ${e.message}")
            }
        }
    }
}
