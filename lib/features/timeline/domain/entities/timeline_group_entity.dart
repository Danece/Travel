import '../../../marker/domain/entities/marker_entity.dart';

/// 時間軸的月份分組資料。
///
/// 每個實例代表同一年同一月份的所有標記，
/// 供時間軸頁面按年／月分組顯示。
class TimelineGroupEntity {
  const TimelineGroupEntity({
    required this.year,
    required this.month,
    required this.markers,
  });

  /// 年份，例如 2024
  final int year;

  /// 月份（1–12）
  final int month;

  /// 該月的標記列表，依 [MarkerEntity.createdAt] 降序排列（最新在前）
  final List<MarkerEntity> markers;

  /// 月份標籤，例如 `「3月」`、`「12月」`
  String get monthLabel => '$month月';

  /// 該月份的標記數量
  int get markerCount => markers.length;
}
