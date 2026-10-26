import 'package:mynamaz_scheduler/core/constants/app_constants.dart';
import 'package:mynamaz_scheduler/core/notifications/notification_service.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';

class TaskAlarmScheduler {
  const TaskAlarmScheduler._();

  static int _baseId(String taskId) {
    var hash = 2166136261;
    for (final unit in taskId.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return 800000000 + (hash % 100000000) * 3;
  }

  static Future<void> cancel(String taskId) async {
    final base = _baseId(taskId);
    for (var slot = 0; slot < 3; slot++) {
      await NotificationService.instance.cancelNotification(base + slot);
    }
  }

  static Future<void> schedule(WorkTask task, DateTime start) async {
    await cancel(task.id);
    if (task.status == TaskStatus.completed) return;

    final base = _baseId(task.id);
    final reminder = start.subtract(Duration(minutes: task.reminderMinutes));
    final details = task.description?.trim();
    final body = details == null || details.isEmpty
        ? 'Your task "${task.title}" starts in ${task.reminderMinutes} minutes.'
        : 'In ${task.reminderMinutes} minutes: $details';

    await NotificationService.instance.scheduleNotification(
      id: base,
      title: 'Task reminder: ${task.title}',
      body: body,
      scheduledDate: reminder,
      channelId: AppConstants.taskChannelId,
      channelName: AppConstants.taskChannelName,
    );
    await NotificationService.instance.scheduleNotification(
      id: base + 1,
      title: 'Task starts: ${task.title}',
      body: details == null || details.isEmpty ? 'Time to begin your task.' : details,
      scheduledDate: start,
      channelId: AppConstants.taskChannelId,
      channelName: AppConstants.taskChannelName,
    );
    await NotificationService.instance.scheduleNotification(
      id: base + 2,
      title: 'Task time is up: ${task.title}',
      body: 'Your ${task.durationMinutes}-minute task period has ended.',
      scheduledDate: start.add(Duration(minutes: task.durationMinutes)),
      channelId: AppConstants.taskChannelId,
      channelName: AppConstants.taskChannelName,
    );
  }
}
