import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/marker_model.dart';
import 'marker_local_datasource.dart';
import 'marker_table.dart';

class MarkerLocalDatasourceImpl implements MarkerLocalDatasource {
  const MarkerLocalDatasourceImpl(this._dbHelper);
  final DatabaseHelper _dbHelper;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<List<MarkerModel>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      MarkerTable.tableName,
      orderBy: '${MarkerTable.colCreatedAt} DESC',
    );
    return rows.map(MarkerModel.fromMap).toList();
  }

  @override
  Future<MarkerModel?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      MarkerTable.tableName,
      where: '${MarkerTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MarkerModel.fromMap(rows.first);
  }

  @override
  Future<List<MarkerModel>> search({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (title != null && title.isNotEmpty) {
      conditions.add('${MarkerTable.colTitle} LIKE ?');
      args.add('%$title%');
    }
    if (countries != null && countries.isNotEmpty) {
      final placeholders = List.filled(countries.length, '?').join(',');
      conditions.add('${MarkerTable.colCountry} IN ($placeholders)');
      args.addAll(countries);
    }
    if (minRating != null) {
      conditions.add('${MarkerTable.colRating} >= ?');
      args.add(minRating);
    }
    if (startDate != null) {
      conditions.add('${MarkerTable.colCreatedAt} >= ?');
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      conditions.add('${MarkerTable.colCreatedAt} <= ?');
      args.add(endDate.millisecondsSinceEpoch);
    }
    if (categories != null && categories.isNotEmpty) {
      final placeholders = List.filled(categories.length, '?').join(',');
      conditions.add('${MarkerTable.colCategory} IN ($placeholders)');
      args.addAll(categories);
    }

    final rows = await db.query(
      MarkerTable.tableName,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${MarkerTable.colCreatedAt} DESC',
    );
    return rows.map(MarkerModel.fromMap).toList();
  }

  @override
  Future<void> insert(MarkerModel model) async {
    final db = await _db;
    await db.insert(
      MarkerTable.tableName,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> upsert(MarkerModel model) async {
    final db = await _db;
    await db.insert(
      MarkerTable.tableName,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(MarkerModel model) async {
    final db = await _db;
    await db.update(
      MarkerTable.tableName,
      model.toMap(),
      where: '${MarkerTable.colId} = ?',
      whereArgs: [model.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(
      MarkerTable.tableName,
      where: '${MarkerTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
