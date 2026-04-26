import '../../../marker/domain/entities/marker_entity.dart';
import '../entities/import_result.dart';

abstract interface class ExcelRepository {
  /// 將地標清單匯出為 xlsx 檔案，回傳完整儲存路徑
  Future<String> exportMarkers(List<MarkerEntity> markers);

  /// 從指定路徑的 xlsx 檔案批量匯入地標，回傳匯入結果摘要
  Future<ImportResult> importMarkersFromExcel(String filePath);
}
