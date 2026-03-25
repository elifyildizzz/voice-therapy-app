import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const String _databaseName = 'voice_therapy.db';
  static const String szTestRecordsTable = 'sz_test_records';
  static const String clientFormRecordsTable = 'client_form_records';
  static const int _databaseVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSzTestRecordsTable(db);
        await _createClientFormRecordsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createClientFormRecordsTable(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createSzTestRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${LocalDatabase.szTestRecordsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        s_attempts TEXT NOT NULL,
        z_attempts TEXT NOT NULL,
        s_best REAL NOT NULL,
        z_best REAL NOT NULL,
        ratio REAL NOT NULL
      )
    ''');
  }

  Future<void> _createClientFormRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${LocalDatabase.clientFormRecordsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        vrqol_q1 INTEGER NOT NULL,
        vrqol_q4 INTEGER NOT NULL,
        vrqol_q9 INTEGER NOT NULL,
        vhi_q3 INTEGER NOT NULL,
        vhi_q9 INTEGER NOT NULL,
        total_score INTEGER NOT NULL,
        result_label TEXT NOT NULL
      )
    ''');
  }
}
