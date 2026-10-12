import 'package:flutter_test/flutter_test.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';

void main() {
  group('Prayer Calculation Tests', () {
    final repository = PrayerRepository();

    test('Calculates 5 prayer timings for Karachi coordinates', () {
      final date = DateTime(2026, 10, 9);
      final timings = repository.calculatePrayerTimings(
        latitude: 24.8607,
        longitude: 67.0011,
        date: date,
        settings: const PrayerCalculationSettings(method: 'KARACHI', madhab: 'HANAFI'),
      );

      expect(timings.length, equals(5));
      expect(timings[0].name, equals('Fajr'));
      expect(timings[1].name, equals('Dhuhr'));
      expect(timings[2].name, equals('Asr'));
      expect(timings[3].name, equals('Maghrib'));
      expect(timings[4].name, equals('Isha'));

      // Fajr should be before Dhuhr, Dhuhr before Asr, etc.
      expect(timings[0].time.isBefore(timings[1].time), isTrue);
      expect(timings[1].time.isBefore(timings[2].time), isTrue);
      expect(timings[2].time.isBefore(timings[3].time), isTrue);
      expect(timings[3].time.isBefore(timings[4].time), isTrue);
    });

    test('Hanafi Asr prayer time is later than Shafi Asr prayer time', () {
      final date = DateTime(2026, 10, 9);
      final hanafiTimings = repository.calculatePrayerTimings(
        latitude: 24.8607,
        longitude: 67.0011,
        date: date,
        settings: const PrayerCalculationSettings(method: 'KARACHI', madhab: 'HANAFI'),
      );

      final shafiTimings = repository.calculatePrayerTimings(
        latitude: 24.8607,
        longitude: 67.0011,
        date: date,
        settings: const PrayerCalculationSettings(method: 'KARACHI', madhab: 'SHAFI'),
      );

      final hanafiAsr = hanafiTimings.firstWhere((t) => t.name == 'Asr').time;
      final shafiAsr = shafiTimings.firstWhere((t) => t.name == 'Asr').time;

      expect(hanafiAsr.isAfter(shafiAsr), isTrue);
    });

    test('Prayer offsets shift prayer timing accurately', () {
      final date = DateTime(2026, 10, 9);
      final baseTimings = repository.calculatePrayerTimings(
        latitude: 24.8607,
        longitude: 67.0011,
        date: date,
        settings: const PrayerCalculationSettings(fajrOffset: 0),
      );

      final offsetTimings = repository.calculatePrayerTimings(
        latitude: 24.8607,
        longitude: 67.0011,
        date: date,
        settings: const PrayerCalculationSettings(fajrOffset: 15),
      );

      final baseFajr = baseTimings.firstWhere((t) => t.name == 'Fajr').time;
      final offsetFajr = offsetTimings.firstWhere((t) => t.name == 'Fajr').time;

      expect(offsetFajr.difference(baseFajr).inMinutes, equals(15));
    });

    test('When Isha prayer has passed at night, getNextPrayer returns tomorrow Fajr with positive countdown', () {
      final repository = PrayerRepository();
      // Suppose today is 2026-10-09 at 23:00 (11 PM - well after Isha)
      final nightTime = DateTime(2026, 10, 9, 23, 0);

      final nextPrayer = repository.getNextPrayer(
        latitude: 24.8607,
        longitude: 67.0011,
        settings: const PrayerCalculationSettings(method: 'KARACHI', madhab: 'HANAFI'),
        now: nightTime,
      );

      expect(nextPrayer.name, equals('Fajr'));
      expect(nextPrayer.isNext, isTrue);
      // Next Fajr must be on tomorrow's date (2026-10-10)
      expect(nextPrayer.time.day, equals(10));
      expect(nextPrayer.time.isAfter(nightTime), isTrue);

      // Remaining countdown must be strictly positive (e.g. ~6 hours), never 0 or negative
      expect(nextPrayer.timeRemaining, isNotNull);
      expect(nextPrayer.timeRemaining!.isNegative, isFalse);
      expect(nextPrayer.timeRemaining!.inMinutes, greaterThan(60));
    });
  });

  group('Prayer Record Model Tests', () {
    test('PrayerRecord correctly converts to and from Map', () {
      final now = DateTime.now();
      final record = PrayerRecord(
        id: '2026-10-09_FAJR',
        date: '2026-10-09',
        prayerName: 'Fajr',
        status: PrayerStatus.onTime,
        takbirEUla: true,
        updatedAt: now,
      );

      final map = record.toMap();
      expect(map['id'], equals('2026-10-09_FAJR'));
      expect(map['status'], equals('ONTIME'));
      expect(map['takbir_e_ula'], equals(1));

      final restored = PrayerRecord.fromMap(map);
      expect(restored.prayerName, equals('Fajr'));
      expect(restored.status, equals(PrayerStatus.onTime));
      expect(restored.takbirEUla, isTrue);
    });
  });
}
