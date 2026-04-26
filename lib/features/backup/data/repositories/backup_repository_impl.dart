import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../domain/entities/backup_file_entity.dart';
import '../../domain/repositories/backup_repository.dart';

// ── 常數 ──────────────────────────────────────────────────────────────────────

/// Drive 上用來存放備份的資料夾名稱
const _driveFolderName = 'TravelMark';

/// Drive 資料夾的 MIME Type
const _folderMime = 'application/vnd.google-apps.folder';

/// Drive 查詢時要求回傳的欄位
const _fileFields = 'id,name,size,createdTime';

/// 每次上傳後保留的最多備份數量
const _maxBackups = 5;

class BackupRepositoryImpl implements BackupRepository {
  // ══════════════════════════════════════════════════════════════════════════
  // 建立備份
  // ══════════════════════════════════════════════════════════════════════════

  /// 流程：
  ///   1. 取得已驗證的 Drive API
  ///   2. 找到（或建立）TravelMark 資料夾
  ///   3. 壓縮 DB + photos/ 成 ZIP
  ///   4. 上傳 ZIP 到 Drive
  ///   5. 刪除超過 _maxBackups 的舊備份
  @override
  Future<BackupFileEntity> createBackup() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateFolder(api);

    // 組裝 ZIP 位元組
    final zipBytes = await _buildZip();

    // 以時間戳建立檔名
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final fileName = 'backup_$stamp.zip';

    // 上傳
    final entity = await _uploadFile(api, folderId, zipBytes, fileName);

    // 保留最近 _maxBackups 份，刪除其餘舊檔
    await _pruneOldBackups(api, folderId);

    return entity;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 還原備份
  // ══════════════════════════════════════════════════════════════════════════

  /// 流程：
  ///   1. 從 Drive 下載指定 fileId 的 ZIP
  ///   2. 解壓縮
  ///   3. 關閉 DB → 覆蓋 DB 檔案 → 恢復連線
  ///   4. 覆寫 photos/ 照片
  @override
  Future<void> restoreBackup(String fileId) async {
    final api = await _getDriveApi();

    // 下載 ZIP bytes
    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <int>[];
    await response.stream.forEach(chunks.addAll);
    final archive = ZipDecoder().decodeBytes(Uint8List.fromList(chunks));

    // 關閉 DB 連線，讓檔案可被覆寫
    await DatabaseHelper.instance.closeDatabase();

    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final docsDir = await getApplicationDocumentsDirectory();

    for (final file in archive) {
      if (!file.isFile) continue;

      final data = file.content as List<int>;

      if (file.name == 'travel_mark.db') {
        // 還原主資料庫
        await File(dbPath).writeAsBytes(data);
      } else if (file.name.startsWith('photos/')) {
        // 還原照片（保留相對路徑結構）
        final photoPath = p.join(docsDir.path, file.name);
        await Directory(p.dirname(photoPath)).create(recursive: true);
        await File(photoPath).writeAsBytes(data);
      }
    }
    // DB 連線會在下次 DatabaseHelper.instance.database 呼叫時自動重建
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 取得備份清單
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<BackupFileEntity>> getBackupList() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateFolder(api);

    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files($_fileFields)',
    );

    return (result.files ?? []).map(_toEntity).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 刪除備份
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> deleteBackup(String fileId) async {
    final api = await _getDriveApi();
    await api.files.delete(fileId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 私有輔助方法
  // ══════════════════════════════════════════════════════════════════════════

  /// 取得已驗證的 DriveApi；未登入時拋出 [LocalFailure]
  Future<drive.DriveApi> _getDriveApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) {
      throw const LocalFailure('請先登入 Google 帳號後再進行備份');
    }
    return drive.DriveApi(client);
  }

  /// 取得（或建立）Drive 上的 TravelMark 資料夾，回傳資料夾 ID
  Future<String> _getOrCreateFolder(drive.DriveApi api) async {
    final q =
        'name = \'$_driveFolderName\' '
        'and mimeType = \'$_folderMime\' '
        'and trashed = false';

    final result = await api.files.list(
      q: q,
      spaces: 'drive',
      $fields: 'files(id)',
    );

    if (result.files?.isNotEmpty == true) {
      return result.files!.first.id!;
    }

    // 資料夾不存在，建立一個
    final folder = drive.File()
      ..name = _driveFolderName
      ..mimeType = _folderMime;

    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  /// 壓縮本機 DB + photos/ 資料夾成 ZIP，回傳位元組陣列
  Future<List<int>> _buildZip() async {
    final archive = Archive();

    // ── 加入主資料庫 ──────────────────────────────────────────────────────
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      final bytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('travel_mark.db', bytes.length, bytes));
    }

    // ── 加入 photos/ 資料夾內所有照片 ─────────────────────────────────────
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    if (photosDir.existsSync()) {
      for (final entity in photosDir.listSync()) {
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        final name = p.basename(entity.path);
        archive.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw const LocalFailure('ZIP 壓縮失敗，請重試');
    return encoded;
  }

  /// 上傳 ZIP 到指定資料夾，回傳 BackupFileEntity
  Future<BackupFileEntity> _uploadFile(
    drive.DriveApi api,
    String folderId,
    List<int> zipBytes,
    String fileName,
  ) async {
    final metadata = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(
      Stream.fromIterable([zipBytes]),
      zipBytes.length,
    );

    final created = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: _fileFields,
    );

    return _toEntity(created);
  }

  /// 保留最新 _maxBackups 份，刪除多餘的舊備份
  Future<void> _pruneOldBackups(
    drive.DriveApi api,
    String folderId,
  ) async {
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id)',
    );

    final files = result.files ?? [];
    if (files.length <= _maxBackups) return;

    for (final file in files.skip(_maxBackups)) {
      await api.files.delete(file.id!);
    }
  }

  /// 將 Drive File 物件轉為 BackupFileEntity
  BackupFileEntity _toEntity(drive.File file) => BackupFileEntity(
        id: file.id ?? '',
        name: file.name ?? '',
        sizeBytes: int.tryParse(file.size ?? ''),
        createdTime: file.createdTime ?? DateTime.now(),
      );
}
