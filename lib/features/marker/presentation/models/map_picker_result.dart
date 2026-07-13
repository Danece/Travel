import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 地圖選點頁面（MapPickerPage）的回傳結果。
///
/// [latLng] 為使用者確認的座標；
/// [detectedCountry] 為透過 Geocoding API 自動偵測的國家中文名稱，
/// API 逾時或失敗時為 null。
class MapPickerResult {
  const MapPickerResult({
    required this.latLng,
    this.detectedCountry,
  });

  /// 使用者在地圖上選取的座標
  final LatLng latLng;

  /// 自動偵測的國家名稱（中文），偵測失敗時為 null
  final String? detectedCountry;
}
