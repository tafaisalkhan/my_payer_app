import 'package:flutter_test/flutter_test.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/prayer_check_in_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePrayerRepository extends PrayerRepository {
  final List<PrayerRecord> records;
  _FakePrayerRepository(this.records);

  @override
  Future<List<PrayerRecord>> getAllPrayerRecords() async => records;

  @override
  List<PrayerTiming> calculatePrayerTimings({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationSettings settings,
  }) =>
      [
        PrayerTiming(
            type: PrayerType.fajr,
            name: 'Fajr',
            time: DateTime(date.year, date.month, date.day, 5)),
        PrayerTiming(
            type: PrayerType.dhuhr,
            name: 'Dhuhr',
            time: DateTime(date.year, date.month, date.day, 12)),
        PrayerTiming(
            type: PrayerType.asr,
            name: 'Asr',
            time: DateTime(date.year, date.month, date.day, 16)),
        PrayerTiming(
            type: PrayerType.maghrib,
            name: 'Maghrib',
            time: DateTime(date.year, date.month, date.day, 18)),
        PrayerTiming(
            type: PrayerType.isha,
            name: 'Isha',
            time: DateTime(date.year, date.month, date.day, 20)),
      ];
}

void main() {
  test(
      'catch-up includes unmarked prayers since install, but no future prayers',
      () async {
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date': '2026-11-01T00:00:00.000',
    });
    final records = [
      PrayerRecord(
        id: '2026-11-01_FAJR',
        date: '2026-11-01',
        prayerName: 'Fajr',
        status: PrayerStatus.onTime,
        takbirEUla: false,
        updatedAt: DateTime(2026, 11, 1, 5),
      ),
    ];
    final pending = await PrayerCheckInService.load(
      repository: _FakePrayerRepository(records),
      latitude: 24,
      longitude: 67,
      settings: const PrayerCalculationSettings(),
      now: DateTime(2026, 11, 3, 16, 30),
    );
    expect(pending.length, 12); // 4 + 5 + 3 due today.
    expect(pending.first.prayer, 'Dhuhr');
    expect(pending.last.prayer, 'Asr');
    expect(pending.last.dateIso, '2026-11-03');
  });
}
