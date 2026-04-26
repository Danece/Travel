import '../../../marker/domain/entities/marker_entity.dart';
import '../repositories/excel_repository.dart';

class ExportToExcel {
  const ExportToExcel(this._repository);
  final ExcelRepository _repository;

  /// 觸發匯出，回傳儲存的完整檔案路徑
  Future<String> call(List<MarkerEntity> markers) =>
      _repository.exportMarkers(markers);
}
