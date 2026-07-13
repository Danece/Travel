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
    this.category = 'attraction',
    // ── 天氣資訊（全部可為 null，舊資料不受影響）─────────────────────────
    this.weatherCondition,
    this.weatherDescription,
    this.temperature,
    this.humidity,
    this.weatherIcon,
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
  final String category;
  final String? weatherCondition;    // 天氣狀況代碼，如 "clear"、"rain"
  final String? weatherDescription;  // 天氣描述，如 "晴天"、"多雲"
  final double? temperature;         // 氣溫（°C）
  final int? humidity;               // 濕度（%）
  final String? weatherIcon;         // icon 代碼，對應本地 icon 顯示

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
        category: map[MarkerTable.colCategory] as String? ?? 'attraction',
        // 天氣欄位：v3 新增，舊資料讀取時為 null，不影響既有記錄
        weatherCondition: map[MarkerTable.colWeatherCondition] as String?,
        weatherDescription: map[MarkerTable.colWeatherDescription] as String?,
        temperature: map[MarkerTable.colTemperature] as double?,
        humidity: map[MarkerTable.colHumidity] as int?,
        weatherIcon: map[MarkerTable.colWeatherIcon] as String?,
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
        MarkerTable.colCategory: category,
        // null 值直接寫入 SQLite NULL，讓舊資料欄位保持空值
        MarkerTable.colWeatherCondition: weatherCondition,
        MarkerTable.colWeatherDescription: weatherDescription,
        MarkerTable.colTemperature: temperature,
        MarkerTable.colHumidity: humidity,
        MarkerTable.colWeatherIcon: weatherIcon,
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
        category: entity.category,
        weatherCondition: entity.weatherCondition,
        weatherDescription: entity.weatherDescription,
        temperature: entity.temperature,
        humidity: entity.humidity,
        weatherIcon: entity.weatherIcon,
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
        category: category,
        weatherCondition: weatherCondition,
        weatherDescription: weatherDescription,
        temperature: temperature,
        humidity: humidity,
        weatherIcon: weatherIcon,
      );
}
