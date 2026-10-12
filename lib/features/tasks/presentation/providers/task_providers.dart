import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynamaz_scheduler/features/tasks/data/repositories/task_repository.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) => TaskRepository());

final todayTasksProvider = StateNotifierProvider<TodayTasksNotifier, List<WorkTask>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TodayTasksNotifier(repo);
});

class TodayTasksNotifier extends StateNotifier<List<WorkTask>> {
  final TaskRepository _repo;
  String _currentDateIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

  TodayTasksNotifier(this._repo) : super([]) {
    loadTasks();
  }

  String get selectedDateIso => _currentDateIso;

  Future<void> loadTasks([String? dateIso]) async {
    if (dateIso != null) {
      _currentDateIso = dateIso;
    }
    state = await _repo.getTasksForDate(_currentDateIso);
  }

  Future<void> addTask({
    required String title,
    String? description,
    required String startTime,
    String? endTime,
    int durationMinutes = 45,
    String? scheduledDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final dateStr = scheduledDate ?? _currentDateIso;
    final task = WorkTask(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      scheduledDate: dateStr,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      priority: priority,
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
    );

    await _repo.saveTask(task);
    await loadTasks(dateStr);
  }

  Future<void> updateTaskStatus(String id, TaskStatus status) async {
    final task = state.firstWhere((t) => t.id == id);
    final updated = WorkTask(
      id: task.id,
      title: task.title,
      description: task.description,
      scheduledDate: task.scheduledDate,
      startTime: task.startTime,
      endTime: task.endTime,
      durationMinutes: task.durationMinutes,
      priority: task.priority,
      status: status,
      createdAt: task.createdAt,
    );

    await _repo.saveTask(updated);
    await loadTasks();
  }

  Future<void> updateTask(WorkTask task) async {
    await _repo.saveTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    await _repo.deleteTask(id);
    await loadTasks();
  }
}
