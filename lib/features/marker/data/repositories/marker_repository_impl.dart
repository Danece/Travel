import '../../domain/entities/marker_entity.dart';
import '../../domain/repositories/marker_repository.dart';
import '../datasources/marker_local_datasource.dart';
import '../models/marker_model.dart';

class MarkerRepositoryImpl implements MarkerRepository {
  const MarkerRepositoryImpl(this._datasource);
  final MarkerLocalDatasource _datasource;

  @override
  Future<List<MarkerEntity>> getAllMarkers() async {
    final models = await _datasource.getAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<MarkerEntity?> getMarkerById(String id) async {
    final model = await _datasource.getById(id);
    return model?.toEntity();
  }

  @override
  Future<List<MarkerEntity>> searchMarkers({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
  }) async {
    final models = await _datasource.search(
      title: title,
      countries: countries,
      minRating: minRating,
      startDate: startDate,
      endDate: endDate,
      categories: categories,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> insertMarker(MarkerEntity marker) =>
      _datasource.insert(MarkerModel.fromEntity(marker));

  @override
  Future<void> upsertMarker(MarkerEntity marker) =>
      _datasource.upsert(MarkerModel.fromEntity(marker));

  @override
  Future<void> updateMarker(MarkerEntity marker) =>
      _datasource.update(MarkerModel.fromEntity(marker));

  @override
  Future<void> deleteMarker(String id) => _datasource.delete(id);
}
