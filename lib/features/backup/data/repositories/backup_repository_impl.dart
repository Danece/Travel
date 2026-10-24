import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' show ClientException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../domain/entities/backup_file_entity.dart';
import '../../domain/repositories/backup_repository.dart';

const _driveFolderName = 'TravelMark';
const _folderMime = 'application/vnd.google-apps.folder';
const _fileFields = 'id,name,size,createdTime';
const _maxBackups = 5;
const _kDbEntryName = 'travel_mark.db';
const _kPhotosPrefix = 'photos/';
const _maxDownloadRetries = 3;

class BackupRepositoryImpl implements BackupRepository {
  // ══════════════════════════════════════════════════════════════════════════
  // 建立備份
  // ══════════════════════════════════════════════════════════════════════════

  /// 流程：
  ///   1. 使用 ZipFileEncoder 逐檔壓縮至暫存 ZIP（不把所有照片載入記憶體）
  ///   2. 複製暫存 ZIP 到本機 Downloads
  ///   3. 從暫存 ZIP 串流上傳至 Drive（不把整個 ZIP 載入記憶體）
  ///   4. 刪除超過 _maxBackups 的舊備份
  ///   5. 清理暫存 ZIP
  @override
  Future<BackupFileEntity> createBackup() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateFolder(api);

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

    // 1. 逐檔壓縮到暫存 ZIP，不佔大量記憶體
    final tempZipPath = await _buildZipFile(fileName);

    try {
      // 2. 複製到本機 Downloads
      final localPath = await _copyToDownloads(tempZipPath, fileName);

      // 3. 從暫存 ZIP 串流上傳至 Drive
      final entity = await _uploadFromFile(api, folderId, tempZipPath, fileName);

      // 4. 保留最近 _maxBackups 份，刪除其餘舊檔
      await _pruneOldBackups(api, folderId);

      return entity.copyWith(localPath: localPath);
    } finally {
      // 5. 清理暫存 ZIP（成功或失敗皆執行）
      final tmp = File(tempZipPath);
      if (tmp.existsSync()) await tmp.delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 還原備份
  // ══════════════════════════════════════════════════════════════════════════

  /// 流程：
  ///   1. 串流下載 ZIP 至暫存檔（含重試，不把整個 ZIP 載入記憶體）
  ///   2. 從暫存檔解壓縮 DB 與照片
  ///   3. 清理暫存檔
  @override
  Future<void> restoreBackup(String fileId) async {
    final api = await _getDriveApi();

    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, 'restore_temp.zip');

    try {
      // 1. 串流下載至暫存檔（網路中斷時自動重試）
      await _downloadWithRetry(api, fileId, tempZipPath);

      // 2. 從暫存檔解壓縮
      // InputFileStream 是 lazy 讀取：decodeBuffer 只讀目錄結構，
      // file.content 才真正讀取各檔內容，因此 close() 必須在迴圈結束後才能呼叫。
      final inputStream = InputFileStream(tempZipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      await DatabaseHelper.instance.closeDatabase();
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final docsDir = await getApplicationDocumentsDirectory();

      try {
        for (final file in archive) {
          if (!file.isFile) continue;
          final data = file.content as List<int>;

          if (file.name == _kDbEntryName) {
            await File(dbPath).writeAsBytes(data);
          } else if (file.name.startsWith(_kPhotosPrefix)) {
            final photoPath = p.join(docsDir.path, file.name);
            await Directory(p.dirname(photoPath)).create(recursive: true);
            await File(photoPath).writeAsBytes(data);
          }
        }
      } finally {
        inputStream.close();
      }
    } finally {
      // 3. 清理暫存 ZIP
      final tmp = File(tempZipPath);
      if (tmp.existsSync()) await tmp.delete();
    }
  }

  /// 下載 Drive 檔案至本機路徑，失敗時最多重試 [_maxDownloadRetries] 次。
  /// 每先向 Metadata API 取得精確檔案大小，下載後逐次驗證是否完整。
  Future<void> _downloadWithRetry(
    drive.DriveApi api,
    String fileId,
    String destPath,
  ) async {
    // 預先取得 Drive 上的檔案大小（比 Content-Length 更可靠）
    final meta = await api.files.get(fileId, $fields: 'size') as drive.File;
    final expectedBytes = int.tryParse(meta.size ?? '');

    Object? lastError;

    for (var attempt = 0; attempt < _maxDownloadRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }

      try {
        final response = await api.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final sink = File(destPath).openWrite();
        try {
          await response.stream.pipe(sink);
        } catch (e) {
          await sink.close();
          rethrow;
        }

        // 用 metadata size 驗證（response.length 可能為 null）
        final knownSize = expectedBytes ?? response.length;
        if (knownSize != null) {
          final actualSize = await File(destPath).length();
          if (actualSize != knownSize) {
            throw ClientException(
              'Incomplete download: got $actualSize of $knownSize bytes',
            );
          }
        }

        return; // 下載成功
      } on ClientException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      }
    }

    throw lastError!;
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

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) throw const LocalFailure('請先登入 Google 帳號後再進行備份');
    return drive.DriveApi(client);
  }

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

    if (result.files?.isNotEmpty == true) return result.files!.first.id!;

    final folder = drive.File()
      ..name = _driveFolderName
      ..mimeType = _folderMime;
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  /// ZipFileEncoder 逐檔壓縮到暫存目錄，記憶體只需容納單一檔案
  /// DB → 存為 'travel_mark.db'；photos/ → 存為 'photos/filename'
  Future<String> _buildZipFile(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, fileName);

    final encoder = ZipFileEncoder();
    encoder.open(zipPath);

    try {
      // 加入主資料庫（basename = travel_mark.db）
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        encoder.addFile(dbFile);
      }

      // 加入 photos/ 資料夾（includeDirName: true → 壓縮為 photos/filename）
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(docsDir.path, 'photos'));
      if (photosDir.existsSync()) {
        encoder.addDirectory(photosDir, includeDirName: true);
      }
    } finally {
      encoder.close();
    }

    return zipPath;
  }

  /// 複製暫存 ZIP 到本機 Downloads，回傳目標路徑
  Future<String> _copyToDownloads(String srcPath, String fileName) async {
    final dir = (await getDownloadsDirectory()) ??
        await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) await dir.create(recursive: true);
    final destPath = p.join(dir.path, fileName);
    await File(srcPath).copy(destPath);
    return destPath;
  }

  /// 從本機 ZIP 檔串流上傳至 Drive，不需將整個檔案載入記憶體
  Future<BackupFileEntity> _uploadFromFile(
    drive.DriveApi api,
    String folderId,
    String zipPath,
    String fileName,
  ) async {
    final file = File(zipPath);
    final size = await file.length();

    final metadata = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(file.openRead(), size);

    final created = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: _fileFields,
    );

    return _toEntity(created);
  }

  Future<void> _pruneOldBackups(drive.DriveApi api, String folderId) async {
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

  BackupFileEntity _toEntity(drive.File file) => BackupFileEntity(
        id: file.id ?? '',
        name: file.name ?? '',
        sizeBytes: int.tryParse(file.size ?? ''),
        createdTime: file.createdTime ?? DateTime.now(),
      );
}
