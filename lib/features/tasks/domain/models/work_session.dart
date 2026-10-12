class WorkSession {
  final String id;
  final String taskId;
  final DateTime startTimestamp;
  final DateTime? endTimestamp;
  final int activeDurationSeconds;
  final bool isPaused;
  final DateTime? lastPausedTimestamp;
  final String status; // IN_PROGRESS, COMPLETED, PAUSED

  const WorkSession({
    required this.id,
    required this.taskId,
    required this.startTimestamp,
    this.endTimestamp,
    this.activeDurationSeconds = 0,
    this.isPaused = false,
    this.lastPausedTimestamp,
    this.status = 'IN_PROGRESS',
  });

  int getEffectiveDurationSeconds() {
    if (status == 'COMPLETED') return activeDurationSeconds;
    if (isPaused) return activeDurationSeconds;
    final now = DateTime.now();
    final elapsedSinceLastStart = now.difference(lastPausedTimestamp ?? startTimestamp).inSeconds;
    return activeDurationSeconds + (elapsedSinceLastStart > 0 ? elapsedSinceLastStart : 0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'start_timestamp': startTimestamp.toIso8601String(),
      'end_timestamp': endTimestamp?.toIso8601String(),
      'active_duration_seconds': activeDurationSeconds,
      'is_paused': isPaused ? 1 : 0,
      'last_paused_timestamp': lastPausedTimestamp?.toIso8601String(),
      'status': status,
    };
  }

  factory WorkSession.fromMap(Map<String, dynamic> map) {
    return WorkSession(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      startTimestamp: DateTime.parse(map['start_timestamp'] as String),
      endTimestamp: map['end_timestamp'] != null
          ? DateTime.parse(map['end_timestamp'] as String)
          : null,
      activeDurationSeconds: map['active_duration_seconds'] as int,
      isPaused: (map['is_paused'] as int) == 1,
      lastPausedTimestamp: map['last_paused_timestamp'] != null
          ? DateTime.parse(map['last_paused_timestamp'] as String)
          : null,
      status: map['status'] as String,
    );
  }
}
