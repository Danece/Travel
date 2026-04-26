import '../repositories/marker_repository.dart';

class DeleteMarker {
  const DeleteMarker(this._repository);
  final MarkerRepository _repository;

  Future<void> call(String id) => _repository.deleteMarker(id);
}
