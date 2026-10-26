import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/core/location/location_service.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/core/utils/prayer_time_helper.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/voluntary_prayer_timing.dart';
import 'package:mynamaz_scheduler/features/quran/data/repositories/quran_repository.dart';
import 'package:mynamaz_scheduler/features/tasks/data/repositories/task_repository.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/task_alarm_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final prayerRepositoryProvider = Provider<PrayerRepository>((ref) => PrayerRepository());
bool _legacyPrayerAlarmsCleared = false;

final locationDataProvider = FutureProvider<LocationData>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentOrSavedLocation();
});

final prayerSettingsProvider = StateNotifierProvider<PrayerSettingsNotifier, PrayerCalculationSettings>((ref) {
  return PrayerSettingsNotifier();
});

class PrayerSettingsNotifier extends StateNotifier<PrayerCalculationSettings> {
  late final Future<void> _ready;

  PrayerSettingsNotifier() : super(const PrayerCalculationSettings()) {
    _ready = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString('pref_calc_method') ?? 'KARACHI';
    final madhab = prefs.getString('pref_madhab') ?? 'HANAFI';
    final fajr = prefs.getInt('pref_offset_fajr') ?? 0;
    final dhuhr = prefs.getInt('pref_offset_dhuhr') ?? 0;
    final asr = prefs.getInt('pref_offset_asr') ?? 0;
    final maghrib = prefs.getInt('pref_offset_maghrib') ?? 0;
    final isha = prefs.getInt('pref_offset_isha') ?? 0;

    state = PrayerCalculationSettings(
      method: method,
      madhab: madhab,
      fajrOffset: fajr,
      dhuhrOffset: dhuhr,
      asrOffset: asr,
      maghribOffset: maghrib,
      ishaOffset: isha,
    );
  }

  Future<void> updateMethod(String newMethod) async {
    await _ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_calc_method', newMethod);
    state = PrayerCalculationSettings(
      method: newMethod,
      madhab: state.madhab,
      fajrOffset: state.fajrOffset,
      dhuhrOffset: state.dhuhrOffset,
      asrOffset: state.asrOffset,
      maghribOffset: state.maghribOffset,
      ishaOffset: state.ishaOffset,
    );
  }

  Future<void> updateMadhab(String newMadhab) async {
    await _ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_madhab', newMadhab);
    state = PrayerCalculationSettings(
      method: state.method,
      madhab: newMadhab,
      fajrOffset: state.fajrOffset,
      dhuhrOffset: state.dhuhrOffset,
      asrOffset: state.asrOffset,
      maghribOffset: state.maghribOffset,
      ishaOffset: state.ishaOffset,
    );
  }

  Future<void> updateOffsets({
    int? fajr,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
  }) async {
    await _ready;
    final prefs = await SharedPreferences.getInstance();
    if (fajr != null) await prefs.setInt('pref_offset_fajr', fajr);
    if (dhuhr != null) await prefs.setInt('pref_offset_dhuhr', dhuhr);
    if (asr != null) await prefs.setInt('pref_offset_asr', asr);
    if (maghrib != null) await prefs.setInt('pref_offset_maghrib', maghrib);
    if (isha != null) await prefs.setInt('pref_offset_isha', isha);

    state = PrayerCalculationSettings(
      method: state.method,
      madhab: state.madhab,
      fajrOffset: fajr ?? state.fajrOffset,
      dhuhrOffset: dhuhr ?? state.dhuhrOffset,
      asrOffset: asr ?? state.asrOffset,
      maghribOffset: maghrib ?? state.maghribOffset,
      ishaOffset: isha ?? state.ishaOffset,
    );
  }
}

