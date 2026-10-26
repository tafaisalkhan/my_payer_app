enum TaskPriority { high, medium, low }
enum TaskStatus { pending, inProgress, completed }

class WorkTask {
  final String id;
  final String title;
  final String? description;
  final String scheduledDate; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String? endTime;
  final int durationMinutes;
  final int reminderMinutes;
  final String frequency; // One-Time, Daily, Weekly, Monthly
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;

  const WorkTask({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledDate,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 45,
    this.reminderMinutes = 10,
    this.frequency = 'One-Time',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduled_date': scheduledDate,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'reminder_minutes': reminderMinutes,
      'priority': priority.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WorkTask.fromMap(Map<String, dynamic> map) {
    TaskPriority p = TaskPriority.medium;
    if (map['priority'] == 'HIGH') p = TaskPriority.high;
    if (map['priority'] == 'LOW') p = TaskPriority.low;

    TaskStatus s = TaskStatus.pending;
    if (map['status'] == 'IN_PROGRESS') s = TaskStatus.inProgress;
    if (map['status'] == 'COMPLETED') s = TaskStatus.completed;

    return WorkTask(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      scheduledDate: map['scheduled_date'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String?,
      durationMinutes: map['duration_minutes'] as int? ?? 45,
      reminderMinutes: map['reminder_minutes'] as int? ?? 10,
      frequency: 'One-Time',
      priority: p,
      status: s,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
