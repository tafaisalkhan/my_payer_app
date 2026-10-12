import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_session.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';

double calculateQiblaBearing(double userLat, double userLng) {
  double lat1 = userLat * (math.pi / 180.0);
  double lng1 = userLng * (math.pi / 180.0);
  double lat2 = AppConstants.kaabaLatitude * (math.pi / 180.0);
  double lng2 = AppConstants.kaabaLongitude * (math.pi / 180.0);

  double dLng = lng2 - lng1;

  double y = math.sin(dLng) * math.cos(lat2);
  double x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

  double bearing = math.atan2(y, x);
  bearing = bearing * (180.0 / math.pi);
  return (bearing + 360.0) % 360.0;
}

void main() {
  group('Qibla Bearing Calculation Tests', () {
    test('Calculates Qibla direction from Karachi accurately', () {
      // From Karachi (24.8607, 67.0011), Qibla is approx ~260-265 degrees
      final bearing = calculateQiblaBearing(24.8607, 67.0011);
      expect(bearing, greaterThan(255.0));
      expect(bearing, lessThan(270.0));
    });

    test('Calculates Qibla direction from London accurately', () {
      // From London (51.5074, -0.1278), Qibla is approx ~118-122 degrees
      final bearing = calculateQiblaBearing(51.5074, -0.1278);
      expect(bearing, greaterThan(115.0));
      expect(bearing, lessThan(125.0));
    });
  });

  group('Work Session & Work Task Tests', () {
    test('WorkSession active duration calculates correctly from persisted timestamps', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(minutes: 30));

      final session = WorkSession(
        id: 'session_1',
        taskId: 'task_1',
        startTimestamp: startTime,
        activeDurationSeconds: 600, // 10 mins elapsed before pause
        isPaused: true,
        lastPausedTimestamp: now.subtract(const Duration(minutes: 5)),
        status: 'PAUSED',
      );

      final totalDuration = session.getEffectiveDurationSeconds();
      expect(totalDuration, equals(600));
    });

    test('WorkTask converts to and from Map', () {
      final task = WorkTask(
        id: 'task_100',
        title: 'Complete Islamic Report',
        description: 'Prepare monthly summary',
        scheduledDate: '2026-10-09',
        startTime: '09:00 AM',
        endTime: '05:00 PM',
        priority: TaskPriority.high,
        status: TaskStatus.completed,
        createdAt: DateTime.now(),
      );

      final map = task.toMap();
      expect(map['id'], equals('task_100'));
      expect(map['priority'], equals('HIGH'));
      expect(map['status'], equals('COMPLETED'));

      final restored = WorkTask.fromMap(map);
      expect(restored.title, equals('Complete Islamic Report'));
      expect(restored.priority, equals(TaskPriority.high));
      expect(restored.status, equals(TaskStatus.completed));
    });
  });
}
