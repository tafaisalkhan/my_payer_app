import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mynamaz_scheduler.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE work_tasks ADD COLUMN duration_minutes INTEGER DEFAULT 45');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE quran_schedules ADD COLUMN duration_minutes INTEGER DEFAULT 30');
        } catch (_) {}
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. User Settings Table
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 2. Prayer Records Table
    await db.execute('''
      CREATE TABLE prayer_records (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        prayer_name TEXT NOT NULL,
        status TEXT NOT NULL,
        takbir_e_ula INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Quran Schedules Table
    await db.execute('''
      CREATE TABLE quran_schedules (
        id TEXT PRIMARY KEY,
        frequency TEXT NOT NULL,
        recitation_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 30,
        surah_id INTEGER NOT NULL,
        surah_name TEXT NOT NULL,
        start_ayah INTEGER NOT NULL,
        end_ayah INTEGER NOT NULL,
        juz INTEGER,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Quran History Log Table
    await db.execute('''
      CREATE TABLE quran_history (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        date TEXT NOT NULL,
        surah_name TEXT NOT NULL,
        start_ayah INTEGER NOT NULL,
        end_ayah INTEGER NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');

    // 5. Work Tasks Table
    await db.execute('''
      CREATE TABLE work_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        scheduled_date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_minutes INTEGER NOT NULL DEFAULT 45,
        priority TEXT NOT NULL DEFAULT 'MEDIUM',
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      )
    ''');

    // 6. Work Sessions Timer Table
    await db.execute('''
      CREATE TABLE work_sessions (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        start_timestamp TEXT NOT NULL,
        end_timestamp TEXT,
        active_duration_seconds INTEGER NOT NULL DEFAULT 0,
        is_paused INTEGER NOT NULL DEFAULT 0,
        last_paused_timestamp TEXT,
        status TEXT NOT NULL DEFAULT 'IN_PROGRESS'
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
