import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/domain/repositories/marker_repository.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/repositories/excel_repository.dart';

// ── 欄位索引常數（匯出、匯入共用，避免魔術數字）──────────────────────────────
const _colId = 0;
const _colTitle = 1;
const _colCountry = 2;
const _colDate = 3;
const _colLat = 4;
const _colLng = 5;
const _colRating = 6;
const _colNote = 7;
const _colPhotoCount = 8;

/// Excel 工作表名稱
const _sheetName = 'TravelMark';

class ExcelRepositoryImpl implements ExcelRepository {
  const ExcelRepositoryImpl(this._markerRepository);

  /// 注入 MarkerRepository，用於匯入時批量寫入資料庫
  final MarkerRepository _markerRepository;

  // ══════════════════════════════════════════════════════════════════════════
  // 匯出
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<String> exportMarkers(List<MarkerEntity> markers) async {
    final excel = Excel.createExcel();

    // 預設工作表名稱為 'Sheet1'，先刪除再以正確名稱建立
    excel.delete('Sheet1');
    final sheet = excel[_sheetName];

    // 寫入標題列（加粗、藍底白字）
    _writeHeaderRow(sheet);

    // 從第 1 列（index 1）依序寫入每筆地標資料
    for (var i = 0; i < markers.length; i++) {
      _writeDataRow(sheet, rowIndex: i + 1, marker: markers[i]);
    }

    // 計算完整儲存路徑
    final savePath = await _buildSavePath();

    // 編碼並寫入磁碟
    final encoded = excel.encode();
    if (encoded == null) {
      throw const LocalFailure('Excel 編碼失敗，請重試');
    }
    await File(savePath).writeAsBytes(encoded);

    return savePath;
  }

  /// 寫入標題列：9 個欄位，加粗、藍底（#1565C0）白字（#FFFFFF）
  void _writeHeaderRow(Sheet sheet) {
    const headers = [
      'ID', '標題', '國家', '建立日期',
      '緯度', '經度', '評分', '心得內容', '照片數量',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      );
    }
  }

  /// 將單筆 MarkerEntity 寫入指定列索引
  void _writeDataRow(
    Sheet sheet, {
    required int rowIndex,
    required MarkerEntity marker,
  }) {
    // 快捷輔助：設定指定欄位的值
    void put(int col, CellValue value) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          )
          .value = value;
    }

    // 日期格式：yyyy-MM-dd
    final d = marker.createdAt;
    final dateStr =
        '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    put(_colId, TextCellValue(marker.id));
    put(_colTitle, TextCellValue(marker.title));
    put(_colCountry, TextCellValue(marker.country));
    put(_colDate, TextCellValue(dateStr));
    put(_colLat, DoubleCellValue(marker.latitude));
    put(_colLng, DoubleCellValue(marker.longitude));
    put(_colRating, IntCellValue(marker.rating));
    put(_colNote, TextCellValue(marker.note));
    // 照片欄位：僅存數量（路徑不匯出，保護隱私且跨裝置無意義）
    put(_colPhotoCount, IntCellValue(marker.photoPaths.length));
  }

  /// 決定儲存路徑：Android 嘗試 Downloads，iOS/其他退回 Documents
  Future<String> _buildSavePath() async {
    Directory dir;
    try {
      dir = (await getDownloadsDirectory()) ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }
    if (!dir.existsSync()) await dir.create(recursive: true);

    // 檔名格式：TravelMark_Export_yyyyMMdd_HHmmss.xlsx
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    return p.join(dir.path, 'TravelMark_Export_$stamp.xlsx');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 匯入
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<ImportResult> importMarkersFromExcel(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // 優先使用 TravelMark 工作表，找不到則取第一個工作表
    final sheet = excel.tables[_sheetName] ?? excel.tables.values.firstOrNull;
    if (sheet == null) {
      throw const LocalFailure('找不到可讀取的工作表');
    }

    int successCount = 0;
    int skippedCount = 0;
    final failedRows = <int>[];
    final failedMessages = <String>[];

    // 從第 1 列（index 1）開始，跳過第 0 列標題
    for (var rowIdx = 1; rowIdx < sheet.maxRows; rowIdx++) {
      final row = sheet.row(rowIdx);

      // 全空白列跳過
      final isBlank = row.every((c) => c == null || c.value == null);
      if (isBlank) {
        skippedCount++;
        continue;
      }

      try {
        final marker = _parseRow(row, rowIdx);
        await _markerRepository.insertMarker(marker);
        successCount++;
      } on LocalFailure catch (e) {
        failedRows.add(rowIdx + 1);
        failedMessages.add(e.message);
      } catch (e) {
        failedRows.add(rowIdx + 1);
        failedMessages.add('第 ${rowIdx + 1} 列：${e.toString()}');
      }
    }

    return ImportResult(
      successCount: successCount,
      skippedCount: skippedCount,
      failedRows: failedRows,
      failedMessages: failedMessages,
    );
  }

  /// 解析單列為 MarkerEntity；任何驗證失敗皆拋出 LocalFailure
  MarkerEntity _parseRow(List<Data?> row, int rowIdx) {
    // 取得指定欄的字串值（去除空白，空字串回傳 null）
    String? str(int col) {
      if (col >= row.length) return null;
      final v = row[col]?.value;
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isNotEmpty ? s : null;
    }

    // 取得 double 值，支援字串格式
    double? dbl(int col) => double.tryParse(str(col) ?? '');

    // 取得 int 值，支援浮點數字串（如 "3.0"）
    int? integer(int col) {
      final s = str(col);
      if (s == null) return null;
      return int.tryParse(s) ?? double.tryParse(s)?.toInt();
    }

    // 1-indexed 列號（含標題列），用於錯誤訊息
    final displayRow = rowIdx + 1;

    // ── 必填欄位驗證 ──────────────────────────────────────────────────────

    final title = str(_colTitle);
    if (title == null) {
      throw LocalFailure('第 $displayRow 列：標題不得為空');
    }

    final country = str(_colCountry);
    if (country == null) {
      throw LocalFailure('第 $displayRow 列：國家不得為空');
    }

    final lat = dbl(_colLat);
    if (lat == null || lat < -90 || lat > 90) {
      throw LocalFailure('第 $displayRow 列：緯度無效（需介於 -90 ~ 90）');
    }

    final lng = dbl(_colLng);
    if (lng == null || lng < -180 || lng > 180) {
      throw LocalFailure('第 $displayRow 列：經度無效（需介於 -180 ~ 180）');
    }

    final rating = integer(_colRating);
    if (rating == null || rating < 1 || rating > 5) {
      throw LocalFailure('第 $displayRow 列：評分無效（需介於 1 ~ 5，目前為「${str(_colRating) ?? '空'}」）');
    }

    // ── 選填欄位 ──────────────────────────────────────────────────────────

    // ID 空白時產生新 UUID，確保不與現有資料衝突
    final rawId = str(_colId);
    final id = (rawId != null) ? rawId : const Uuid().v4();

    // 日期解析，格式需為 yyyy-MM-dd；失敗時使用今日
    final dateStr = str(_colDate);
    final createdAt = (dateStr != null)
        ? (DateTime.tryParse(dateStr) ?? DateTime.now())
        : DateTime.now();

    return MarkerEntity(
      id: id,
      title: title,
      country: country,
      createdAt: createdAt,
      latitude: lat,
      longitude: lng,
      rating: rating,
      note: str(_colNote) ?? '',
      photoPaths: const [], // 匯入時不含照片（路徑跨裝置無意義）
    );
  }
}
