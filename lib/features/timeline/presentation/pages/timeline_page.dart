import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/country_flag.dart';
import '../../../../core/widgets/weather_icon_widget.dart';
import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/pages/create_marker_page.dart';
import '../../../marker/presentation/pages/marker_detail_page.dart';
import '../../../marker/presentation/widgets/share_bottom_sheet.dart';
import '../../domain/entities/timeline_group_entity.dart';
import '../providers/timeline_provider.dart';

// ── 時間軸項目型別（sealed class）────────────────────────────────────────────────
//
// SliverList 需要一個扁平化的列表；用 sealed class 標記每個 item 的種類，
// 在 itemBuilder 中以 switch 分派對應的 Widget。

sealed class _Item {}

/// 年份標題列
class _YearItem extends _Item {
  _YearItem(this.year);
  final int year;
}

/// 月份標題列
class _MonthItem extends _Item {
  _MonthItem(this.group);
  final TimelineGroupEntity group;
}

/// 標記卡片列
class _CardItem extends _Item {
  _CardItem(this.marker);
  final MarkerEntity marker;
}

/// 將 [TimelineGroupEntity] 清單攤平為 SliverList 所需的扁平列表。
///
/// 年份切換時插入 [_YearItem]，每個月份分組前插入 [_MonthItem]，
/// 接著依序插入該月所有標記對應的 [_CardItem]。
List<_Item> _buildItems(List<TimelineGroupEntity> groups) {
  final items = <_Item>[];
  int? lastYear;
  for (final group in groups) {
    if (group.year != lastYear) {
      items.add(_YearItem(group.year));
      lastYear = group.year;
    }
    items.add(_MonthItem(group));
    for (final marker in group.markers) {
      items.add(_CardItem(marker));
    }
  }
  return items;
}

// ── 時間軸頁面 ────────────────────────────────────────────────────────────────────

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(timelineFilterProvider);
    final notifier = ref.read(timelineFilterProvider.notifier);

    return Scaffold(
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('載入失敗：$e',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(timelineFilterProvider),
                child: const Text('重試'),
              ),
            ],
          ),
        ),
        data: (groups) {
          final years = notifier.availableYears;
          final selectedYear = notifier.selectedYear;

          // 資料庫中完全沒有任何標記
          if (years.isEmpty) {
            return _EmptyState(
              onAdd: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateMarkerPage()),
                );
                ref.invalidate(timelineFilterProvider);
              },
            );
          }

          final items = _buildItems(groups);

          return CustomScrollView(
            slivers: [
              // ── 固定頂部 AppBar + 年份篩選 Chip 列 ──────────────────────────
              SliverAppBar(
                title: const Text('旅遊時間軸'),
                pinned: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: _YearFilterBar(
                    years: years,
                    selectedYear: selectedYear,
                    onChanged: (year) => ref
                        .read(timelineFilterProvider.notifier)
                        .filterByYear(year),
                  ),
                ),
              ),

              // ── 篩選年份後無資料 ─────────────────────────────────────────────
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '$selectedYear 年沒有旅遊紀錄',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = items[i];
                        return switch (item) {
                          _YearItem() => _YearHeader(year: item.year),
                          _MonthItem() => _MonthHeader(group: item.group),
                          _CardItem() => _MarkerCardRow(
                              marker: item.marker,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MarkerDetailPage(
                                        marker: item.marker),
                                  ),
                                );
                                // 從詳情頁返回後刷新（可能有編輯）
                                ref.invalidate(timelineFilterProvider);
                              },
                              onShare: () => showShareBottomSheet(
                                  context, item.marker),
                            ),
                        };
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 年份篩選 Chip 列 ──────────────────────────────────────────────────────────────

class _YearFilterBar extends StatelessWidget {
  const _YearFilterBar({
    required this.years,
    required this.selectedYear,
    required this.onChanged,
  });

