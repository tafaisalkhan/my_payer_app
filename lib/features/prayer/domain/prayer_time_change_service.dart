import 'package:flutter/foundation.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimeChangeService {
  const PrayerTimeChangeService._();

  static String formatMinutes(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Saves today's calculated times and returns previous times that changed.
  static Future<Map<String, int>> check(List<PrayerTiming> timings) async {
    final prefs = await SharedPreferences.getInstance();
    final changes = <String, int>{};
    for (var index = 0; index < timings.length; index++) {
      final timing = timings[index];
      final key = 'last_prayer_time_${timing.name.toLowerCase()}';
      final nowMinutes = timing.time.hour * 60 + timing.time.minute;
      final previous = prefs.getInt(key);
      if (previous != null && previous != nowMinutes) {
        changes[timing.name] = previous;
        try {
          await NotificationService.instance.showPrayerTimeChanged(
            id: 70000 + index,
            prayer: timing.name,
            oldTime: formatMinutes(previous),
            newTime: formatMinutes(nowMinutes),
          );
        } catch (error) {
          debugPrint('Could not notify prayer time change: $error');
        }
      }
      await prefs.setInt(key, nowMinutes);
    }
    return changes;
  }
}
