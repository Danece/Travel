import 'dart:convert';

import '../../domain/entities/marker_entity.dart';
import '../datasources/marker_table.dart';

class MarkerModel {
  const MarkerModel({
    required this.id,
    required this.title,
    required this.country,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.rating,
    this.note = '',
    this.photoPaths = const [],
  });

  final String id;
  final String title;
  final String country;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final int rating;
  final String note;
  final List<String> photoPaths;

  // ── SQLite ────────────────────────────────────────────────────────────────

  factory MarkerModel.fromMap(Map<String, dynamic> map) => MarkerModel(
        id: map[MarkerTable.colId] as String,
        title: map[MarkerTable.colTitle] as String,
        country: map[MarkerTable.colCountry] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map[MarkerTable.colCreatedAt] as int,
        ),
        latitude: map[MarkerTable.colLatitude] as double,
        longitude: map[MarkerTable.colLongitude] as double,
        rating: map[MarkerTable.colRating] as int,
        note: map[MarkerTable.colNote] as String? ?? '',
        photoPaths: (jsonDecode(map[MarkerTable.colPhotoPaths] as String)
                as List<dynamic>)
            .cast<String>(),
      );

  Map<String, dynamic> toMap() => {
        MarkerTable.colId: id,
        MarkerTable.colTitle: title,
        MarkerTable.colCountry: country,
        MarkerTable.colCreatedAt: createdAt.millisecondsSinceEpoch,
        MarkerTable.colLatitude: latitude,
        MarkerTable.colLongitude: longitude,
        MarkerTable.colRating: rating,
        MarkerTable.colNote: note,
        MarkerTable.colPhotoPaths: jsonEncode(photoPaths),
      };

  // ── Domain ────────────────────────────────────────────────────────────────

  factory MarkerModel.fromEntity(MarkerEntity entity) => MarkerModel(
        id: entity.id,
        title: entity.title,
        country: entity.country,
        createdAt: entity.createdAt,
        latitude: entity.latitude,
        longitude: entity.longitude,
        rating: entity.rating,
        note: entity.note,
        photoPaths: entity.photoPaths,
      );

  MarkerEntity toEntity() => MarkerEntity(
        id: id,
        title: title,
        country: country,
        createdAt: createdAt,
        latitude: latitude,
        longitude: longitude,
        rating: rating,
        note: note,
        photoPaths: photoPaths,
      );
}
