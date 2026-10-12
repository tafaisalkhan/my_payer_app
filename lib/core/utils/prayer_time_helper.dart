import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';

class PrayerPeriodInfo {
  final String prayer; // 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  final String period; // 'Morning', 'Noon', 'Afternoon', 'Evening', 'Night'
  final String label; // 'Morning (Fajr)', etc.
  final String emoji; // '🌅', '☀️', etc.

  const PrayerPeriodInfo({
    required this.prayer,
    required this.period,
    required this.label,
    required this.emoji,
  });
}

class PrayerTimeHelper {
  static const List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static const List<PrayerPeriodInfo> prayerPeriods = [
    PrayerPeriodInfo(prayer: 'Fajr', period: 'Morning', label: 'Morning (Fajr)', emoji: '🌅'),
    PrayerPeriodInfo(prayer: 'Dhuhr', period: 'Noon', label: 'Noon / Midday (Dhuhr)', emoji: '☀️'),
    PrayerPeriodInfo(prayer: 'Asr', period: 'Afternoon', label: 'Afternoon (Asr)', emoji: '🌤️'),
    PrayerPeriodInfo(prayer: 'Maghrib', period: 'Evening', label: 'Evening (Maghrib)', emoji: '🌇'),
    PrayerPeriodInfo(prayer: 'Isha', period: 'Night', label: 'Night (Isha)', emoji: '🌙'),
  ];

  static String mapTextToPrayer(String text) {
    final t = text.toLowerCase();
    if (t.contains('afternoon') || t.contains('asr') || t.contains('sipahar')) return 'Asr';
    if (t.contains('morn') || t.contains('fajr') || t.contains('subah')) return 'Fajr';
    if (t.contains('noon') || t.contains('midday') || t.contains('dhuhr') || t.contains('zuhr') || t.contains('zohar')) return 'Dhuhr';
    if (t.contains('even') || t.contains('maghrib') || t.contains('sham')) return 'Maghrib';
    if (t.contains('night') || t.contains('isha') || t.contains('raat') || t.contains('bed')) return 'Isha';
    return 'Fajr';
  }

  static PrayerPeriodInfo getPeriodInfo(String prayerName) {
    return prayerPeriods.firstWhere(
      (p) => p.prayer.toLowerCase() == prayerName.toLowerCase(),
      orElse: () => const PrayerPeriodInfo(prayer: 'Fajr', period: 'Morning', label: 'Morning (Fajr)', emoji: '🌅'),
    );
  }

  /// Returns both Azan time and Namaz (congregation/Iqamah) time for the requested prayer
  static ({DateTime azanTime, DateTime namazTime}) getPrayerTimes({
    required String prayerName,
    required List<PrayerTiming> prayerTimings,
    PrayerCalculationSettings? settings,
  }) {
    final now = DateTime.now();
    PrayerTiming? timing;
    try {
      timing = prayerTimings.firstWhere(
        (t) => t.name.toLowerCase() == prayerName.toLowerCase(),
      );
    } catch (_) {}

    DateTime azan;
    if (timing != null) {
      azan = timing.time;
    } else {
      azan = switch (prayerName.toLowerCase()) {
        'fajr' => DateTime(now.year, now.month, now.day, 5, 0),
        'dhuhr' => DateTime(now.year, now.month, now.day, 12, 30),
        'asr' => DateTime(now.year, now.month, now.day, 16, 30),
        'maghrib' => DateTime(now.year, now.month, now.day, 18, 30),
        _ => DateTime(now.year, now.month, now.day, 20, 0), // isha
      };
    }

    // Default congregation/Iqamah delay after Azan
    int namazDelay = switch (prayerName.toLowerCase()) {
      'fajr' => 20,
      'dhuhr' => 20,
      'asr' => 15,
      'maghrib' => 10,
      'isha' => 15,
      _ => 15,
    };

    if (settings != null) {
      final customOffset = switch (prayerName.toLowerCase()) {
        'fajr' => settings.fajrOffset,
        'dhuhr' => settings.dhuhrOffset,
        'asr' => settings.asrOffset,
        'maghrib' => settings.maghribOffset,
        'isha' => settings.ishaOffset,
        _ => 0,
      };
      if (customOffset > 0) {
        namazDelay = customOffset;
      }
    }

    final namaz = azan.add(Duration(minutes: namazDelay));
    return (azanTime: azan, namazTime: namaz);
  }

