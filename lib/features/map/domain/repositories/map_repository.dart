import '../../../marker/domain/entities/marker_entity.dart';

abstract interface class MapRepository {
  Future<List<MarkerEntity>> getMarkersForMap();
}
