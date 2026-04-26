import '../entities/travel_summary_entity.dart';

abstract interface class HomeRepository {
  Future<TravelSummaryEntity> getTravelSummary();
}
