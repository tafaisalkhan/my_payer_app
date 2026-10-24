package com.mynamaz.scheduler

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.NotificationCompat

class PrayerAlarmService : Service() {

    companion object {
        const val CHANNEL_ID = "namaz_prayer_foreground_channel_v1"
        const val NOTIFICATION_ID = 9001
        var isRinging: Boolean = false
            private set

        fun stopAlarm(context: Context) {
            try {
                val stopIntent = Intent(context, PrayerAlarmService::class.java).apply {
                    action = PrayerAlarmReceiver.ACTION_STOP_ALARM
                }
                context.startService(stopIntent)
            } catch (e: Exception) {
                android.util.Log.e("PrayerAlarmService", "Failed to stopAlarm: ${e.message}")
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var previousAlarmVolume: Int = -1
    private var previousMusicVolume: Int = -1
    private var isCleanedUp: Boolean = false

    private var autoSilenceTimer: Handler? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PrayerAlarmReceiver.ACTION_STOP_ALARM) {
            stopSelfCleanly()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME) ?: "Reminder"
        val prayerTitle = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TITLE)
            ?: "Time for $prayerName"
        val eventType = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_EVENT_TYPE) ?: "AZAN"
        val soundType = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_SOUND_TYPE) ?: "ADHAN"

        startAlarm(prayerName, prayerTitle, eventType, soundType)
        return START_NOT_STICKY
    }

    private fun startAlarm(prayerName: String, prayerTitle: String, eventType: String, soundType: String) {
        if (isRinging) {
            return
        }
        isRinging = true
        isCleanedUp = false

        acquireWakeLock()
        createNotificationChannel()
        showForegroundNotification(prayerName, prayerTitle, eventType)
        requestExclusiveAudioFocus()
        boostDeviceVolume()
        playEventAudio(soundType)
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "MyNamaz:PrayerAlarmWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(600000L) // 10 minutes safety timeout for full Adhan
            }
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Namaz Prayer & Activity Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent high-priority alarms for scheduled Namaz, Quran, and Tasks"
                setBypassDnd(true) // Bypasses Do Not Disturb
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                setSound(null, null) // Handled with exclusive AudioFocus by MediaPlayer
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showForegroundNotification(prayerName: String, prayerTitle: String, eventType: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val launchPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmReceiver.ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            NOTIFICATION_ID,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val (notificationTitle, buttonText) = when (eventType) {
            "QURAN" -> Pair("📖 Quran Recitation: $prayerName", "🛑 STOP ALARM")
            "TASK" -> Pair("🚀 Work Task: $prayerName", "🛑 STOP ALARM")
            else -> Pair("🕌 Allahu Akbar! Time for $prayerName Prayer", "🛑 STOP AZAN")
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(notificationTitle)
            .setContentText(prayerTitle)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(launchPendingIntent)
            .setFullScreenIntent(launchPendingIntent, true)
            .addAction(android.R.drawable.ic_media_pause, buttonText, stopPendingIntent)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            android.util.Log.e("PrayerAlarmService", "Failed to startForeground: ${e.message}")
        }
    }

    private fun requestExclusiveAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // 1. Dispatch media pause key event to pause YouTube, Spotify, and other running media players immediately
        try {
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (_: Exception) {}

        // 2. Request exclusive Audio Focus on USAGE_ALARM so other app notifications do not pause or stop Azan
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false) // NEVER duck or pause for incoming notifications from other apps
                .setOnAudioFocusChangeListener { _ ->
                    // Do NOT stop Azan for other app notifications or transient focus losses.
                    // Azan must ONLY stop when the user explicitly stops it.
                }
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                { /* Do not stop for other app notifications */ },
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            )
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
            // Dispatch media play key event so previous media player (YouTube, Spotify, etc.) automatically resumes
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY))
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY))
        } catch (_: Exception) {}
    }

    private fun boostDeviceVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)

            if (previousAlarmVolume == -1) {
                previousAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            }
            if (previousMusicVolume == -1) {
                previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            }

            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
        } catch (_: Exception) {}
    }

    private fun restoreDeviceVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (previousAlarmVolume != -1) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previousAlarmVolume, 0)
                previousAlarmVolume = -1
            }
            if (previousMusicVolume != -1) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previousMusicVolume, 0)
                previousMusicVolume = -1
            }
        } catch (_: Exception) {}
    }

    private fun playEventAudio(soundType: String) {
        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            var player: MediaPlayer? = null
            val isAdhan = (soundType == "ADHAN")

            // 1. Try bundled raw resource
            try {
                val soundRes = if (isAdhan) {
                    val resId = resources.getIdentifier("short_adhan", "raw", packageName)
                    if (resId != 0) resId else R.raw.short_adhan
                } else {
                    val resId = resources.getIdentifier("alarm_clock", "raw", packageName)
                    if (resId != 0) resId else R.raw.alarm_clock
                }

                val afd = resources.openRawResourceFd(soundRes)
                if (afd != null) {
                    player = MediaPlayer().apply {
                        setAudioAttributes(audioAttributes)
                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                        afd.close()
                        prepare()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("PrayerAlarmService", "Error loading raw audio: ${e.message}")
            }

            // 2. Fallback to system default alarm/notification ringtone
            if (player == null) {
                try {
                    val alertUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    if (alertUri != null) {
                        player = MediaPlayer().apply {
                            setAudioAttributes(audioAttributes)
                            setDataSource(this@PrayerAlarmService, alertUri)
                            prepare()
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("PrayerAlarmService", "Error loading system alarm: ${e.message}")
                }
            }

            if (player == null) {
                android.util.Log.e("PrayerAlarmService", "Cannot initialize audio playback for soundType=$soundType")
                stopSelfCleanly()
                return
            }

            player.apply {
                isLooping = !isAdhan // Clock alarm loops until dismissed, Adhan plays once
                setVolume(1.0f, 1.0f)
                setOnCompletionListener {
                    if (!isLooping) {
                        stopSelfCleanly()
                    }
                }
                setOnErrorListener { _, what, extra ->
                    android.util.Log.e("PrayerAlarmService", "MediaPlayer error: what=$what, extra=$extra")
                    stopSelfCleanly()
                    true
                }
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                start()
            }
            mediaPlayer = player

            // Automatically silence clock alarm and resume previous app after 60 seconds if untouched
            if (!isAdhan) {
                autoSilenceTimer = Handler(Looper.getMainLooper()).apply {
                    postDelayed({
                        stopSelfCleanly()
                    }, 60000L)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("PrayerAlarmService", "Fatal error in playEventAudio: ${e.message}", e)
            stopSelfCleanly()
        }
    }

    private fun stopSelfCleanly() {
        if (isCleanedUp) return
        isCleanedUp = true
        isRinging = false

        try {
            autoSilenceTimer?.removeCallbacksAndMessages(null)
            autoSilenceTimer = null
        } catch (_: Exception) {}

        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null
        } catch (_: Exception) {}

        abandonExclusiveAudioFocus()
        restoreDeviceVolume()
        resumePreviousMedia() // Resumes previous app (e.g. YouTube, Spotify)

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            wakeLock = null
        } catch (_: Exception) {}

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopSelfCleanly()
        super.onDestroy()
    }
}
