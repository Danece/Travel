import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../marker/domain/entities/marker_category.dart';
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
const _colCategory = 9;

/// Excel 工作表名稱
const _sheetName = 'TravelMark';

class ExcelRepositoryImpl implements ExcelRepository {
  const ExcelRepositoryImpl(this._markerRepository);

  final MarkerRepository _markerRepository;

  static const _channel = MethodChannel('com.travelmark.app/downloads');

  // ══════════════════════════════════════════════════════════════════════════
  // 匯出
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<String> exportMarkers(List<MarkerEntity> markers) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[_sheetName];
    _writeHeaderRow(sheet);
    for (var i = 0; i < markers.length; i++) {
      _writeDataRow(sheet, rowIndex: i + 1, marker: markers[i]);
    }

    final encoded = excel.encode();
    if (encoded == null) throw const LocalFailure('Excel 編碼失敗，請重試');

    final filename = _buildFilename();

    // Android：透過 MethodChannel 寫入公開 Downloads 資料夾
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>(
          'saveToDownloads',
          {'bytes': Uint8List.fromList(encoded), 'filename': filename},
        );
        return path ?? filename;
      } catch (_) {
        // 發生錯誤時退回 App 文件目錄
      }
    }

    // 其他平台或 Android 備援：寫入 App 文件目錄
    final savePath = await _buildSavePath(filename);
    await File(savePath).writeAsBytes(encoded);
    return savePath;
  }

  /// 寫入標題列：9 個欄位，加粗、藍底（#1565C0）白字（#FFFFFF）
  void _writeHeaderRow(Sheet sheet) {
    const headers = [
      'ID', '標題', '國家', '建立日期',
      '緯度', '經度', '評分', '心得內容', '照片數量', '種類',
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
    put(_colPhotoCount, IntCellValue(marker.photoPaths.length));
    put(_colCategory, TextCellValue(marker.category));
  }

  /// 檔名格式：TravelMark_Export_yyyyMMdd_HHmmss.xlsx
  String _buildFilename() {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'TravelMark_Export_$stamp.xlsx';
  }

  /// 非 Android 平台的備援儲存路徑（App Documents 目錄）
  Future<String> _buildSavePath(String filename) async {
    Directory dir;
    try {
      dir = (await getDownloadsDirectory()) ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }
    if (!dir.existsSync()) await dir.create(recursive: true);
    return p.join(dir.path, filename);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 匯入
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<ImportResult> importMarkersFromExcel(String filePath) async {
    final rawBytes = await File(filePath).readAsBytes();
    final bytes = _fixInlineStrCells(rawBytes);

    late Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw LocalFailure('無法解析 Excel 檔案，請確認格式正確（支援 .xlsx / .xls）：${e.runtimeType}');
    }

    // 優先使用 TravelMark 工作表，找不到則取第一個工作表
    final sheet = excel.tables[_sheetName] ?? excel.tables.values.firstOrNull;
    if (sheet == null) {
      throw const LocalFailure('找不到可讀取的工作表，請確認檔案內有資料');
    }

    int successCount = 0;
    int skippedCount = 0;
    final failedRows = <int>[];
    final failedMessages = <String>[];

    // 從第 1 列（index 1）開始，跳過第 0 列標題
    for (var rowIdx = 1; rowIdx < sheet.maxRows; rowIdx++) {
      try {
        final row = sheet.row(rowIdx);

        // 全空白列跳過
        final isBlank = row.every((c) => c == null || c.value == null);
        if (isBlank) {
          skippedCount++;
          continue;
        }

        final marker = _parseRow(row, rowIdx);
        await _markerRepository.upsertMarker(marker);
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

  /// 修復 xlsx 中空的 inlineStr 儲存格（`<c t="inlineStr"></c>`），
  /// 這類儲存格缺少 `<is><t>` 子節點，會導致 excel 套件的 `.first` 拋出例外。
  List<int> _fixInlineStrCells(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      var modified = false;
      final newArchive = Archive();

      for (final file in archive) {
        if (file.isFile &&
            file.name.startsWith('xl/worksheets/') &&
            file.name.endsWith('.xml')) {
          final content = utf8.decode(file.content as List<int>, allowMalformed: true);
          // 空的 inlineStr 格：`t="inlineStr"></c>` → 補上 `<is><t></t></is>`
          final fixed = content.replaceAll(
            't="inlineStr"></c>',
            't="inlineStr"><is><t></t></is></c>',
          );
          if (fixed != content) {
            modified = true;
            final fixedBytes = utf8.encode(fixed);
            newArchive.addFile(ArchiveFile(file.name, fixedBytes.length, fixedBytes));
            continue;
          }
        }
        newArchive.addFile(file);
      }

      if (!modified) return bytes;
      return ZipEncoder().encode(newArchive) ?? bytes;
    } catch (_) {
      return bytes;
    }
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

    final categoryStr = str(_colCategory) ?? 'attraction';
    final category = MarkerCategory.fromString(categoryStr).name;

    return MarkerEntity(
      id: id,
      title: title,
      country: country,
      createdAt: createdAt,
      latitude: lat,
      longitude: lng,
      rating: rating,
      note: str(_colNote) ?? '',
      photoPaths: const [],
      category: category,
    );
  }
}
