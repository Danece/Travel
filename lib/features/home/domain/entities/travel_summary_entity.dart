import 'package:freezed_annotation/freezed_annotation.dart';

part 'travel_summary_entity.freezed.dart';

@freezed
sealed class TravelSummaryEntity with _$TravelSummaryEntity {
  const factory TravelSummaryEntity({
    /// 地標（旅遊足跡）總筆數
    required int totalMarkers,
    /// 造訪的不同國家數量
    required int totalCountries,
    /// 所有地標的平均評分（0.0 表示尚無資料）
    required double averageRating,
    /// 最後一筆資料的建立時間
    required DateTime lastUpdated,
  }) = _TravelSummaryEntity;
}
