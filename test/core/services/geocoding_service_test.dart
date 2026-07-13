import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:travel_mark/core/services/geocoding_service.dart';

/// 呼叫 [GeocodingService.instance.getCountryFromCoordinates] 並透過
/// [http.runWithClient] 注入 MockClient，無需改動 production 代碼。
Future<String?> _callWithClient(
  http.Client mockClient,
  double lat,
  double lng,
) =>
    http.runWithClient(
      () => GeocodingService.instance.getCountryFromCoordinates(lat, lng),
      () => mockClient,
    );

/// 產生符合 Nominatim reverse geocoding 格式的假 JSON 回應
String _nominatimJson({required String country}) => jsonEncode({
      'place_id': 12345,
      'licence': 'Data © OpenStreetMap contributors',
      'address': {
        'city': 'Taipei',
        'state': 'Taiwan',
        'country': country,          // 這個欄位是測試重點
        'country_code': 'tw',
      },
    });

void main() {
  group('GeocodingService.getCountryFromCoordinates', () {
    // ── 正常回傳 ───────────────────────────────────────────────────────────

    test('API 成功回傳時，正確解析 address.country 並轉換為繁體中文', () async {
      // Nominatim 以英文回傳 'Taiwan'，服務層應轉換為 '台灣'
      final client = MockClient((_) async => http.Response(
            _nominatimJson(country: 'Taiwan'),
            200,
          ));

      final result = await _callWithClient(client, 25.03, 121.56);

      expect(result, '台灣');
    });

    test('API 回傳不在 countryNameMap 中的國家時，回傳原始英文名稱', () async {
      // 'Wonderland' 不在對照表，應直接回傳英文
      final client = MockClient((_) async => http.Response(
            _nominatimJson(country: 'Wonderland'),
            200,
          ));

      final result = await _callWithClient(client, 0, 0);

      expect(result, 'Wonderland');
    });

    test('API 回傳 Japan 時轉換為 日本', () async {
      final client = MockClient((_) async => http.Response(
            _nominatimJson(country: 'Japan'),
            200,
          ));

      final result = await _callWithClient(client, 35.68, 139.69);

      expect(result, '日本');
    });

    // ── HTTP 錯誤狀態碼 ────────────────────────────────────────────────────

    test('API 回傳非 200 狀態碼時，回傳 null 且不拋出 exception', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"not found"}', 404),
      );

      // 不應拋出任何 exception
      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });

    test('API 回傳 500 伺服器錯誤時，回傳 null', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );

      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });

    // ── 網路錯誤 ────────────────────────────────────────────────────────────

    test('網路連線失敗（exception）時，回傳 null 且不拋出 exception', () async {
      final client = MockClient((_) async {
        throw const SocketException('Network unreachable');
      });

      // SocketException 應被 catch 吸收，回傳 null
      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });

    // ── 逾時 ────────────────────────────────────────────────────────────────

    test('請求逾時時，回傳 null 且不阻擋（不拋出 exception）', () async {
      // 模擬逾時：MockClient 直接拋出 TimeoutException
      final client = MockClient((_) async {
        throw TimeoutException('request timed out');
      });

      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });

    // ── JSON 格式異常 ────────────────────────────────────────────────────────

    test('回傳 JSON 中 address 欄位為 null 時，回傳 null', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'place_id': 1}), // 沒有 address 欄位
            200,
          ));

      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });

    test('回傳無效 JSON 時，回傳 null 且不拋出 exception', () async {
      final client = MockClient(
        (_) async => http.Response('not-json-at-all', 200),
      );

      final result = await _callWithClient(client, 0, 0);

      expect(result, isNull);
    });
  });
}
