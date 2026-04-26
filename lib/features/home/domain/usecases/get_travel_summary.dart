import '../entities/travel_summary_entity.dart';
import '../repositories/home_repository.dart';

class GetTravelSummary {
  const GetTravelSummary(this._repository);
  final HomeRepository _repository;

  Future<TravelSummaryEntity> call() => _repository.getTravelSummary();
}
