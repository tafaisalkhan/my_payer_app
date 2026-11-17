import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingPrayerCheckIn {
  final String dateIso;
  final String prayer;
  final DateTime time;

  const PendingPrayerCheckIn(this.dateIso, this.prayer, this.time);
}

class PrayerCheckInService {
  static const _installKey = 'prayer_tracking_install_date';
  static const _installDateTimeKey = 'prayer_tracking_install_datetime';
  static const _channel = MethodChannel('com.mynamaz.scheduler/volume');

  static Future<DateTime> installDateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDt = prefs.getString(_installDateTimeKey);
    if (savedDt != null) return DateTime.parse(savedDt);

    DateTime installed = DateTime.now();
    try {
      final milliseconds =
          await _channel.invokeMethod<int>('getFirstInstallTime');
      if (milliseconds != null) {
        installed = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    } catch (_) {}

    final savedDay = prefs.getString(_installKey);
    if (savedDay != null) {
      final parsedDay = DateTime.parse(savedDay);
      if (installed.year != parsedDay.year ||
          installed.month != parsedDay.month ||
          installed.day != parsedDay.day) {
        installed = parsedDay;
      }
    }

    final day = DateTime(installed.year, installed.month, installed.day);
    await prefs.setString(_installKey, day.toIso8601String());
    await prefs.setString(_installDateTimeKey, installed.toIso8601String());
    return installed;
  }

  static Future<DateTime> installDate() async {
    final dt = await installDateTime();
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Counts prayers on the install day starting from [installTime] onward.
  /// E.g. if installed at Isha (last prayer), returns 1 instead of 5.
  static int installDayPrayerCount({
    required PrayerRepository repository,
    required double latitude,
    required double longitude,
    required PrayerCalculationSettings settings,
    required DateTime installTime,
  }) {
    final installDay =
        DateTime(installTime.year, installTime.month, installTime.day);
    final timings = repository.calculatePrayerTimings(
      latitude: latitude,
      longitude: longitude,
      date: installDay,
      settings: settings,
    );
    var count = 0;
    for (var i = 0; i < timings.length; i++) {
      final nextTime = i + 1 < timings.length ? timings[i + 1].time : null;
      if (nextTime == null || installTime.isBefore(nextTime)) {
        count++;
      }
    }
    return count > 0 ? count : 1;
  }

  /// Loads only today's pending prayers (from install time onward on install day),
  /// so users are never forced to backfill previous days.
  static Future<List<PendingPrayerCheckIn>> load({
    required PrayerRepository repository,
    required double latitude,
    required double longitude,
    required PrayerCalculationSettings settings,
    DateTime? now,
  }) async {
    final installedAt = await installDateTime();
    final installedDay =
        DateTime(installedAt.year, installedAt.month, installedAt.day);
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    if (today.isBefore(installedDay)) return const [];

    final records = await repository.getPrayerRecordsForDate(
      DateFormat('yyyy-MM-dd').format(today),
    );
    final marked = <String>{
      for (final record in records)
        if (record.status != PrayerStatus.pending)
          '${record.date}_${record.prayerName.toUpperCase()}',
    };

    final dateIso = DateFormat('yyyy-MM-dd').format(today);
    final timings = repository.calculatePrayerTimings(
      latitude: latitude,
      longitude: longitude,
      date: today,
      settings: settings,
    );

    final isInstallDay = today.isAtSameMomentAs(installedDay);
    final pending = <PendingPrayerCheckIn>[];
    for (var i = 0; i < timings.length; i++) {
      final timing = timings[i];
      if (timing.time.isAfter(current)) {
        continue;
      }
      if (isInstallDay) {
        final nextTime = i + 1 < timings.length ? timings[i + 1].time : null;
        if (nextTime != null && !installedAt.isBefore(nextTime)) {
          continue;
        }
      }
      if (marked.contains('${dateIso}_${timing.name.toUpperCase()}')) {
        continue;
      }
      pending.add(PendingPrayerCheckIn(dateIso, timing.name, timing.time));
    }
    return pending;
  }
}
