import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const MethodChannel _volumeChannel = MethodChannel('com.mynamaz.scheduler/volume');

  final ValueNotifier<bool> isAdhanPlayingNotifier = ValueNotifier<bool>(false);
  bool get isAdhanPlaying => isAdhanPlayingNotifier.value;

  bool _isInitialized = false;

  NotificationService._init() {
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'stopSound') {
        await stopAdhanPreview();
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;
      if (isAdhanPlayingNotifier.value != playing) {
        isAdhanPlayingNotifier.value = playing;
        if (!playing) {
          restoreVolume();
          _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': false}).catchError((_) {});
        }
      }
    });
  }

  Future<void> boostVolume() async {
    try {
      await _volumeChannel.invokeMethod('boostVolume');
    } catch (_) {}
  }

  Future<void> restoreVolume() async {
    try {
      await _volumeChannel.invokeMethod('restoreVolume');
    } catch (_) {}
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click action
      },
    );

    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.namazChannelId,
            AppConstants.namazChannelName,
            description: 'Time-sensitive notifications for 5 daily prayer times',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound('short_adhan'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

        final alarmUri = await getSystemAlarmUri();
        final alarmSound = (alarmUri != null && alarmUri.isNotEmpty)
            ? UriAndroidNotificationSound(alarmUri)
            : null;

        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            AppConstants.quranChannelId,
            AppConstants.quranChannelName,
            description: 'Scheduled Quran recitation reminders and alarms',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: alarmSound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            AppConstants.taskChannelId,
            AppConstants.taskChannelName,
            description: 'Scheduled work task activity reminders and alarms',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: alarmSound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
    }

    _isInitialized = true;
  }

  String? _systemAlarmUri;

  Future<String?> getSystemAlarmUri() async {
    if (_systemAlarmUri != null) return _systemAlarmUri;
    try {
      _systemAlarmUri = await _volumeChannel.invokeMethod<String>('getSystemAlarmUri');
    } catch (_) {}
    return _systemAlarmUri;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notif = await androidImplementation?.requestNotificationsPermission() ?? false;
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (_) {}
      return notif;
    } else if (Platform.isIOS) {
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
    bool enableSound = true,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    if (Platform.isAndroid) {
      String eventType = 'AZAN';
      String soundType = 'ADHAN';
      if (channelId == AppConstants.quranChannelId) {
        eventType = 'QURAN';
        soundType = 'ALARM';
      } else if (channelId == AppConstants.taskChannelId) {
        eventType = 'TASK';
        soundType = 'ALARM';
      }

      // Single dedicated native alarm service:
      // Stops YouTube/other apps, plays ONE sound, displays ONE notification, resumes previous app on finish
      await scheduleNativeAlarm(
        id: id,
        scheduledDate: scheduledDate,
        name: title,
        title: body,
        eventType: eventType,
        soundType: soundType,
      );
      return;
    }

    final tz.TZDateTime tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleNativeAlarm({
    required int id,
    required DateTime scheduledDate,
    required String name,
    required String title,
    required String eventType,
    required String soundType,
  }) async {
    if (!Platform.isAndroid) return;
    if (scheduledDate.isBefore(DateTime.now())) return;
    try {
      await _volumeChannel.invokeMethod('scheduleNativeAlarm', {
        'id': id,
        'timeMs': scheduledDate.millisecondsSinceEpoch,
        'name': name,
        'title': title,
        'eventType': eventType,
        'soundType': soundType,
      });
    } catch (_) {}
  }

  Timer? _adhan5SecTimer;

  Future<void> playPrayerAdhan() async {
    try {
      _adhan5SecTimer?.cancel();
      await _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': true});
      await boostVolume(); // Increase volume to max for Azan & request exclusive audio focus
      await _audioPlayer.setAsset('assets/audio/short_adhan.mp3');
      await _audioPlayer.setVolume(1.0);
      isAdhanPlayingNotifier.value = true;
      await _audioPlayer.play();
    } catch (_) {
      isAdhanPlayingNotifier.value = false;
      await restoreVolume();
      try {
        await _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': false});
      } catch (_) {}
    }
  }

  Future<void> playAdhanPreview() async {
    try {
      _adhan5SecTimer?.cancel();
      await _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': true});
      await boostVolume(); // Increase volume for Azan & request exclusive audio focus
      await _audioPlayer.setAsset('assets/audio/short_adhan.mp3');
      await _audioPlayer.setVolume(1.0);
      isAdhanPlayingNotifier.value = true;
      await _audioPlayer.play();

      // Automatically silence Azan and restore volume after 15 seconds for preview
      _adhan5SecTimer = Timer(const Duration(seconds: 15), () {
        if (isAdhanPlaying) {
          stopAdhanPreview();
        }
      });
    } catch (_) {
      isAdhanPlayingNotifier.value = false;
      await restoreVolume();
      try {
        await _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': false});
      } catch (_) {}
    }
  }

  Future<void> stopAdhanPreview() async {
    _adhan5SecTimer?.cancel();
    _adhan5SecTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    isAdhanPlayingNotifier.value = false;
    await restoreVolume(); // Restore volume back to pre-Azan level & abandon audio focus
    try {
      await _volumeChannel.invokeMethod('setSoundPlaying', {'isPlaying': false});
    } catch (_) {}
    await stopNativePrayerAlarm();
  }

  Future<void> scheduleNativePrayerAlarms(List<Map<String, dynamic>> alarms) async {
    if (!Platform.isAndroid) return;
    try {
      await _volumeChannel.invokeMethod('scheduleNativePrayerAlarms', {'alarms': alarms});
    } catch (_) {}
  }

  Future<void> cancelNativePrayerAlarms(List<int> ids) async {
    if (!Platform.isAndroid) return;
    try {
      await _volumeChannel.invokeMethod('cancelNativePrayerAlarms', {'ids': ids});
    } catch (_) {}
  }

  Future<bool> isAlarmRinging() async {
    if (!Platform.isAndroid) return isAdhanPlaying;
    try {
      final res = await _volumeChannel.invokeMethod<bool>('isNativeAlarmRinging');
      return (res ?? false) || isAdhanPlaying;
    } catch (_) {
      return isAdhanPlaying;
    }
  }

  Future<void> stopNativePrayerAlarm() async {
    if (!Platform.isAndroid) return;
    try {
      await _volumeChannel.invokeMethod('stopNativePrayerAlarm');
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    await cancelNativePrayerAlarms([id]);
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
