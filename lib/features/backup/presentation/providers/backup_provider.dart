import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/google_auth_service.dart';
import '../../../marker/presentation/providers/marker_provider.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/entities/backup_file_entity.dart';
import '../../domain/usecases/create_backup.dart';
import '../../domain/usecases/delete_backup.dart';
import '../../domain/usecases/get_backup_list.dart';
import '../../domain/usecases/restore_backup.dart';

part 'backup_provider.g.dart';

// ── BackupNotifier ────────────────────────────────────────────────────────────
//
// state 型別：AsyncValue<List<BackupFileEntity>>
//   - AsyncData([])         ：未登入或尚無備份
//   - AsyncData([...])      ：備份清單已載入
//   - AsyncLoading()        ：清單載入中 or 操作進行中
//   - AsyncError(e, st)     ：操作失敗

@riverpod
class BackupNotifier extends _$BackupNotifier {
  BackupRepositoryImpl get _repo => BackupRepositoryImpl();

  // ── 初始化：靜默登入 + 載入清單 ────────────────────────────────────────────

  @override
  Future<List<BackupFileEntity>> build() async {
    // 嘗試恢復上次登入（不跳出互動介面）
    await GoogleAuthService.instance.signInSilently();

    if (!GoogleAuthService.instance.isSignedIn) return const [];

    return GetBackupList(_repo).call();
  }

  // ── Google 帳號管理 ─────────────────────────────────────────────────────────

  /// 互動式 Google 登入，成功後重新載入備份清單
  Future<bool> signIn() async {
    final account = await GoogleAuthService.instance.signIn();
    if (account == null) return false;
    ref.invalidateSelf();
    return true;
  }

  /// 登出 Google，清空備份清單
  Future<void> signOut() async {
    await GoogleAuthService.instance.signOut();
    state = const AsyncData([]);
  }

  // ── 建立備份 ────────────────────────────────────────────────────────────────

  /// 壓縮並上傳至 Drive，成功時回傳備份名稱供 UI 顯示
  Future<String?> createBackup() async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard<BackupFileEntity>(
      () => CreateBackup(_repo).call(),
    );

    // 不論成功或失敗，重新載入清單（成功時清單有新項目）
    await _refreshList();

    if (result case AsyncError(:final error, :final stackTrace)) {
      state = AsyncError(error, stackTrace);
      return null;
    }

    return result.valueOrNull?.name;
  }

  // ── 還原備份 ────────────────────────────────────────────────────────────────

  /// 下載並還原指定 [fileId] 的備份，成功後刷新地標列表
  Future<bool> restore(String fileId) async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard<void>(
      () => RestoreBackup(_repo).call(fileId),
    );

    if (result is AsyncData) {
      // 通知地標 Provider 重新從新 DB 讀取資料
      ref.invalidate(markerNotifierProvider);
      await _refreshList();
      return true;
    }

    if (result case AsyncError(:final error, :final stackTrace)) {
      state = AsyncError(error, stackTrace);
    }
    return false;
  }

  // ── 刪除備份 ────────────────────────────────────────────────────────────────

  /// 刪除 Drive 上指定 [fileId] 的備份
  Future<bool> deleteBackup(String fileId) async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard<void>(
      () => DeleteBackup(_repo).call(fileId),
    );

    await _refreshList();

    if (result case AsyncError(:final error, :final stackTrace)) {
      state = AsyncError(error, stackTrace);
      return false;
    }

    return true;
  }

  // ── 私有輔助 ────────────────────────────────────────────────────────────────

  Future<void> _refreshList() async {
    try {
      final list = await GetBackupList(_repo).call();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
