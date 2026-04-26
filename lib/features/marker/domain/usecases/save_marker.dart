import '../entities/marker_entity.dart';
import '../repositories/marker_repository.dart';

class SaveMarker {
  const SaveMarker(this._repository);
  final MarkerRepository _repository;

  Future<void> call(MarkerEntity marker) => _repository.insertMarker(marker);
}
