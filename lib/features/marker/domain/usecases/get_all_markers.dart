import '../entities/marker_entity.dart';
import '../repositories/marker_repository.dart';

class GetAllMarkers {
  const GetAllMarkers(this._repository);
  final MarkerRepository _repository;

  Future<List<MarkerEntity>> call() => _repository.getAllMarkers();
}
