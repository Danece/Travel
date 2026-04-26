// ── BackupFileEntity ──────────────────────────────────────────────────────────
//
// 代表 Google Drive 上單一備份檔案的資訊。

class BackupFileEntity {
  const BackupFileEntity({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdTime,
  });

  /// Drive 檔案 ID（用於下載 / 刪除）
  final String id;

  /// 檔案名稱（例：backup_20240415_143022.zip）
  final String name;

  /// 檔案大小（bytes）；Drive API 有時不回傳此欄位則為 null
  final int? sizeBytes;

  /// 備份建立時間
  final DateTime createdTime;
}
