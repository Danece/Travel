import '../entities/import_result.dart';
import '../repositories/excel_repository.dart';

class ImportFromExcel {
  const ImportFromExcel(this._repository);
  final ExcelRepository _repository;

  /// 從指定路徑匯入 xlsx，回傳結果摘要
  Future<ImportResult> call(String filePath) =>
      _repository.importMarkersFromExcel(filePath);
}
