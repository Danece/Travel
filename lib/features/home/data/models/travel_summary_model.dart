import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/travel_summary_entity.dart';

part 'travel_summary_model.freezed.dart';
part 'travel_summary_model.g.dart';

@freezed
sealed class TravelSummaryModel with _$TravelSummaryModel {
  const factory TravelSummaryModel({
    required int totalMarkers,
    required int totalCountries,
    required double averageRating,
    required DateTime lastUpdated,
  }) = _TravelSummaryModel;

  factory TravelSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$TravelSummaryModelFromJson(json);
}

extension TravelSummaryModelX on TravelSummaryModel {
  TravelSummaryEntity toEntity() => TravelSummaryEntity(
        totalMarkers: totalMarkers,
        totalCountries: totalCountries,
        averageRating: averageRating,
        lastUpdated: lastUpdated,
      );
}
