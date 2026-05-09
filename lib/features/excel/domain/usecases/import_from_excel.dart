import 'dart:typed_data';

import '../entities/import_result.dart';
import '../repositories/excel_repository.dart';

class ImportFromExcel {
  const ImportFromExcel(this._repository);
  final ExcelRepository _repository;

  Future<ImportResult> call(Uint8List bytes) =>
      _repository.importMarkersFromBytes(bytes);
}
