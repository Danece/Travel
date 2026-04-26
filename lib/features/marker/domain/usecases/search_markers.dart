import '../entities/marker_entity.dart';
import '../repositories/marker_repository.dart';

class SearchMarkers {
  const SearchMarkers(this._repository);
  final MarkerRepository _repository;

  Future<List<MarkerEntity>> call({
    String? title,
    String? country,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _repository.searchMarkers(
        title: title,
        country: country,
        minRating: minRating,
        startDate: startDate,
        endDate: endDate,
      );
}
