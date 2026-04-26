import '../repositories/backup_repository.dart';

class DeleteBackup {
  const DeleteBackup(this._repository);
  final BackupRepository _repository;

  Future<void> call(String fileId) => _repository.deleteBackup(fileId);
}
