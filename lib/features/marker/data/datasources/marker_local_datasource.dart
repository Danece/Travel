import '../models/marker_model.dart';

abstract interface class MarkerLocalDatasource {
  Future<List<MarkerModel>> getAll();
  Future<MarkerModel?> getById(String id);
  Future<List<MarkerModel>> search({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
  });
  Future<void> insert(MarkerModel model);
  Future<void> upsert(MarkerModel model);
  Future<void> update(MarkerModel model);
  Future<void> delete(String id);
}
