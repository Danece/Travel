import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/marker/data/datasources/marker_table.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'travel_mark.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(MarkerTable.createTableSql);
      },
    );
  }

  /// 取得 DB 檔案的完整路徑（備份用）
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'travel_mark.db');
  }

  /// 關閉並清除快取，讓下次 [database] 重新開啟（還原備份後呼叫）
  Future<void> closeDatabase() async {
    await _db?.close();
    _db = null;
  }
}
