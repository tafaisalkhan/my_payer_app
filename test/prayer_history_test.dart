import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HistoryRepository extends PrayerRepository {
  final List<PrayerRecord> records;
  _HistoryRepository(this.records);

  @override
  Future<List<PrayerRecord>> getAllPrayerRecords() async => records;

  @override
  Future<List<PrayerRecord>> getPrayerRecordsForDate(String dateIso) async =>
      records.where((record) => record.date == dateIso).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('history counts on-time mosque and Takbir as nested progress', () async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final old = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 40)));
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date': '${old}T00:00:00.000',
    });
    PrayerRecord record(String id, String prayer, PrayerStatus status,
            {PrayerPlace? place, bool takbir = false, String? date}) =>
        PrayerRecord(
          id: id,
          date: date ?? today,
          prayerName: prayer,
          status: status,
          place: place,
          takbirEUla: takbir,
          updatedAt: DateTime.now(),
        );

    final container = ProviderContainer(overrides: [
      prayerRepositoryProvider.overrideWithValue(_HistoryRepository([
        record('1', 'Fajr', PrayerStatus.onTime,
            place: PrayerPlace.mosque, takbir: true),
        record('2', 'Fajr', PrayerStatus.onTime, place: PrayerPlace.home),
        record('3', 'Fajr', PrayerStatus.qada,
            place: PrayerPlace.mosque, takbir: true),
        record('4', 'Dhuhr', PrayerStatus.onTime, place: PrayerPlace.mosque),
        record('5', 'Asr', PrayerStatus.onTime,
            place: PrayerPlace.mosque, takbir: true, date: old),
      ]))
    ]);
    addTearDown(container.dispose);

    final recent = await container.read(prayerHistoryProvider.future);
    expect(recent['Fajr']!.onTime, 2);
    expect(recent['Fajr']!.mosqueOnTime, 1);
    expect(recent['Fajr']!.takbirOnTime, 1);
    expect(recent['Dhuhr']!.mosqueOnTime, 1);
    expect(recent['Dhuhr']!.takbirOnTime, 0);
    expect(recent['Asr']!.onTime, 0);

    container.read(prayerHistoryPeriodProvider.notifier).state = 0;
    final allTime = await container.read(prayerHistoryProvider.future);
    expect(allTime['Asr']!.takbirOnTime, 1);
  });

  test('progress and history begin on the install date', () async {
    final today = DateTime.now();
    final todayIso = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayIso = DateFormat('yyyy-MM-dd')
        .format(today.subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date':
          DateTime(today.year, today.month, today.day).toIso8601String(),
    });
    final repository = _HistoryRepository([
      for (final date in [yesterdayIso, todayIso])
        PrayerRecord(
          id: '${date}_FAJR',
          date: date,
          prayerName: 'Fajr',
          status: PrayerStatus.onTime,
          takbirEUla: false,
          updatedAt: today,
        ),
    ]);
    final container = ProviderContainer(overrides: [
      prayerRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    await container.read(todayPrayerRecordsProvider.notifier).loadTodayRecords();
    final progress = await container.read(namazProgressStatsProvider.future);
    for (final period in [
      progress.daily,
      progress.weekly,
      progress.monthly,
      progress.yearly,
    ]) {
      expect(period.total, 5);
    }
    expect(progress.weekly.completed, 1);
    expect(progress.monthly.completed, 1);
    expect(progress.yearly.completed, 1);
    container.read(prayerHistoryPeriodProvider.notifier).state = 0;
    final history = await container.read(prayerHistoryProvider.future);
    expect(history['Fajr']!.onTime, 1);
  });
}
