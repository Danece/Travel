import '../entities/marker_entity.dart';

abstract interface class MarkerRepository {
  Future<List<MarkerEntity>> getAllMarkers();
  Future<MarkerEntity?> getMarkerById(String id);
  Future<List<MarkerEntity>> searchMarkers({
    String? title,
    String? country,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> insertMarker(MarkerEntity marker);
  Future<void> updateMarker(MarkerEntity marker);
  Future<void> deleteMarker(String id);
}
