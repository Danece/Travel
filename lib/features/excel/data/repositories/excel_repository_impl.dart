import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

// ── 欄位索引常數（匯出、匯入共用）────────────────────────────────────────────
const _colId = 0;
const _colTitle = 1;
const _colCountry = 2;
const _colDate = 3;
const _colLat = 4;
const _colLng = 5;
const _colRating = 6;
const _colNote = 7;
const _colCategory = 9;

const _headers = [
  'ID', '標題', '國家', '建立日期',
  '緯度', '經度', '評分', '心得內容', '照片數量', '種類',
];

class ExcelRepositoryImpl implements ExcelRepository {
  const ExcelRepositoryImpl(this._markerRepository);

  final MarkerRepository _markerRepository;

  static const _channel = MethodChannel('com.travelmark.app/downloads');

  // ══════════════════════════════════════════════════════════════════════════
  // 匯出
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<String> exportMarkers(List<MarkerEntity> markers) async {
    final csv = _buildCsv(markers);
    // UTF-8 BOM 讓 Windows Excel 正確辨識中文
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    final filename = _buildFilename();

    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>(
          'saveToDownloads',
          {'bytes': bytes, 'filename': filename},
        );
        return path ?? filename;
      } catch (_) {}
    }

    final savePath = await _buildSavePath(filename);
    await File(savePath).writeAsBytes(bytes);
    return savePath;
  }

  /// 產生 CSV 內容字串（不含 BOM）
  String _buildCsv(List<MarkerEntity> markers) {
    final buf = StringBuffer();
    buf.writeln(_csvRow(_headers));
    for (final marker in markers) {
      final d = marker.createdAt;
      final dateStr =
          '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      buf.writeln(_csvRow([
        marker.id,
        marker.title,
        marker.country,
        dateStr,
        marker.latitude.toString(),
        marker.longitude.toString(),
        marker.rating.toString(),
        marker.note,
        marker.photoPaths.length.toString(),
        marker.category,
      ]));
    }
    return buf.toString();
  }

  /// RFC 4180：含逗號、引號、換行的欄位用雙引號包裹，引號以 "" 跳脫
  String _csvRow(List<String> fields) {
    return fields.map((f) {
      if (f.contains(',') || f.contains('"') || f.contains('\n') || f.contains('\r')) {
        return '"${f.replaceAll('"', '""')}"';
      }
      return f;
    }).join(',');
  }

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
    return 'TravelMark_Export_$stamp.csv';
  }

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
  Future<ImportResult> importMarkersFromBytes(Uint8List rawBytes) async {
    // 移除 UTF-8 BOM（若有）
    final bytes = (rawBytes.length >= 3 &&
            rawBytes[0] == 0xEF &&
            rawBytes[1] == 0xBB &&
            rawBytes[2] == 0xBF)
        ? rawBytes.sublist(3)
        : rawBytes;

    final content = utf8.decode(bytes, allowMalformed: true);
    final rows = _parseCsv(content);

    if (rows.isEmpty) {
      throw const LocalFailure('CSV 檔案無任何資料');
    }

    int successCount = 0;
    int skippedCount = 0;
    final failedRows = <int>[];
    final failedMessages = <String>[];

    // 從第 1 列（index 1）開始，跳過第 0 列標題
    for (var rowIdx = 1; rowIdx < rows.length; rowIdx++) {
      try {
        final row = rows[rowIdx];

        // 全空白列跳過
        if (row.every((f) => f.trim().isEmpty)) {
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

  /// RFC 4180 CSV 解析器（支援引號欄位、雙引號跳脫、CRLF/LF）
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var fields = <String>[];
    var field = StringBuffer();
    var inQuotes = false;
    var i = 0;

    void commitField() {
      fields.add(field.toString());
      field = StringBuffer();
    }

    void commitRow() {
      commitField();
      rows.add(List.unmodifiable(fields));
      fields = [];
    }

    while (i < content.length) {
      final ch = content[i];

      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        switch (ch) {
          case '"':
            inQuotes = true;
          case ',':
            commitField();
          case '\r':
            commitRow();
            if (i + 1 < content.length && content[i + 1] == '\n') i++;
          case '\n':
            commitRow();
          default:
            field.write(ch);
        }
      }
      i++;
    }

    // 最後一行無換行符時
    if (fields.isNotEmpty || field.isNotEmpty) {
      commitRow();
    }

    return rows;
  }

  /// 解析單列為 MarkerEntity；驗證失敗拋出 LocalFailure
  MarkerEntity _parseRow(List<String> row, int rowIdx) {
    String? col(int idx) {
      if (idx >= row.length) return null;
      final s = row[idx].trim();
      return s.isNotEmpty ? s : null;
    }

    double? dbl(int idx) => double.tryParse(col(idx) ?? '');
    int? integer(int idx) {
      final s = col(idx);
      if (s == null) return null;
      return int.tryParse(s) ?? double.tryParse(s)?.toInt();
    }

    final displayRow = rowIdx + 1;
    // 顯示原始行摘要，方便診斷解析錯誤
    String rowSummary() {
      final preview = row.take(4).map((f) {
        final s = f.length > 20 ? '${f.substring(0, 20)}…' : f;
        return '「$s」';
      }).join(', ');
      return '共 ${row.length} 欄，前幾欄：$preview';
    }

    final title = col(_colTitle);
    if (title == null) throw LocalFailure('第 $displayRow 列：標題不得為空（${rowSummary()}）');

    final country = col(_colCountry);
    if (country == null) throw LocalFailure('第 $displayRow 列：國家不得為空（${rowSummary()}）');

    final lat = dbl(_colLat);
    if (lat == null || lat < -90 || lat > 90) {
      throw LocalFailure('第 $displayRow 列：緯度無效「${col(_colLat) ?? '空'}」（需介於 -90 ~ 90）');
    }

    final lng = dbl(_colLng);
    if (lng == null || lng < -180 || lng > 180) {
      throw LocalFailure('第 $displayRow 列：經度無效「${col(_colLng) ?? '空'}」（需介於 -180 ~ 180）');
    }

    final rating = integer(_colRating);
    if (rating == null || rating < 1 || rating > 5) {
      throw LocalFailure(
          '第 $displayRow 列：評分無效（需介於 1 ~ 5，目前為「${col(_colRating) ?? '空'}」）');
    }

    final rawId = col(_colId);
    final id = rawId ?? const Uuid().v4();

    final dateStr = col(_colDate);
    final createdAt = dateStr != null ? _parseDate(dateStr) : DateTime.now();

    final categoryStr = col(_colCategory) ?? 'attraction';
    final category = MarkerCategory.fromString(categoryStr).name;

    return MarkerEntity(
      id: id,
      title: title,
      country: country,
      createdAt: createdAt,
      latitude: lat,
      longitude: lng,
      rating: rating,
      note: col(_colNote) ?? '',
      photoPaths: const [],
      category: category,
    );
  }

  /// 支援 ISO `2024-03-15` 及 slash `2019/5/1` 兩種日期格式
  DateTime _parseDate(String s) {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final parts = s.split('/');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime.now();
  }
}
