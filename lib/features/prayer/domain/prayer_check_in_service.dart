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
  static const _channel = MethodChannel('com.mynamaz.scheduler/volume');

  static Future<DateTime> _installDate(SharedPreferences prefs) async {
    final saved = prefs.getString(_installKey);
    if (saved != null) return DateTime.parse(saved);
    DateTime installed = DateTime.now();
    try {
      final milliseconds =
          await _channel.invokeMethod<int>('getFirstInstallTime');
      if (milliseconds != null) {
        installed = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    } catch (_) {}
    final day = DateTime(installed.year, installed.month, installed.day);
    await prefs.setString(_installKey, day.toIso8601String());
    return day;
  }

  static Future<DateTime> installDate() async =>
      _installDate(await SharedPreferences.getInstance());

  static Future<List<PendingPrayerCheckIn>> load({
    required PrayerRepository repository,
    required double latitude,
    required double longitude,
    required PrayerCalculationSettings settings,
    DateTime? now,
  }) async {
    final installed = await installDate();
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final records = await repository.getAllPrayerRecords();
    final marked = <String>{
      for (final record in records)
        if (record.status != PrayerStatus.pending)
          '${record.date}_${record.prayerName.toUpperCase()}',
    };
    final pending = <PendingPrayerCheckIn>[];
    for (var day = DateTime(installed.year, installed.month, installed.day);
        !day.isAfter(today);
        day = DateTime(day.year, day.month, day.day + 1)) {
      final dateIso = DateFormat('yyyy-MM-dd').format(day);
      final timings = repository.calculatePrayerTimings(
        latitude: latitude,
        longitude: longitude,
        date: day,
        settings: settings,
      );
      for (final timing in timings) {
        if (timing.time.isAfter(current)) {
          continue;
        }
        if (marked.contains('${dateIso}_${timing.name.toUpperCase()}')) {
          continue;
        }
        pending.add(PendingPrayerCheckIn(dateIso, timing.name, timing.time));
      }
    }
    return pending;
  }
}