final prayerTimingsProvider = Provider<List<PrayerTiming>>((ref) {
  final locationAsync = ref.watch(locationDataProvider);
  final settings = ref.watch(prayerSettingsProvider);
  final repo = ref.watch(prayerRepositoryProvider);

  final location = locationAsync.valueOrNull;
  if (location == null) return [];

  if (!_legacyPrayerAlarmsCleared) {
    _legacyPrayerAlarmsCleared = true;
    NotificationService.instance.cancelNativePrayerAlarms(
      List.generate(70, (index) => 1000 + index),
    );
  }

  final now = DateTime.now();
  final timings = repo.calculatePrayerTimings(
    latitude: location.latitude,
    longitude: location.longitude,
    date: now,
    settings: settings,
  );

  // Auto-schedule exact alarms for the next 7 days (both native high-priority alarm service and local notifications)
  final List<Map<String, dynamic>> nativeAlarms = [];
  final List<int> expiredAlarmIds = [];

  for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
    final targetDate = now.add(Duration(days: dayOffset));
    final dayTimings = repo.calculatePrayerTimings(
      latitude: location.latitude,
      longitude: location.longitude,
      date: targetDate,
      settings: settings,
    );

    for (int i = 0; i < dayTimings.length; i++) {
      final t = dayTimings[i];
      final alarmId =
          (targetDate.year * 10000 + targetDate.month * 100 + targetDate.day) * 10 + i;
      if (t.time.isAfter(now)) {
        // Android AlarmManager high-priority alarm (wakes phone, halts background apps, boosts volume)
        nativeAlarms.add({
          'id': alarmId,
          'timeMs': t.time.millisecondsSinceEpoch,
          'name': t.name,
          'title': 'Time for ${t.name} Prayer in ${location.city}',
          'eventType': 'AZAN',
          'soundType': 'ADHAN',
        });
      } else {
        expiredAlarmIds.add(alarmId);
      }
    }
  }

  if (nativeAlarms.isNotEmpty) {
    NotificationService.instance.scheduleNativePrayerAlarms(nativeAlarms);
  }
  if (expiredAlarmIds.isNotEmpty) {
    NotificationService.instance.cancelNativePrayerAlarms(expiredAlarmIds);
  }

  // Auto-schedule prayer-dependent Quran schedules for the next 7 days
  try {
    final quranRepo = QuranRepository();
    quranRepo.getActiveSchedules().then((schedules) {
      for (final sch in schedules) {
        final parsed = PrayerTimeHelper.parseScheduleTimeString(sch.recitationTime);
        if (!parsed.isPrayerRelative) continue;

        for (int d = 0; d < 7; d++) {
          final scheduleDate = now.add(Duration(days: d));
          final dayTimings = repo.calculatePrayerTimings(
            latitude: location.latitude,
            longitude: location.longitude,
            date: scheduleDate,
            settings: settings,
          );
          final targetTime = PrayerTimeHelper.calculateTargetTimeForDate(
            date: scheduleDate,
            isPrayerRelative: true,
            clockTime: parsed.clockTime,
            prayerName: parsed.prayerName,
            referencePoint: parsed.referencePoint,
            offsetMinutes: parsed.offsetMinutes,
            prayerTimings: dayTimings,
            settings: settings,
          );

          if (targetTime.isAfter(now)) {
            final quranAlarmId = 200000 + (sch.id.hashCode.abs() % 10000) * 10 + d;
            final periodInfo = PrayerTimeHelper.getPeriodInfo(parsed.prayerName);
            NotificationService.instance.scheduleNativeAlarm(
              id: quranAlarmId,
              scheduledDate: targetTime,
              name: '📖 Quran Recitation: ${sch.displayTitle}',
              title: '${periodInfo.emoji} ${periodInfo.label}: Time for ${sch.durationMinutes}-minute Quran recitation.',
              eventType: 'QURAN',
              soundType: 'ADHAN',
            );
          }
        }
      }
    }).catchError((_) {});
  } catch (_) {}

  // Refresh saved task alarms if prayer settings or location changed.
  TaskRepository().getPendingTasks().then((tasks) async {
    for (final task in tasks) {
      if (task.status == TaskStatus.inProgress) continue;
      final taskDate = DateTime.tryParse(task.scheduledDate);
      if (taskDate == null) continue;
      final parsed = PrayerTimeHelper.parseScheduleTimeString(task.startTime);
      final dayTimings = repo.calculatePrayerTimings(
        latitude: location.latitude,
        longitude: location.longitude,
        date: taskDate,
        settings: settings,
      );
      final start = PrayerTimeHelper.calculateTargetTimeForDate(
        date: taskDate,
        isPrayerRelative: parsed.isPrayerRelative,
        clockTime: parsed.clockTime,
        prayerName: parsed.prayerName,
        referencePoint: parsed.referencePoint,
        offsetMinutes: parsed.offsetMinutes,
        prayerTimings: dayTimings,
        settings: settings,
      );
      await TaskAlarmScheduler.schedule(task, start);
    }
  }).catchError((_) {});

  return timings;
});

final voluntaryPrayerTimingsProvider = Provider<List<VoluntaryPrayerTiming>>((ref) {
  final location = ref.watch(locationDataProvider).valueOrNull;
  if (location == null) return [];
  return ref.watch(prayerRepositoryProvider).calculateVoluntaryPrayerTimings(
    latitude: location.latitude,
    longitude: location.longitude,
    date: DateTime.now(),
    settings: ref.watch(prayerSettingsProvider),
  );
});

final nextPrayerProvider = Provider<PrayerTiming?>((ref) {
  final locationAsync = ref.watch(locationDataProvider);
  final settings = ref.watch(prayerSettingsProvider);
  final repo = ref.watch(prayerRepositoryProvider);

  final location = locationAsync.valueOrNull;
  if (location == null) return null;

  return repo.getNextPrayer(
    latitude: location.latitude,
    longitude: location.longitude,
    settings: settings,
  );
});

final todayPrayerRecordsProvider = StateNotifierProvider<TodayPrayerRecordsNotifier, Map<String, PrayerRecord>>((ref) {
  final repo = ref.watch(prayerRepositoryProvider);
  return TodayPrayerRecordsNotifier(repo, ref);
});

class TodayPrayerRecordsNotifier extends StateNotifier<Map<String, PrayerRecord>> {
  final PrayerRepository _repo;
  final Ref _ref;
  final String _todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

  TodayPrayerRecordsNotifier(this._repo, this._ref) : super({}) {
    loadTodayRecords();
  }

