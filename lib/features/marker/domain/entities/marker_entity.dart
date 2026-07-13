import 'package:freezed_annotation/freezed_annotation.dart';

part 'marker_entity.freezed.dart';

@freezed
sealed class MarkerEntity with _$MarkerEntity {
  @Assert('rating >= 1 && rating <= 5', 'rating must be between 1 and 5')
  const factory MarkerEntity({
    required String id,
    required String title,
    required String country,
    required DateTime createdAt,
    required double latitude,
    required double longitude,
    required int rating,
    @Default('') String note,
    @Default([]) List<String> photoPaths,
    @Default('attraction') String category,
    // ── 天氣資訊（建立標記時可選填，舊資料全部為 null）────────────────────
    String? weatherCondition,    // 天氣狀況代碼，如 "clear"、"rain"
    String? weatherDescription,  // 天氣描述，如 "晴天"、"多雲"
    double? temperature,         // 氣溫（°C）
    int? humidity,               // 濕度（%）
    String? weatherIcon,         // icon 代碼，對應本地 icon 顯示
  }) = _MarkerEntity;
}
