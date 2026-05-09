import 'dart:typed_data';

import '../../../marker/domain/entities/marker_entity.dart';
import '../entities/import_result.dart';

abstract interface class ExcelRepository {
  /// 將地標清單匯出為 CSV 檔案，回傳完整儲存路徑
  Future<String> exportMarkers(List<MarkerEntity> markers);

  /// 從 CSV bytes 批量匯入地標，回傳匯入結果摘要
  Future<ImportResult> importMarkersFromBytes(Uint8List bytes);
}
