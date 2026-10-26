import 'package:adhan/adhan.dart';
import 'package:mynamaz_scheduler/core/database/app_database.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/voluntary_prayer_timing.dart';
import 'package:sqflite/sqflite.dart';

class PrayerCalculationSettings {
  final String method; // KARACHI, MWL, ISNA, EGYPT, MAKKAH, TEHRAN, JAFARI, GULF, MOONSIGHTING
  final String madhab; // HANAFI, SHAFI
  final int fajrOffset;
  final int dhuhrOffset;
  final int asrOffset;
  final int maghribOffset;
  final int ishaOffset;

  const PrayerCalculationSettings({
    this.method = 'KARACHI',
    this.madhab = 'HANAFI',
    this.fajrOffset = 0,
    this.dhuhrOffset = 0,
    this.asrOffset = 0,
    this.maghribOffset = 0,
    this.ishaOffset = 0,
  });
}

class PrayerRepository {
  /// Suggested voluntary prayer times. These are display only and never enter
  /// the five-prayer adhan alarm list.
  List<VoluntaryPrayerTiming> calculateVoluntaryPrayerTimings({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationSettings settings,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final params = _getAdhanMethodParameters(settings.method);
    params.madhab = settings.madhab.toUpperCase() == 'HANAFI'
        ? Madhab.hanafi
        : Madhab.shafi;

    PrayerTimes forDate(DateTime day) =>
        PrayerTimes(coordinates, DateComponents.from(day), params);

    final today = forDate(date);
    final yesterday = forDate(DateTime(date.year, date.month, date.day - 1));
    final sunrise = today.sunrise;
    final dhuhr = today.dhuhr.add(Duration(minutes: settings.dhuhrOffset));
    final maghrib = today.maghrib.add(Duration(minutes: settings.maghribOffset));
    final fajr = today.fajr.add(Duration(minutes: settings.fajrOffset));
    final previousMaghrib = yesterday.maghrib.add(Duration(minutes: settings.maghribOffset));
    final night = fajr.difference(previousMaghrib);

    return [
      VoluntaryPrayerTiming(
        name: 'Tahajjud',
        time: fajr.subtract(Duration(microseconds: night.inMicroseconds ~/ 3)),
        description: 'Last third of the night, before Fajr',
      ),
      VoluntaryPrayerTiming(
        name: 'Ishraq',
        time: sunrise.add(const Duration(minutes: 20)),
        description: 'About 20 minutes after sunrise',
      ),
      VoluntaryPrayerTiming(
        name: 'Chasht (Duha)',
        time: sunrise.add(Duration(microseconds:
            dhuhr.difference(sunrise).inMicroseconds ~/ 2)),
        description: 'Midmorning, before Dhuhr',
      ),
      VoluntaryPrayerTiming(
        name: 'Awwabin',
        time: maghrib.add(const Duration(minutes: 15)),
        description: 'After Maghrib prayer',
      ),
    ];
  }

  CalculationParameters _getAdhanMethodParameters(String methodStr) {
    switch (methodStr.toUpperCase()) {
      case 'MWL':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'ISNA':
        return CalculationMethod.north_america.getParameters();
      case 'EGYPT':
        return CalculationMethod.egyptian.getParameters();
      case 'MAKKAH':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'TEHRAN':
        return CalculationMethod.tehran.getParameters();
      case 'DUBAI':
        return CalculationMethod.dubai.getParameters();
      case 'QATAR':
        return CalculationMethod.qatar.getParameters();
      case 'KUWAIT':
        return CalculationMethod.kuwait.getParameters();
      case 'SINGAPORE':
        return CalculationMethod.singapore.getParameters();
      case 'JAFARI':
      case 'KARACHI':
      default:
        return CalculationMethod.karachi.getParameters();
    }
  }

  List<PrayerTiming> calculatePrayerTimings({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationSettings settings,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final dateComponents = DateComponents.from(date);
    final params = _getAdhanMethodParameters(settings.method);

    if (settings.madhab.toUpperCase() == 'HANAFI') {
      params.madhab = Madhab.hanafi;
    } else {
      params.madhab = Madhab.shafi;
    }

    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

    final fajr = prayerTimes.fajr.add(Duration(minutes: settings.fajrOffset));
    final dhuhr = prayerTimes.dhuhr.add(Duration(minutes: settings.dhuhrOffset));
    final asr = prayerTimes.asr.add(Duration(minutes: settings.asrOffset));
    final maghrib = prayerTimes.maghrib.add(Duration(minutes: settings.maghribOffset));
    final isha = prayerTimes.isha.add(Duration(minutes: settings.ishaOffset));

    final now = DateTime.now();

    final timings = [
      PrayerTiming(type: PrayerType.fajr, name: 'Fajr', time: fajr),
      PrayerTiming(type: PrayerType.dhuhr, name: 'Dhuhr', time: dhuhr),
      PrayerTiming(type: PrayerType.asr, name: 'Asr', time: asr),
      PrayerTiming(type: PrayerType.maghrib, name: 'Maghrib', time: maghrib),
      PrayerTiming(type: PrayerType.isha, name: 'Isha', time: isha),
    ];

    // Determine current & next prayer
    int currentIdx = -1;
    int nextIdx = -1;

    for (int i = 0; i < timings.length; i++) {
      if (now.isBefore(timings[i].time)) {
        nextIdx = i;
        currentIdx = i - 1;
        break;
      }
    }

    DateTime? tomorrowFajrTime;
    if (nextIdx == -1) {
      currentIdx = 4; // Isha
      nextIdx = 0; // Fajr next day
      try {
        final tomorrow = date.add(const Duration(days: 1));
        final tomorrowComponents = DateComponents.from(tomorrow);
        final tomorrowPrayerTimes = PrayerTimes(coordinates, tomorrowComponents, params);
        tomorrowFajrTime = tomorrowPrayerTimes.fajr.add(Duration(minutes: settings.fajrOffset));
      } catch (_) {
        tomorrowFajrTime = fajr.add(const Duration(days: 1));
      }
    }

    return List.generate(timings.length, (i) {
      final t = timings[i];
      final isCurrent = i == currentIdx;
      final isNext = i == nextIdx;
      Duration? remaining;

      if (isNext) {
        if (t.time.isBefore(now) && tomorrowFajrTime != null) {
          remaining = tomorrowFajrTime.difference(now);
        } else {
          remaining = t.time.difference(now);
        }
        if (remaining.isNegative) {
          remaining = Duration.zero;
        }
      }

      return t.copyWith(
        isCurrent: isCurrent,
        isNext: isNext,
        timeRemaining: remaining,
      );
    });
  }

  /// Returns the actual next upcoming prayer, calculating tomorrow's Fajr if all prayers today have passed.
  PrayerTiming getNextPrayer({
    required double latitude,
    required double longitude,
    required PrayerCalculationSettings settings,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final todayTimings = calculatePrayerTimings(
      latitude: latitude,
      longitude: longitude,
      date: currentTime,
      settings: settings,
    );

    for (final t in todayTimings) {
      if (t.time.isAfter(currentTime)) {
        return t.copyWith(
          isNext: true,
          timeRemaining: t.time.difference(currentTime),
        );
      }
    }

    // All prayers for today have passed: next prayer is Tomorrow's Fajr
    final tomorrow = currentTime.add(const Duration(days: 1));
    final tomorrowTimings = calculatePrayerTimings(
      latitude: latitude,
      longitude: longitude,
      date: tomorrow,
      settings: settings,
    );
    final tomorrowFajr = tomorrowTimings.first;
    return tomorrowFajr.copyWith(
      isNext: true,
      timeRemaining: tomorrowFajr.time.difference(currentTime),
    );
  }

  // Database Persistence Operations
  Future<List<PrayerRecord>> getPrayerRecordsForDate(String dateIso) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'prayer_records',
      where: 'date = ?',
      whereArgs: [dateIso],
    );

    return maps.map((m) => PrayerRecord.fromMap(m)).toList();
  }

  Future<void> savePrayerRecord(PrayerRecord record) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'prayer_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PrayerRecord>> getAllPrayerRecords() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('prayer_records', orderBy: 'date DESC');
    return maps.map((m) => PrayerRecord.fromMap(m)).toList();
  }
}
