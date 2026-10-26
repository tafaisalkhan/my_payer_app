import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynamaz_scheduler/core/utils/prayer_time_helper.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';

void main() {
  test('A selected future date remains the scheduled task date', () {
    final selected = DateTime(2027, 2, 12);
    final target = PrayerTimeHelper.calculateTargetTimeForDate(
      date: selected,
      isPrayerRelative: false,
      clockTime: const TimeOfDay(hour: 9, minute: 30),
      prayerName: 'Fajr',
      referencePoint: 'AZAN',
      offsetMinutes: 0,
      prayerTimings: const [],
    );

    expect(target, DateTime(2027, 2, 12, 9, 30));
    expect(target.subtract(const Duration(minutes: 10)),
        DateTime(2027, 2, 12, 9, 20));
  });

  test('Task keeps its chosen reminder when saved and loaded', () {
    final task = WorkTask(
      id: 'task-1',
      title: 'Prepare report',
      scheduledDate: '2027-02-12',
      startTime: '09:30',
      reminderMinutes: 15,
      createdAt: DateTime(2026, 10, 26),
    );

    final restored = WorkTask.fromMap(task.toMap());
    expect(restored.scheduledDate, '2027-02-12');
    expect(restored.reminderMinutes, 15);
  });
}
