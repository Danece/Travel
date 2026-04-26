import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/domain/repositories/marker_repository.dart';
import '../../domain/repositories/map_repository.dart';

// 注入 MarkerRepository，直接委派給 getAllMarkers()，
// 確保地圖資料與地標列表使用同一底層資料來源
class MapRepositoryImpl implements MapRepository {
  const MapRepositoryImpl(this._markerRepository);

  final MarkerRepository _markerRepository;

  @override
  Future<List<MarkerEntity>> getMarkersForMap() =>
      _markerRepository.getAllMarkers();
}
