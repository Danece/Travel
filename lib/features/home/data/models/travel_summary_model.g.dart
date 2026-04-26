// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'travel_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TravelSummaryModel _$TravelSummaryModelFromJson(Map<String, dynamic> json) =>
    _TravelSummaryModel(
      totalMarkers: (json['totalMarkers'] as num).toInt(),
      totalCountries: (json['totalCountries'] as num).toInt(),
      averageRating: (json['averageRating'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$TravelSummaryModelToJson(_TravelSummaryModel instance) =>
    <String, dynamic>{
      'totalMarkers': instance.totalMarkers,
      'totalCountries': instance.totalCountries,
      'averageRating': instance.averageRating,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };
