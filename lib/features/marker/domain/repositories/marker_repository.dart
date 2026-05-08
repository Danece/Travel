import '../entities/marker_entity.dart';

abstract interface class MarkerRepository {
  Future<List<MarkerEntity>> getAllMarkers();
  Future<MarkerEntity?> getMarkerById(String id);
  Future<List<MarkerEntity>> searchMarkers({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
  });
  Future<void> insertMarker(MarkerEntity marker);
  Future<void> upsertMarker(MarkerEntity marker);
  Future<void> updateMarker(MarkerEntity marker);
  Future<void> deleteMarker(String id);
}
