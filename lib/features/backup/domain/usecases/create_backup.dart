import '../entities/backup_file_entity.dart';
import '../repositories/backup_repository.dart';

class CreateBackup {
  const CreateBackup(this._repository);
  final BackupRepository _repository;

  Future<BackupFileEntity> call() => _repository.createBackup();
}