  Future<void> loadTodayRecords() async {
    final records = await _repo.getPrayerRecordsForDate(_todayIso);
    final Map<String, PrayerRecord> map = {};
    for (var r in records) {
      map[r.prayerName.toUpperCase()] = r;
    }
    state = map;
  }

  Future<void> updateRecord({
    required String prayerName,
    required PrayerStatus status,
    required bool takbirEUla,
  }) async {
    final pKey = prayerName.toUpperCase();
    final existing = state[pKey];

    final record = PrayerRecord(
      id: existing?.id ?? '${_todayIso}_$pKey',
      date: _todayIso,
      prayerName: prayerName,
      status: status,
      takbirEUla: takbirEUla,
      updatedAt: DateTime.now(),
    );

    await _repo.savePrayerRecord(record);
    state = {...state, pKey: record};
    _ref.invalidate(namazProgressStatsProvider);
  }
}

class PeriodProgress {
  final int completed;
  final int total;
  final int onTimeCount;
  final int qadaCount;
  final int missedCount;

  const PeriodProgress({
    required this.completed,
    required this.total,
    required this.onTimeCount,
    required this.qadaCount,
    required this.missedCount,
  });

  double get percentage => total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
}

class NamazProgressStats {
  final PeriodProgress daily;
  final PeriodProgress weekly;
  final PeriodProgress monthly;
  final PeriodProgress yearly;

  const NamazProgressStats({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
  });
}

final namazProgressStatsProvider = FutureProvider<NamazProgressStats>((ref) async {
  final repo = ref.watch(prayerRepositoryProvider);
  final todayMap = ref.watch(todayPrayerRecordsProvider);
  final allRecords = await repo.getAllPrayerRecords();

  final now = DateTime.now();
  final todayIso = DateFormat('yyyy-MM-dd').format(now);
  final weekAgoIso = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
  final monthAgoIso = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));
  final yearStartIso = DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));

  int dailyCompleted = 0, dailyOnTime = 0, dailyQada = 0, dailyMissed = 0;
  for (var r in todayMap.values) {
    if (r.status == PrayerStatus.onTime) {
      dailyCompleted++;
      dailyOnTime++;
    } else if (r.status == PrayerStatus.qada) {
      dailyCompleted++;
      dailyQada++;
    } else if (r.status == PrayerStatus.notPrayed) {
      dailyMissed++;
    }
  }

  int weeklyCompleted = 0, weeklyOnTime = 0, weeklyQada = 0, weeklyMissed = 0;
  int monthlyCompleted = 0, monthlyOnTime = 0, monthlyQada = 0, monthlyMissed = 0;
  int yearlyCompleted = 0, yearlyOnTime = 0, yearlyQada = 0, yearlyMissed = 0;

  for (var r in allRecords) {
    final isDone = r.status == PrayerStatus.onTime || r.status == PrayerStatus.qada;
    if (r.date.compareTo(weekAgoIso) >= 0 && r.date.compareTo(todayIso) <= 0) {
      if (isDone) weeklyCompleted++;
      if (r.status == PrayerStatus.onTime) weeklyOnTime++;
      if (r.status == PrayerStatus.qada) weeklyQada++;
      if (r.status == PrayerStatus.notPrayed) weeklyMissed++;
    }

    if (r.date.compareTo(monthAgoIso) >= 0 && r.date.compareTo(todayIso) <= 0) {
      if (isDone) monthlyCompleted++;
      if (r.status == PrayerStatus.onTime) monthlyOnTime++;
      if (r.status == PrayerStatus.qada) monthlyQada++;
      if (r.status == PrayerStatus.notPrayed) monthlyMissed++;
    }

    if (r.date.compareTo(yearStartIso) >= 0 && r.date.compareTo(todayIso) <= 0) {
      if (isDone) yearlyCompleted++;
      if (r.status == PrayerStatus.onTime) yearlyOnTime++;
      if (r.status == PrayerStatus.qada) yearlyQada++;
      if (r.status == PrayerStatus.notPrayed) yearlyMissed++;
    }
  }

  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  final yearlyTotal = dayOfYear * 5;

  return NamazProgressStats(
    daily: PeriodProgress(
      completed: dailyCompleted,
      total: 5,
      onTimeCount: dailyOnTime,
      qadaCount: dailyQada,
      missedCount: dailyMissed,
    ),
    weekly: PeriodProgress(
      completed: weeklyCompleted,
      total: 35,
      onTimeCount: weeklyOnTime,
      qadaCount: weeklyQada,
      missedCount: weeklyMissed,
    ),
    monthly: PeriodProgress(
      completed: monthlyCompleted,
      total: 150,
      onTimeCount: monthlyOnTime,
      qadaCount: monthlyQada,
      missedCount: monthlyMissed,
    ),
    yearly: PeriodProgress(
      completed: yearlyCompleted,
      total: yearlyTotal,
      onTimeCount: yearlyOnTime,
      qadaCount: yearlyQada,
      missedCount: yearlyMissed,
    ),
  );
});
