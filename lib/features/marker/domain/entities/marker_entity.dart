import 'package:freezed_annotation/freezed_annotation.dart';

part 'marker_entity.freezed.dart';

@freezed
sealed class MarkerEntity with _$MarkerEntity {
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
  }) = _MarkerEntity;
}
