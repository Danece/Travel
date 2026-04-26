import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/providers/marker_provider.dart';
import '../providers/home_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppShell — 底部導覽列的持久容器
// ══════════════════════════════════════════════════════════════════════════════
//
// 搭配 app_router.dart 的 ShellRoute 使用。
// Shell 負責渲染底部 NavigationBar，child 是各分頁的 Scaffold。
// 這樣切換分頁時 NavigationBar 不會重建，避免視覺閃爍。

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  // 路由路徑 → NavigationBar 的 selectedIndex 對應表
  static int _locationToIndex(String location) {
    if (location.startsWith('/marker')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0; // 首頁
  }

  // selectedIndex → 要跳轉的路由路徑
  static String _indexToLocation(int index) {
    switch (index) {
      case 1:
        return '/marker';
      case 2:
        return '/map';
      case 3:
        return '/settings';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 從 GoRouterState 取得當前路徑，決定高亮的分頁
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_indexToLocation(i)),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首頁',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: '標記',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地圖',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HomePage — 首頁內容
// ══════════════════════════════════════════════════════════════════════════════
//
// 結構：
//   1. 統計卡片   — GridView（crossAxisCount: 2）三張藍色漸層卡片
//   2. 最近新增   — 水平 PageView 顯示最近 5 筆標記
//   3. 快速入口   — 三個大按鈕：新增標記 / 查詢紀錄 / 開啟地圖

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(travelSummaryProvider);
    final markersAsync = ref.watch(markerNotifierProvider);

    return Scaffold(
      // 無 AppBar：頂部由內容區的 Header 替代，畫面更沉浸
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('載入失敗：$e')),
          data: (summary) {
            // 取最近 5 筆標記（依建立時間降冪）
            final recentMarkers = markersAsync.when(
              data: (list) {
                final sorted = [...list]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return sorted.take(5).toList();
              },
              loading: () => <MarkerEntity>[],
              error: (_, __) => <MarkerEntity>[],
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                // ── Header 問候區 ──────────────────────────────────────────
                _Header(),
                const SizedBox(height: 24),

                // ── 1. 統計卡片 ────────────────────────────────────────────
                _SectionTitle('統計概覽'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _StatCard(
                      icon: Icons.place,
                      value: '${summary.totalMarkers}',
                      unit: '筆',
                      label: '旅遊足跡',
                      gradientColors: const [
                        Color(0xFF1565C0),
                        Color(0xFF1E88E5),
                      ],
                    ),
                    _StatCard(
                      icon: Icons.flag,
                      value: '${summary.totalCountries}',
                      unit: '個',
                      label: '造訪國家',
                      gradientColors: const [
                        Color(0xFF283593),
                        Color(0xFF3949AB),
                      ],
                    ),
                    _StatCard(
                      icon: Icons.star,
                      value: summary.averageRating > 0
                          ? summary.averageRating.toStringAsFixed(1)
                          : '--',
                      unit: '',
                      label: '平均評分',
                      prefix: summary.averageRating > 0 ? '★ ' : '',
                      gradientColors: const [
                        Color(0xFF00695C),
                        Color(0xFF00897B),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── 2. 最近新增 ────────────────────────────────────────────
                Row(
                  children: [
                    _SectionTitle('最近新增'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/marker'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '查看全部',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: recentMarkers.isEmpty
                      ? _EmptyRecentCard()
                      : PageView.builder(
                          padEnds: false,
                          controller: PageController(viewportFraction: 0.88),
                          itemCount: recentMarkers.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _RecentMarkerCard(
                              marker: recentMarkers[i],
                              onTap: () => context.push(
                                '/marker/${recentMarkers[i].id}',
                                extra: recentMarkers[i],
                              ),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 28),

                // ── 3. 快速入口 ────────────────────────────────────────────
                _SectionTitle('快速入口'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.add_location_alt_outlined,
                        label: '新增標記',
                        onTap: () => context.push('/marker/create'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.search_outlined,
                        label: '查詢紀錄',
                        onTap: () => context.go('/marker'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.map_outlined,
                        label: '開啟地圖',
                        onTap: () => context.go('/map'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 私有元件
// ══════════════════════════════════════════════════════════════════════════════

// ── Header：問候語 ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travel Mark',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '記錄每一段珍貴旅程',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.travel_explore,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

// ── 區塊標題 ────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// ── 統計卡片 ────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.gradientColors,
    this.prefix = '',
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final String prefix;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 圖示
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
          // 數值
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: '$prefix$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
          // 標籤
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 最近新增：標記卡片 ──────────────────────────────────────────────────────────

class _RecentMarkerCard extends StatelessWidget {
  const _RecentMarkerCard({required this.marker, required this.onTap});

  final MarkerEntity marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = marker.photoPaths.isNotEmpty;
    final firstPhoto = hasPhoto ? marker.photoPaths.first : null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 背景：照片或漸層 ─────────────────────────────────────────
            if (firstPhoto != null && File(firstPhoto).existsSync())
              Image.file(
                File(firstPhoto),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultBackground(),
              )
            else
              _defaultBackground(),

            // ── 底部漸層遮罩 ─────────────────────────────────────────────
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),

            // ── 文字內容 ─────────────────────────────────────────────────
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    marker.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          marker.country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      _StarRow(rating: marker.rating),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 無照片時的預設深藍漸層背景
  Widget _defaultBackground() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ── 評分星號列（唯讀）──────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_outline,
          color: Colors.amber,
          size: 12,
        ),
      ),
    );
  }
}

// ── 無最近紀錄時的佔位元件 ──────────────────────────────────────────────────────

class _EmptyRecentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          Text(
            '尚無旅遊紀錄',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '點擊「新增標記」開始記錄旅程',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── 快速入口按鈕 ────────────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
