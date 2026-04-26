import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database_helper.dart';
import '../../../marker/presentation/providers/marker_provider.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/travel_summary_entity.dart';
import '../../domain/usecases/get_travel_summary.dart';

part 'home_provider.g.dart';

// ── travelSummaryProvider ─────────────────────────────────────────────────────
//
// 監聽 markerNotifierProvider 的狀態變更，
// 當地標資料更新時自動重新計算統計摘要。

@riverpod
Future<TravelSummaryEntity> travelSummary(TravelSummaryRef ref) async {
  // 訂閱地標列表；任何 CRUD 操作後此 provider 都會重新執行
  ref.watch(markerNotifierProvider);

  final usecase = GetTravelSummary(
    HomeRepositoryImpl(DatabaseHelper.instance),
  );
  return usecase();
}
