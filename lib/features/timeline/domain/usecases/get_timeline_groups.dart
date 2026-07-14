import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/domain/repositories/marker_repository.dart';
import '../entities/timeline_group_entity.dart';

/// 取得所有標記並依年份、月份分組，回傳時間軸所需的分組清單。
///
/// 排序規則：
///   - 年份降序（最新年份在前）
///   - 同年內月份降序（12 月在前）
///   - 同月內標記依 [createdAt] 降序（最新標記在前）
class GetTimelineGroups {
  const GetTimelineGroups(this._repository);

  final MarkerRepository _repository;

  /// 執行分組邏輯，回傳 [TimelineGroupEntity] 清單。
  Future<List<TimelineGroupEntity>> call() async {
    final markers = await _repository.getAllMarkers();
    if (markers.isEmpty) return [];

    // 以 (year, month) 為鍵聚合標記
    final Map<(int, int), List<_Entry>> grouped = {};
    for (final marker in markers) {
      final key = (marker.createdAt.year, marker.createdAt.month);
      grouped.putIfAbsent(key, () => []).add(
            _Entry(
              marker: marker,
              createdAt: marker.createdAt,
            ),
          );
    }

    // 將各組標記按日期降序排列
    for (final entries in grouped.values) {
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // 將 key 排序：年份降序，同年內月份降序
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final yearCmp = b.$1.compareTo(a.$1); // 年份降序
        if (yearCmp != 0) return yearCmp;
        return b.$2.compareTo(a.$2);           // 月份降序
      });

    return sortedKeys.map((key) {
      final entries = grouped[key]!;
      return TimelineGroupEntity(
        year: key.$1,
        month: key.$2,
        markers: entries.map((e) => e.marker).toList(),
      );
    }).toList();
  }
}

/// 暫存標記與其排序鍵，避免重複讀取 [MarkerEntity.createdAt]
class _Entry {
  const _Entry({required this.marker, required this.createdAt});
  final MarkerEntity marker;
  final DateTime createdAt;
}
