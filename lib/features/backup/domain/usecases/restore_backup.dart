import '../repositories/backup_repository.dart';

class RestoreBackup {
  const RestoreBackup(this._repository);
  final BackupRepository _repository;

  Future<void> call(String fileId) => _repository.restoreBackup(fileId);
}
