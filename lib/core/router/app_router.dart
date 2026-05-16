import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/backup/presentation/pages/backup_page.dart';
import '../../features/excel/presentation/pages/excel_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/marker/domain/entities/marker_entity.dart';
import '../../features/marker/presentation/pages/create_marker_page.dart';
import '../../features/marker/presentation/pages/marker_detail_page.dart';
import '../../features/marker/presentation/pages/marker_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

part 'app_router.g.dart';

// ── appRouterProvider ─────────────────────────────────────────────────────────
//
// 路由架構分兩層：
//
//   ShellRoute（底部導覽列 Shell）
//   ├── /           → HomePage        首頁
//   ├── /marker     → MarkerPage      標記列表
//   ├── /map        → MapPage         地圖
//   └── /settings   → SettingsPage    設定
//
//   獨立路由（無底部導覽列）
//   ├── /marker/create  → CreateMarkerPage  新增標記
//   ├── /marker/:id     → MarkerDetailPage  標記詳情
//   ├── /excel          → ExcelPage         匯出匯入
//   └── /backup         → BackupPage        備份還原

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      // ── 啟動動畫（無底部導覽列，直接跳轉到 /）─────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashPage()),
      ),

      // ── Shell：持有底部導覽列的父層 Scaffold ─────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(path: '/marker', builder: (_, __) => const MarkerPage()),
          GoRoute(path: '/map', builder: (_, __) => const MapPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),

      // ── 獨立路由（跳出 Shell，無底部導覽列）────────────────────────────────

      // 新增標記（從首頁快速入口或標記列表 FAB 觸發）
      GoRoute(
        path: '/marker/create',
        builder: (_, __) => const CreateMarkerPage(),
      ),

      // 標記詳情（透過 state.extra 傳遞 MarkerEntity，避免重新查詢 DB）
      GoRoute(
        path: '/marker/:id',
        builder: (_, state) {
          final marker = state.extra! as MarkerEntity;
          return MarkerDetailPage(marker: marker);
        },
      ),

      // Excel 匯出／匯入（從設定頁入口進入）
      GoRoute(path: '/excel', builder: (_, __) => const ExcelPage()),

      // 備份與還原（從設定頁入口進入）
      GoRoute(path: '/backup', builder: (_, __) => const BackupPage()),
    ],
  );
}