  final List<int> years;
  final int? selectedYear;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 「全部」Chip — 選中時清除年份篩選
          _YearChip(
            label: '全部',
            isSelected: selectedYear == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          // 各年份 Chip，降序排列（最新年份在前）
          for (final year in years) ...[
            _YearChip(
              label: '$year',
              isSelected: selectedYear == year,
              onTap: () => onChanged(year),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// 單一年份 Chip，選中時以主題色填滿，未選中為 outline 樣式。
class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? cs.onPrimary : cs.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── 年份標題列 ────────────────────────────────────────────────────────────────────

/// 年份大標題列，左側軌道以直徑 16 的圓點標示年份節點。
class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(dotSize: 16, primaryColor: primary),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 0, 8),
              child: Text(
                '$year',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 月份標題列 ────────────────────────────────────────────────────────────────────

/// 月份標題列，含橫線分隔與標記數量。
/// 左側軌道無圓點（dotSize = 0），僅維持連接線的視覺連續性。
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.group});
  final TimelineGroupEntity group;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(dotSize: 0, primaryColor: primary),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 0, 8),
              child: Row(
                children: [
                  Text(
                    group.monthLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                  ),
                  const SizedBox(width: 8),
                  // 橫線分隔
                  Expanded(
                    child: Container(
                      height: 1,
                      color: primary.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${group.markerCount} 筆',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 標記卡片列（軌道 + 卡片）─────────────────────────────────────────────────────

/// 包含左側軌道（直徑 12 圓點）與右側標記卡片的完整列。
class _MarkerCardRow extends StatelessWidget {
  const _MarkerCardRow({
    required this.marker,
    required this.onTap,
    required this.onShare,
  });

  final MarkerEntity marker;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(dotSize: 12, primaryColor: primary),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
              child: _MarkerCard(marker: marker, onTap: onTap, onShare: onShare),
            ),
          ),
        ],
      ),
    );
  }
}

/// 標記卡片本體（Card + InkWell）。
class _MarkerCard extends StatelessWidget {
  const _MarkerCard({
    required this.marker,
    required this.onTap,
    required this.onShare,
  });

  final MarkerEntity marker;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final d = marker.createdAt;
    final dateStr =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側 60×60 縮圖
              _CardThumbnail(marker: marker),
              const SizedBox(width: 10),

              // 右側資訊欄
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題（粗體，單行截斷）
                    Text(
                      marker.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // 國旗 emoji + 國家名稱
                    Text(
                      '${countryFlag(marker.country)} ${marker.country}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 日期 + 天氣 icon（size 14）+ 氣溫
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: onSurfaceVariant),
                        ),
                        if (marker.weatherCondition != null) ...[
                          const SizedBox(width: 6),
                          WeatherIconWidget(
                            condition: marker.weatherCondition!,
                            size: 14,
                            showLabel: false,
                          ),
                          if (marker.temperature != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              '${marker.temperature}°C',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: onSurfaceVariant),
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 五星評分（小型，size 12）
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) => Icon(
                            i < marker.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < marker.rating
                                ? Colors.amber
                                : Colors.grey[400],
                            size: 12,
                          )),
                    ),
                  ],
                ),
              ),

              // 分享按鈕（小型，置右對齊頂部）
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.ios_share_outlined, size: 15),
                  onPressed: onShare,
                  tooltip: '分享',
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 卡片縮圖 ──────────────────────────────────────────────────────────────────────

/// 60×60 卡片縮圖；無照片時優先顯示天氣 icon，否則顯示地球 icon。
class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.marker});
  final MarkerEntity marker;

  @override
  Widget build(BuildContext context) {
    final photoPath =
        marker.photoPaths.isNotEmpty ? marker.photoPaths.first : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: photoPath != null && File(photoPath).existsSync()
            ? Image.file(
                File(photoPath),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                cacheWidth: 120,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: marker.weatherCondition != null
              ? WeatherIconWidget(
                  condition: marker.weatherCondition!,
                  size: 28,
                  showLabel: false,
                )
              : Icon(
                  Icons.public,
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
      );
}

// ── 時間軸軌道（左側線條 + 節點圓點）────────────────────────────────────────────

/// 時間軸左側軌道，寬度固定 56dp。
///
/// 使用 [Column] 分為三段（上線 / 圓點 / 下線），搭配父層 [IntrinsicHeight]
/// 確保線條貫穿整個列高。[dotSize] 為 0 時僅顯示連接線（月份標題列使用）。
class _Rail extends StatelessWidget {
  const _Rail({required this.dotSize, required this.primaryColor});

  final double dotSize;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final lineColor = primaryColor.withValues(alpha: 0.4);

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          // 上半段連接線
          Expanded(
            child: Center(child: Container(width: 2, color: lineColor)),
          ),

          // 節點圓點（dotSize == 0 時不渲染，月份標題列用此省略節點）
          if (dotSize > 0)
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
            ),

          // 下半段連接線
          Expanded(
            child: Center(child: Container(width: 2, color: lineColor)),
          ),
        ],
      ),
    );
  }
}

// ── 空白狀態 ──────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '尚無旅遊紀錄',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            '快來新增第一筆旅遊標記吧！',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('立即新增第一筆旅遊標記'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
