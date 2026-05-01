import '../entities/marker_entity.dart';
import '../repositories/marker_repository.dart';

class SearchMarkers {
  const SearchMarkers(this._repository);
  final MarkerRepository _repository;

  Future<List<MarkerEntity>> call({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _repository.searchMarkers(
        title: title,
        countries: countries,
        minRating: minRating,
        startDate: startDate,
        endDate: endDate,
      );
}
