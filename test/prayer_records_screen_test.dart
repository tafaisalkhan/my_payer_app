import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/core/location/location_service.dart';
import 'package:mynamaz_scheduler/features/prayer/data/repositories/prayer_repository.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_record.dart';
import 'package:mynamaz_scheduler/features/prayer/domain/models/prayer_timing.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:mynamaz_scheduler/features/prayer/presentation/screens/prayer_records_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository extends PrayerRepository {
  final records = <PrayerRecord>[];

  @override
  Future<List<PrayerRecord>> getAllPrayerRecords() async => records;

  @override
  Future<List<PrayerRecord>> getPrayerRecordsForDate(String dateIso) async =>
      records.where((record) => record.date == dateIso).toList();

  @override
  Future<void> savePrayerRecord(PrayerRecord record) async {
    records.removeWhere((existing) => existing.id == record.id);
    records.add(record);
  }

  @override
  List<PrayerTiming> calculatePrayerTimings({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationSettings settings,
  }) =>
      [
        for (final prayer in PrayerType.values)
          PrayerTiming(
            type: prayer,
            name: '${prayer.name[0].toUpperCase()}${prayer.name.substring(1)}',
            time: DateTime(date.year, date.month, date.day),
          ),
      ];
}

void main() {
  testWidgets('year report starts at the installation month', (tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date':
          DateTime(today.year, today.month, today.day).toIso8601String(),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWithValue(_FakeRepository()),
        locationDataProvider.overrideWith((ref) async => const LocationData(
              latitude: 24.8,
              longitude: 67.0,
              city: 'Karachi',
              country: 'Pakistan',
            )),
      ],
      child: const MaterialApp(
          home: PrayerRecordsScreen(initialView: PrayerRecordsView.year)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('January ${today.year}'),
        today.month == 1 ? findsOneWidget : findsNothing);
    expect(find.text(DateFormat('MMMM y').format(today)), findsOneWidget);
    expect(find.byTooltip('Previous'), findsOneWidget);
    final previous = tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip('Previous'),
      matching: find.byType(IconButton),
    ));
    expect(previous.onPressed, isNull);
  });

  testWidgets('year calendar opens a day with all five prayer times',
      (tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date':
          DateTime(today.year, 1, 1).toIso8601String(),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWithValue(_FakeRepository()),
        locationDataProvider.overrideWith((ref) async => const LocationData(
              latitude: 24.8,
              longitude: 67.0,
              city: 'Karachi',
              country: 'Pakistan',
            )),
      ],
      child: const MaterialApp(
          home: PrayerRecordsScreen(initialView: PrayerRecordsView.year)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('January ${today.year}'), findsOneWidget);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Fajr ·'), findsOneWidget);
    expect(find.textContaining('Dhuhr ·'), findsOneWidget);
    expect(find.textContaining('Asr ·'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Maghrib ·'), 150,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Maghrib ·'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Isha ·'), 150,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Isha ·'), findsOneWidget);
  });

  testWidgets('tapping Takbir-e-Ula saves an on-time mosque check-in',
      (tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date':
          DateTime(today.year, today.month, today.day).toIso8601String(),
    });
    final repository = _FakeRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWithValue(repository),
        locationDataProvider.overrideWith((ref) async => const LocationData(
              latitude: 24.8,
              longitude: 67.0,
              city: 'Karachi',
              country: 'Pakistan',
            )),
      ],
      child: const MaterialApp(home: PrayerRecordsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('5 prayers awaiting check-in'), findsOneWidget);
    await tester.tap(find.text('Check in').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On Time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mosque').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();

    expect(repository.records, hasLength(1));
    final record = repository.records.single;
    expect(record.date, DateFormat('yyyy-MM-dd').format(today));
    expect(record.status, PrayerStatus.onTime);
    expect(record.place, PrayerPlace.mosque);
    expect(record.takbirEUla, isTrue);
    expect(record.joinedRakats, isNull);
    expect(find.text('4 prayers awaiting check-in'), findsOneWidget);
  });

  testWidgets('No Takbir requires a missed-rakat choice', (tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'prayer_tracking_install_date':
          DateTime(today.year, today.month, today.day).toIso8601String(),
    });
    final repository = _FakeRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWithValue(repository),
        locationDataProvider.overrideWith((ref) async => const LocationData(
              latitude: 24.8,
              longitude: 67.0,
              city: 'Karachi',
              country: 'Pakistan',
            )),
      ],
      child: const MaterialApp(home: PrayerRecordsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check in').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On Time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mosque').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Rakats missed'), findsNothing);
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    expect(find.text('Rakats missed (of 4)'), findsOneWidget);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose how many rakats you missed.'), findsOneWidget);
    expect(repository.records, isEmpty);
    await tester.tap(find.byType(DropdownButton<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(repository.records.single.takbirEUla, isFalse);
    expect(repository.records.single.joinedRakats, 3);
  });
}
