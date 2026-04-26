import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/providers/marker_provider.dart';

part 'map_provider.g.dart';

// 直接監聽 markerNotifierProvider.future，確保地圖與列表頁的資料完全同步，
// 避免重複查詢資料庫
@riverpod
Future<List<MarkerEntity>> mapMarkers(Ref ref) async {
  return ref.watch(markerNotifierProvider.future);
}
