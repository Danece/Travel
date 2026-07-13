import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Open-Meteo API 回傳的天氣資料（已解析為應用層格式）。
class WeatherResult {
  const WeatherResult({
    required this.condition,
    required this.description,
    required this.temperature,
    required this.humidity,
    required this.icon,
  });

  final String condition;    // 天氣狀況代碼，如 "clear"、"rain"
  final String description;  // 中文天氣描述，如 "晴天"、"雨天"
  final double temperature;  // 當日均溫（°C），(max+min)/2 四捨五入至小數一位
  final int humidity;        // 當日平均濕度（%）
  final String icon;         // icon 代碼，UI 層據此對應本地圖檔
}

/// 透過 Open-Meteo 免費 API 取得歷史天氣資料。
///
/// 優點：完全免費、無需 API Key、支援全球任意日期的歷史天氣。
///
/// API 文件：https://open-meteo.com/en/docs
class WeatherService {
  WeatherService();

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _headers = {
    'User-Agent': 'TravelMark/1.0.0 (a0938550310@gmail.com)',
  };

  /// 取得指定座標與日期的天氣資料。
  ///
  /// 流程：
  ///   1. 呼叫 Open-Meteo API，取得 daily（weathercode、max/min 溫度）與
  ///      hourly（每小時濕度）資料
  ///   2. WMO weathercode 解析為中文描述與代碼
  ///   3. 均溫 = (max + min) / 2，四捨五入至小數一位
  ///   4. 平均濕度 = hourly 全天資料平均值
  ///
  /// 網路錯誤、解析失敗或逾時（10 秒）時回傳 null，不拋出 exception。
  Future<WeatherResult?> getWeather(
    double lat,
    double lng,
    DateTime date,
  ) async {
    final dateStr = _formatDate(date);
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'daily': 'weathercode,temperature_2m_max,temperature_2m_min',
      'hourly': 'relativehumidity_2m',
      'start_date': dateStr,
      'end_date': dateStr,
      'timezone': 'auto',
    });

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parse(json);
    } catch (_) {
      return null;
    }
  }

  /// 解析 Open-Meteo JSON 回應為 [WeatherResult]；格式錯誤時回傳 null。
  WeatherResult? _parse(Map<String, dynamic> json) {
    final daily = json['daily'] as Map<String, dynamic>?;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (daily == null || hourly == null) return null;

    final codes = daily['weathercode'] as List<dynamic>?;
    final maxList = daily['temperature_2m_max'] as List<dynamic>?;
    final minList = daily['temperature_2m_min'] as List<dynamic>?;
    final humList = hourly['relativehumidity_2m'] as List<dynamic>?;

    if (codes == null || codes.isEmpty) return null;
    if (maxList == null || maxList.isEmpty) return null;
    if (minList == null || minList.isEmpty) return null;

    // WMO weathercode → (condition 代碼, 中文描述)
    final code = (codes.first as num).toInt();
    final (condition, description) = _decodeWeatherCode(code);

    // 均溫：(最高 + 最低) / 2，四捨五入至小數一位
    final tMax = (maxList.first as num).toDouble();
    final tMin = (minList.first as num).toDouble();
    final temperature =
        double.parse(((tMax + tMin) / 2).toStringAsFixed(1));

    // 平均濕度：取 hourly 全天（最多 24 筆）平均值
    int humidity = 0;
    if (humList != null && humList.isNotEmpty) {
      final sum = humList.fold<double>(
        0,
        (acc, v) => acc + (v as num).toDouble(),
      );
      humidity = (sum / humList.length).round();
    }

    // icon 代碼與 condition 相同，UI 層再依此對應圖檔資源
    return WeatherResult(
      condition: condition,
      description: description,
      temperature: temperature,
      humidity: humidity,
      icon: condition,
    );
  }

  /// 將 [DateTime] 格式化為 Open-Meteo 要求的 `yyyy-MM-dd`
  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// WMO weathercode 對照表，回傳 (condition 代碼, 中文描述)。
  ///
  /// 代碼來源：https://open-meteo.com/en/docs#weathervariables
  (String, String) _decodeWeatherCode(int code) => switch (code) {
        0 => ('clear', '晴天'),
        1 || 2 || 3 => ('cloudy', '多雲'),
        45 || 48 => ('fog', '霧'),
        51 || 53 || 55 => ('drizzle', '毛毛雨'),
        61 || 63 || 65 => ('rain', '雨天'),
        71 || 73 || 75 => ('snow', '雪天'),
        77 => ('snow', '雪粒'),
        80 || 81 || 82 => ('shower', '陣雨'),
        85 || 86 => ('snow_shower', '陣雪'),
        95 => ('thunderstorm', '雷陣雨'),
        96 || 99 => ('heavy_thunderstorm', '強雷陣雨'),
        _ => ('unknown', '未知'),
      };
}

/// 提供 [WeatherService] 實例的 Riverpod Provider。
///
/// 使用方式：
/// ```dart
/// final service = ref.read(weatherServiceProvider);
/// final result = await service.getWeather(lat, lng, date);
/// ```
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});