  /// Calculates the target alarm DateTime based on either clock time or relative prayer offset
  static DateTime calculateTargetTime({
    required bool isPrayerRelative,
    required TimeOfDay clockTime,
    required String prayerName,
    required String referencePoint, // 'AZAN' or 'NAMAZ'
    required int offsetMinutes,
    required List<PrayerTiming> prayerTimings,
    PrayerCalculationSettings? settings,
  }) {
    final now = DateTime.now();

    if (!isPrayerRelative) {
      var t = DateTime(now.year, now.month, now.day, clockTime.hour, clockTime.minute);
      if (t.isBefore(now)) {
        t = t.add(const Duration(days: 1));
      }
      return t;
    }

    final times = getPrayerTimes(
      prayerName: prayerName,
      prayerTimings: prayerTimings,
      settings: settings,
    );

    final base = referencePoint.toUpperCase() == 'NAMAZ' ? times.namazTime : times.azanTime;
    var target = base.add(Duration(minutes: offsetMinutes));
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// Calculates the target alarm DateTime for a specific date (used for auto-scheduling)
  static DateTime calculateTargetTimeForDate({
    required DateTime date,
    required bool isPrayerRelative,
    required TimeOfDay clockTime,
    required String prayerName,
    required String referencePoint, // 'AZAN' or 'NAMAZ'
    required int offsetMinutes,
    required List<PrayerTiming> prayerTimings,
    PrayerCalculationSettings? settings,
  }) {
    if (!isPrayerRelative) {
      return DateTime(date.year, date.month, date.day, clockTime.hour, clockTime.minute);
    }

    final times = getPrayerTimes(
      prayerName: prayerName,
      prayerTimings: prayerTimings,
      settings: settings,
    );

    final base = referencePoint.toUpperCase() == 'NAMAZ' ? times.namazTime : times.azanTime;
    return DateTime(date.year, date.month, date.day, base.hour, base.minute)
        .add(Duration(minutes: offsetMinutes));
  }

  /// Formats the schedule time string for display and storage
  static String formatScheduleTimeString({
    required bool isPrayerRelative,
    required TimeOfDay clockTime,
    required String prayerName,
    required String referencePoint, // 'AZAN' or 'NAMAZ'
    required int offsetMinutes,
    required List<PrayerTiming> prayerTimings,
    PrayerCalculationSettings? settings,
  }) {
    if (!isPrayerRelative) {
      final hour = clockTime.hour.toString().padLeft(2, '0');
      final minute = clockTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final times = getPrayerTimes(
      prayerName: prayerName,
      prayerTimings: prayerTimings,
      settings: settings,
    );

    final base = referencePoint.toUpperCase() == 'NAMAZ' ? times.namazTime : times.azanTime;
    final target = base.add(Duration(minutes: offsetMinutes));
    final timeStr = DateFormat('hh:mm a').format(target);
    final periodInfo = getPeriodInfo(prayerName);

    if (referencePoint.toUpperCase() == 'NAMAZ') {
      return '$timeStr (${periodInfo.emoji} ${periodInfo.period} +$offsetMinutes min after $prayerName Namaz)';
    }
    return '$timeStr (${periodInfo.emoji} ${periodInfo.period} +$offsetMinutes min after $prayerName)';
  }

  /// Parses a saved schedule time string back into its original configuration for editing
  static ParsedScheduleTime parseScheduleTimeString(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) {
      return const ParsedScheduleTime(
        isPrayerRelative: false,
        clockTime: TimeOfDay(hour: 7, minute: 0),
        prayerName: 'Fajr',
        referencePoint: 'AZAN',
        offsetMinutes: 30,
      );
    }

    final s = timeStr.trim().toLowerCase();

    // Check for prayer relative or period-based string
    final hasPeriod = s.contains('after') ||
        s.contains('fajr') ||
        s.contains('dhuhr') ||
        s.contains('asr') ||
        s.contains('maghrib') ||
        s.contains('isha') ||
        s.contains('morning') ||
        s.contains('noon') ||
        s.contains('afternoon') ||
        s.contains('evening') ||
        s.contains('night');

    if (hasPeriod) {
      final prayer = mapTextToPrayer(s);
      final isNamaz = s.contains('namaz');
      int offset = 30;
      final match = RegExp(r'\+(\d+)\s*min').firstMatch(s);
      if (match != null) {
        offset = int.tryParse(match.group(1)!) ?? 30;
      }

      // Try to parse the time before the parenthesis if present
      TimeOfDay clock = const TimeOfDay(hour: 7, minute: 0);
      final parenIdx = timeStr.indexOf('(');
      final timePart = parenIdx > 0 ? timeStr.substring(0, parenIdx).trim() : timeStr;
      final parsedClock = _parseClockString(timePart);
      if (parsedClock != null) {
        clock = parsedClock;
      }

      return ParsedScheduleTime(
        isPrayerRelative: true,
        clockTime: clock,
        prayerName: prayer,
        referencePoint: isNamaz ? 'NAMAZ' : 'AZAN',
        offsetMinutes: offset,
      );
    }

    // Exact clock time: "07:00", "14:30", "07:00 AM", "02:30 PM"
    final parsedClock = _parseClockString(timeStr);
    return ParsedScheduleTime(
      isPrayerRelative: false,
      clockTime: parsedClock ?? const TimeOfDay(hour: 7, minute: 0),
      prayerName: 'Fajr',
      referencePoint: 'AZAN',
      offsetMinutes: 30,
    );
  }

  static TimeOfDay? _parseClockString(String s) {
    try {
      if (s.toLowerCase().contains('am') || s.toLowerCase().contains('pm')) {
        final dt = DateFormat('hh:mm a').parse(s.trim());
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      final parts = s.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0].trim());
        final m = int.tryParse(parts[1].trim());
        if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    } catch (_) {}
    return null;
  }
}

class ParsedScheduleTime {
  final bool isPrayerRelative;
  final TimeOfDay clockTime;
  final String prayerName;
  final String referencePoint; // 'AZAN' or 'NAMAZ'
  final int offsetMinutes;

  const ParsedScheduleTime({
    required this.isPrayerRelative,
    required this.clockTime,
    required this.prayerName,
    required this.referencePoint,
    required this.offsetMinutes,
  });
}
