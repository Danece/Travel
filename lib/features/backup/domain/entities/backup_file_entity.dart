class BackupFileEntity {
  const BackupFileEntity({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdTime,
    this.localPath,
  });

  final String id;
  final String name;
  final int? sizeBytes;
  final DateTime createdTime;

  /// 本機儲存路徑（僅在剛建立備份時有值；從清單讀取的項目為 null）
  final String? localPath;

  BackupFileEntity copyWith({String? localPath}) => BackupFileEntity(
        id: id,
        name: name,
        sizeBytes: sizeBytes,
        createdTime: createdTime,
        localPath: localPath ?? this.localPath,
      );
}
