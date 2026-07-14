import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../marker/presentation/providers/marker_provider.dart';
import '../../domain/entities/timeline_group_entity.dart';
import '../../domain/usecases/get_timeline_groups.dart';

// ── 1. timelineGroupsProvider ─────────────────────────────────────────────────
//
// 一次性讀取全部標記並分組，適合只需要讀取而不需要篩選的場合。
// 需要篩選功能時請改用 [timelineFilterProvider]。

/// 取得所有標記並依年月分組的 FutureProvider。
///
/// 年份降序、月份降序，同月內標記依日期降序。
final timelineGroupsProvider =
    FutureProvider<List<TimelineGroupEntity>>((ref) async {
  final repo = ref.watch(markerRepositoryProvider);
  return GetTimelineGroups(repo).call();
});

// ── 2. TimelineFilterNotifier ─────────────────────────────────────────────────
//
// 支援年份篩選的 AsyncNotifier。
//
// 狀態（state）為篩選後的分組列表；完整原始清單保存在 [_allGroups]，
// 供 [availableYears] 與重設篩選時使用。

/// 支援年份篩選的時間軸狀態管理器。
class TimelineFilterNotifier
    extends AsyncNotifier<List<TimelineGroupEntity>> {
  /// 完整的未篩選分組列表，由 [build] 載入後保存。
  List<TimelineGroupEntity> _allGroups = [];

  /// 目前篩選的年份；null 表示顯示全部年份。
  int? _selectedYear;

  @override
  Future<List<TimelineGroupEntity>> build() async {
    final repo = ref.watch(markerRepositoryProvider);
    _allGroups = await GetTimelineGroups(repo).call();
    _selectedYear = null; // 重建時重設篩選狀態
    return _allGroups;
  }

  /// 篩選特定年份的分組。
  ///
  /// [year] 為 null 時清除篩選，顯示全部年份。
  /// 直接更新 [state]，不重新呼叫 API。
  void filterByYear(int? year) {
    _selectedYear = year;
    state = AsyncData(
      year == null
          ? _allGroups
          : _allGroups.where((g) => g.year == year).toList(),
    );
  }

  /// 資料中所有有標記的年份，降序排列（最新年份在前）。
  ///
  /// 在 [build] 完成前回傳空列表；UI 層應在 [state] 為
  /// [AsyncData] 後再讀取此值。
  List<int> get availableYears => _allGroups
      .map((g) => g.year)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  /// 目前選取的篩選年份（null 表示全部）。
  int? get selectedYear => _selectedYear;
}

// ── 3. timelineFilterProvider ─────────────────────────────────────────────────

/// 提供 [TimelineFilterNotifier] 的 AsyncNotifierProvider。
///
/// 使用方式：
/// ```dart
/// // 監聽篩選後的分組列表
/// final groups = ref.watch(timelineFilterProvider);
///
/// // 篩選特定年份
/// ref.read(timelineFilterProvider.notifier).filterByYear(2024);
///
/// // 取得所有可篩選年份
/// final years = ref.read(timelineFilterProvider.notifier).availableYears;
/// ```
final timelineFilterProvider = AsyncNotifierProvider<TimelineFilterNotifier,
    List<TimelineGroupEntity>>(
  TimelineFilterNotifier.new,
);
