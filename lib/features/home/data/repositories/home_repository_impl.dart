import '../../../../core/database/database_helper.dart';
import '../../../marker/data/datasources/marker_table.dart';
import '../../domain/entities/travel_summary_entity.dart';
import '../../domain/repositories/home_repository.dart';

// ── HomeRepositoryImpl ────────────────────────────────────────────────────────
//
// 執行三條 SQLite 查詢，組合成 TravelSummaryEntity：
//   1. COUNT(*)              → totalMarkers（地標總數）
//   2. COUNT(DISTINCT country) → totalCountries（造訪國家數）
//   3. AVG(rating)           → averageRating（平均評分）
//   4. MAX(created_at)       → lastUpdated（最後更新時間）

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._dbHelper);
  final DatabaseHelper _dbHelper;

  @override
  Future<TravelSummaryEntity> getTravelSummary() async {
    final db = await _dbHelper.database;
    final t = MarkerTable.tableName;

    // ── 並行執行四條查詢以減少等待時間 ──────────────────────────────────────
    final results = await Future.wait([
      // 地標總數
      db.rawQuery('SELECT COUNT(*) AS value FROM $t'),
      // 造訪國家數（以 country 欄位去重）
      db.rawQuery(
        'SELECT COUNT(DISTINCT ${MarkerTable.colCountry}) AS value FROM $t',
      ),
      // 平均評分（資料表為空時 AVG 回傳 NULL）
      db.rawQuery('SELECT AVG(${MarkerTable.colRating}) AS value FROM $t'),
      // 最後一筆建立時間（毫秒時間戳）
      db.rawQuery(
        'SELECT MAX(${MarkerTable.colCreatedAt}) AS value FROM $t',
      ),
    ]);

    final totalMarkers = (results[0].first['value'] as int?) ?? 0;
    final totalCountries = (results[1].first['value'] as int?) ?? 0;

    // AVG 在資料表為空時回傳 NULL；Dart 的 num 轉換需處理 int/double 兩種型態
    final avgRaw = results[2].first['value'];
    final averageRating = avgRaw == null ? 0.0 : (avgRaw as num).toDouble();

    final maxMs = results[3].first['value'] as int?;
    final lastUpdated = maxMs != null
        ? DateTime.fromMillisecondsSinceEpoch(maxMs)
        : DateTime.now();

    return TravelSummaryEntity(
      totalMarkers: totalMarkers,
      totalCountries: totalCountries,
      averageRating: averageRating,
      lastUpdated: lastUpdated,
    );
  }
}
