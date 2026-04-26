import '../entities/backup_file_entity.dart';

abstract interface class BackupRepository {
  /// 壓縮 DB + photos/ 並上傳至 Google Drive，回傳備份檔資訊
  Future<BackupFileEntity> createBackup();

  /// 從 Drive 下載指定 [fileId] 的 ZIP 並還原 DB 與照片
  Future<void> restoreBackup(String fileId);

  /// 取得 Drive 上的備份檔案清單（依建立時間降冪排列）
  Future<List<BackupFileEntity>> getBackupList();

  /// 刪除 Drive 上指定 [fileId] 的備份
  Future<void> deleteBackup(String fileId);
}
