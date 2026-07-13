import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/country_names.dart';

/// 透過 Nominatim OpenStreetMap 免費 API 將座標反解析為國家名稱。
///
/// Nominatim 使用政策要求：
///   - User-Agent 必須包含應用程式名稱與聯絡資訊
///   - 請求頻率不超過每秒 1 次（由呼叫端自行控制）
class GeocodingService {
  GeocodingService._();
  static final instance = GeocodingService._();

  static const _baseUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const _headers = {
    'User-Agent': 'TravelMark/1.0.0 (a0938550310@gmail.com)',
    'Accept-Language': 'en', // 固定回傳英文國家名，再由 toChineseName() 轉換
  };

  /// 依緯度、經度取得所在國家的繁體中文名稱（如「台灣」、「日本」）。
  ///
  /// 流程：
  ///   1. 呼叫 Nominatim API 取得 JSON，解析 address.country（英文）
  ///   2. 透過 [toChineseName] 轉換為繁體中文
  ///
  /// 網路錯誤、逾時、或解析失敗時回傳 null，不拋出 exception。
  Future<String?> getCountryFromCoordinates(double lat, double lng) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'json',
    });

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      final englishName = address?['country'] as String?;
      if (englishName == null) return null;

      // 有對應則回傳中文，無對應則回傳原始英文（避免顯示空白）
      return toChineseName(englishName);
    } catch (_) {
      return null;
    }
  }
}

/// 提供 [GeocodingService] 實例的 Riverpod Provider。
///
/// 使用方式：
/// ```dart
/// final service = ref.read(geocodingServiceProvider);
/// final country = await service.getCountryFromCoordinates(lat, lng);
/// ```
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService._();
});
