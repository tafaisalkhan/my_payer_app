import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/core/utils/prayer_time_helper.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_schedule.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_history.dart';

void main() {
  group('Quran Schedule and Part Selection Tests', () {
    test('AppConstants contains all 114 Surahs and 30 Parts', () {
      expect(AppConstants.surahs.length, equals(114));
      expect(AppConstants.quranParts.length, equals(30));

      expect(AppConstants.surahs.first['name'], equals('Al-Fatihah'));
      expect(AppConstants.surahs.last['name'], equals('An-Nas'));

      expect(AppConstants.quranParts.first['name'], equals('Para 1: آلم'));
      expect(AppConstants.quranParts.last['name'], equals('Para 30: عَمَّ يَتَسَاءَلُونَ'));
    });

    test('QuranSchedule correctly formats Surah displayTitle with Ayah range', () {
      final sch = QuranSchedule(
        id: '1',
        frequency: 'Every Day',
        recitationTime: '07:00',
        surahId: 2,
        surahName: 'Al-Baqarah',
        startAyah: 1,
        endAyah: 20,
        selectionType: 'SURAH',
        createdAt: DateTime(2026, 10, 11),
      );

      expect(sch.isPartSchedule, isFalse);
      expect(sch.displayTitle, equals('Al-Baqarah (Ayah 1-20)'));
    });

    test('QuranSchedule correctly formats Part displayTitle without Ayah range', () {
      final sch = QuranSchedule(
        id: '2',
        frequency: 'Every 2 Days',
        recitationTime: '08:30',
        surahId: 0,
        surahName: 'Part 1 (Juz 1)',
        startAyah: 0,
        endAyah: 0,
        juz: 1,
        selectionType: 'PART',
        createdAt: DateTime(2026, 10, 11),
      );

      expect(sch.isPartSchedule, isTrue);
      expect(sch.displayTitle, equals('Part 1 (Juz 1)'));
    });

    test('QuranHistory displayTitle handles Part vs Surah correctly', () {
      final historySurah = QuranHistory(
        id: '1',
        scheduleId: '100',
        date: '2026-10-11',
        surahName: 'Al-Kahf',
        startAyah: 1,
        endAyah: 10,
        status: 'COMPLETED',
        completedAt: DateTime.now(),
      );

      final historyPart = QuranHistory(
        id: '2',
        scheduleId: '101',
        date: '2026-10-11',
        surahName: 'Part 30 (Juz 30)',
        startAyah: 0,
        endAyah: 0,
        status: 'COMPLETED',
        completedAt: DateTime.now(),
      );

      expect(historySurah.displayTitle, equals('Al-Kahf (1-10)'));
      expect(historyPart.displayTitle, equals('Part 30 (Juz 30)'));
    });

    test('PrayerTimeHelper accurately formats and calculates 45 to 150 minutes after Azan and Namaz', () {
      final now = DateTime.now();
      final timings = [
        PrayerTiming(type: PrayerType.fajr, name: 'Fajr', time: DateTime(now.year, now.month, now.day, 5, 15)),
        PrayerTiming(type: PrayerType.dhuhr, name: 'Dhuhr', time: DateTime(now.year, now.month, now.day, 12, 30)),
      ];

      // 1. Azan + 45 minutes
      final formatted45 = PrayerTimeHelper.formatScheduleTimeString(
        isPrayerRelative: true,
        clockTime: const TimeOfDay(hour: 7, minute: 0),
        prayerName: 'Fajr',
        referencePoint: 'AZAN',
        offsetMinutes: 45,
        prayerTimings: timings,
      );
      expect(formatted45, contains('06:00'));
      expect(formatted45, contains('+45 min after Fajr'));

      // 2. Namaz + 150 minutes
      final formatted150 = PrayerTimeHelper.formatScheduleTimeString(
        isPrayerRelative: true,
        clockTime: const TimeOfDay(hour: 7, minute: 0),
        prayerName: 'Fajr',
        referencePoint: 'NAMAZ',
        offsetMinutes: 150,
        prayerTimings: timings,
      );
      expect(formatted150, contains('+150 min after Fajr Namaz'));

      // 3. Fixed clock time formatting
      final fixedStr = PrayerTimeHelper.formatScheduleTimeString(
        isPrayerRelative: false,
        clockTime: const TimeOfDay(hour: 8, minute: 15),
        prayerName: 'Fajr',
        referencePoint: 'AZAN',
        offsetMinutes: 45,
        prayerTimings: timings,
      );
      expect(fixedStr, equals('08:15'));
    });

    test('PrayerTimeHelper.parseScheduleTimeString parses relative and clock times for editing', () {
      // 1. Relative with minutes after prayer
      final parsed1 = PrayerTimeHelper.parseScheduleTimeString('06:00 AM (+45 min after Fajr)');
      expect(parsed1.isPrayerRelative, isTrue);
      expect(parsed1.prayerName, equals('Fajr'));
      expect(parsed1.offsetMinutes, equals(45));
      expect(parsed1.referencePoint, equals('AZAN'));

      // 2. Relative with Namaz reference
      final parsed2 = PrayerTimeHelper.parseScheduleTimeString('07:30 AM (+90 min after Maghrib Namaz)');
      expect(parsed2.isPrayerRelative, isTrue);
      expect(parsed2.prayerName, equals('Maghrib'));
      expect(parsed2.offsetMinutes, equals(90));
      expect(parsed2.referencePoint, equals('NAMAZ'));

      // 3. Exact clock time
      final parsed3 = PrayerTimeHelper.parseScheduleTimeString('14:45');
      expect(parsed3.isPrayerRelative, isFalse);
      expect(parsed3.clockTime.hour, equals(14));
      expect(parsed3.clockTime.minute, equals(45));
    });

    test('QuranSchedule preserves durationMinutes in toMap and fromMap', () {
      final sch = QuranSchedule(
        id: '123',
        frequency: 'Daily',
        recitationTime: '06:00 AM (+45 min after Fajr)',
        durationMinutes: 75,
        surahId: 1,
        surahName: 'Al-Fatihah',
        startAyah: 1,
        endAyah: 7,
        createdAt: DateTime(2026, 10, 11),
      );

      final map = sch.toMap();
      expect(map['duration_minutes'], equals(75));

      final fromMap = QuranSchedule.fromMap(map);
      expect(fromMap.durationMinutes, equals(75));
      expect(fromMap.recitationTime, equals('06:00 AM (+45 min after Fajr)'));
    });

    test('Prayer periods (Morning, Noon, Afternoon, Evening, Night) automatically map to prayers', () {
      expect(PrayerTimeHelper.mapTextToPrayer('Morning (Fajr)'), equals('Fajr'));
      expect(PrayerTimeHelper.mapTextToPrayer('🌅 Morning'), equals('Fajr'));
      expect(PrayerTimeHelper.mapTextToPrayer('☀️ Noon'), equals('Dhuhr'));
      expect(PrayerTimeHelper.mapTextToPrayer('Midday'), equals('Dhuhr'));
      expect(PrayerTimeHelper.mapTextToPrayer('🌤️ Afternoon'), equals('Asr'));
      expect(PrayerTimeHelper.mapTextToPrayer('🌇 Evening'), equals('Maghrib'));
      expect(PrayerTimeHelper.mapTextToPrayer('🌙 Night'), equals('Isha'));

      // Check parseScheduleTimeString parses period strings
      final parsedMorning = PrayerTimeHelper.parseScheduleTimeString('05:45 AM (🌅 Morning +30 min after Fajr)');
      expect(parsedMorning.isPrayerRelative, isTrue);
      expect(parsedMorning.prayerName, equals('Fajr'));
      expect(parsedMorning.offsetMinutes, equals(30));

      final parsedEvening = PrayerTimeHelper.parseScheduleTimeString('06:45 PM (🌇 Evening +15 min after Maghrib)');
      expect(parsedEvening.isPrayerRelative, isTrue);
      expect(parsedEvening.prayerName, equals('Maghrib'));
      expect(parsedEvening.offsetMinutes, equals(15));
    });

    test('PrayerTimeHelper.calculateTargetTimeForDate accurately calculates target across future dates', () {
      final baseDate = DateTime(2026, 10, 15);
      final timings = [
        PrayerTiming(type: PrayerType.fajr, name: 'Fajr', time: DateTime(2026, 10, 15, 5, 20)),
        PrayerTiming(type: PrayerType.maghrib, name: 'Maghrib', time: DateTime(2026, 10, 15, 18, 10)),
      ];

      final morningTarget = PrayerTimeHelper.calculateTargetTimeForDate(
        date: baseDate,
        isPrayerRelative: true,
        clockTime: const TimeOfDay(hour: 7, minute: 0),
        prayerName: 'Fajr',
        referencePoint: 'AZAN',
        offsetMinutes: 30,
        prayerTimings: timings,
      );
      expect(morningTarget.year, equals(2026));
      expect(morningTarget.month, equals(10));
      expect(morningTarget.day, equals(15));
      expect(morningTarget.hour, equals(5));
      expect(morningTarget.minute, equals(50));
    });
  });
}
