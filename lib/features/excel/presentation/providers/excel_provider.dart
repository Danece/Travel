import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database_helper.dart';
import '../../../marker/data/datasources/marker_local_datasource_impl.dart';
import '../../../marker/data/repositories/marker_repository_impl.dart';
import '../../../marker/presentation/providers/marker_provider.dart';
import '../../data/repositories/excel_repository_impl.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/usecases/export_to_excel.dart';
import '../../domain/usecases/import_from_excel.dart';
import '../../../marker/domain/entities/marker_entity.dart';

part 'excel_provider.g.dart';

// ── ExcelNotifier ─────────────────────────────────────────────────────────────
//
// state 型別：AsyncValue<void>
//   - AsyncData(null)：閒置（初始或操作完成）
//   - AsyncLoading()：匯出或匯入進行中
//   - AsyncError(e, st)：操作失敗

@riverpod
class ExcelNotifier extends _$ExcelNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // ── 匯出 ──────────────────────────────────────────────────────────────────

  /// 匯出目前所有地標至 xlsx，成功時回傳儲存路徑，失敗時更新 state 為 AsyncError
  Future<String?> export() async {
    state = const AsyncLoading();

    // 取得目前所有地標
    final markers = await _readAllMarkers();
    if (markers == null) return null; // 讀取失敗，state 已更新為 AsyncError

    final result = await AsyncValue.guard<String>(
      () => ExportToExcel(_buildRepo()).call(markers),
    );

    state = result.when(
      data: (_) => const AsyncData(null),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    );

    return result.valueOrNull;
  }

  // ── 匯入 ──────────────────────────────────────────────────────────────────

  /// 從 bytes 匯入 CSV，成功時回傳 ImportResult，失敗時更新 state 為 AsyncError
  Future<ImportResult?> import(Uint8List bytes) async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard<ImportResult>(
      () => ImportFromExcel(_buildRepo()).call(bytes),
    );

    // 匯入完成後通知 markerNotifier 刷新列表
    if (result is AsyncData) {
      ref.invalidate(markerNotifierProvider);
    }

    state = result.when(
      data: (_) => const AsyncData(null),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    );

    return result.valueOrNull;
  }

  // ── 私有輔助 ───────────────────────────────────────────────────────────────

  /// 建立注入了 MarkerRepository 的 ExcelRepositoryImpl
  ExcelRepositoryImpl _buildRepo() {
    final markerRepo = MarkerRepositoryImpl(
      MarkerLocalDatasourceImpl(DatabaseHelper.instance),
    );
    return ExcelRepositoryImpl(markerRepo);
  }

  /// 從 markerNotifierProvider 讀取所有地標；失敗時更新 state
  Future<List<MarkerEntity>?> _readAllMarkers() async {
    try {
      return await ref.read(markerNotifierProvider.future);
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
