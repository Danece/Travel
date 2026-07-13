import 'package:flutter/foundation.dart';
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
      // v1 → 初始建表
      // v2 → 新增 category 欄位
      // v3 → 新增天氣相關欄位（weather_condition / weather_description /
      //       temperature / humidity / weather_icon）
      version: 3,
      onCreate: (db, _) async {
        await db.execute(MarkerTable.createTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colCategory} TEXT NOT NULL DEFAULT \'attraction\'',
          );
        }
        if (oldVersion < 3) {
          // 天氣欄位全部允許 NULL，不指定 DEFAULT，舊資料自動以 NULL 填充
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colWeatherCondition} TEXT',
          );
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colWeatherDescription} TEXT',
          );
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colTemperature} REAL',
          );
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colHumidity} INTEGER',
          );
          await db.execute(
            'ALTER TABLE ${MarkerTable.tableName} ADD COLUMN '
            '${MarkerTable.colWeatherIcon} TEXT',
          );
        }
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

  /// 僅供測試使用：直接注入已開啟的 [Database]（例如 sqflite_common_ffi 的 in-memory DB）
  @visibleForTesting
  static void injectForTesting(Database db) => _db = db;
}
