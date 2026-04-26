import '../entities/backup_file_entity.dart';
import '../repositories/backup_repository.dart';

class GetBackupList {
  const GetBackupList(this._repository);
  final BackupRepository _repository;

  Future<List<BackupFileEntity>> call() => _repository.getBackupList();
}
