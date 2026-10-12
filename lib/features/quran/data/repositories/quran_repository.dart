import 'package:mynamaz_scheduler/core/database/app_database.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_history.dart';
import 'package:mynamaz_scheduler/features/quran/domain/models/quran_schedule.dart';
import 'package:sqflite/sqflite.dart';

class QuranRepository {
  Future<List<QuranSchedule>> getActiveSchedules() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'quran_schedules',
      where: 'is_active = 1',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => QuranSchedule.fromMap(m)).toList();
  }

  Future<void> saveSchedule(QuranSchedule schedule) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'quran_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSchedule(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('quran_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<QuranHistory>> getHistory() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('quran_history', orderBy: 'completed_at DESC');
    return maps.map((m) => QuranHistory.fromMap(m)).toList();
  }

  Future<void> addHistory(QuranHistory history) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'quran_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
