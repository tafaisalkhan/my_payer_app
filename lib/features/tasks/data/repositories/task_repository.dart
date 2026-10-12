import 'package:mynamaz_scheduler/core/database/app_database.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_session.dart';
import 'package:mynamaz_scheduler/features/tasks/domain/models/work_task.dart';
import 'package:sqflite/sqflite.dart';

class TaskRepository {
  Future<List<WorkTask>> getTasksForDate(String dateIso) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'work_tasks',
      where: 'scheduled_date = ?',
      whereArgs: [dateIso],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => WorkTask.fromMap(m)).toList();
  }

  Future<List<WorkTask>> getPendingTasks() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'work_tasks',
      where: 'status != ?',
      whereArgs: ['COMPLETED'],
      orderBy: 'scheduled_date ASC',
    );
    return maps.map((m) => WorkTask.fromMap(m)).toList();
  }

  Future<void> saveTask(WorkTask task) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'work_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('work_tasks', where: 'id = ?', whereArgs: [id]);
    await db.delete('work_sessions', where: 'task_id = ?', whereArgs: [id]);
  }

  Future<WorkSession?> getActiveSessionForTask(String taskId) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'work_sessions',
      where: 'task_id = ? AND status = ?',
      whereArgs: [taskId, 'IN_PROGRESS'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkSession.fromMap(maps.first);
  }

  Future<void> saveSession(WorkSession session) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'work_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WorkSession>> getCompletedSessionsForTask(String taskId) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'work_sessions',
      where: 'task_id = ? AND status = ?',
      whereArgs: [taskId, 'COMPLETED'],
    );
    return maps.map((m) => WorkSession.fromMap(m)).toList();
  }
}
