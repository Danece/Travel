import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/marker_entity.dart';
import '../providers/marker_provider.dart';
import 'create_marker_page.dart';
import 'marker_detail_page.dart';

// ── 地標列表頁 ────────────────────────────────────────────────────────────────
//
// 頁面結構：
//   1. 頂部搜尋欄（TextField，onChange 即時搜尋）
//   2. 水平 FilterChip 列（國家、評分、日期區間）
//   3. RefreshIndicator + ListView（Card + Dismissible）
//   4. FAB 新增地標

class MarkerPage extends ConsumerStatefulWidget {
  const MarkerPage({super.key});

  @override
  ConsumerState<MarkerPage> createState() => _MarkerPageState();
}

class _MarkerPageState extends ConsumerState<MarkerPage> {
  // ── 搜尋狀態 ───────────────────────────────────────────────────────────────
  final _searchController = TextEditingController();

  // ── 篩選狀態 ───────────────────────────────────────────────────────────────
  /// 目前選取的國家清單（空表示不篩選）
  Set<String> _selectedCountries = {};

  /// 最低評分篩選（null 表示不篩選）
  int? _minRating;

  /// 日期區間篩選（null 表示不篩選）
  DateTimeRange? _dateRange;

  // ── 生命週期 ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 搜尋文字變更時即時觸發搜尋
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── 工具方法 ───────────────────────────────────────────────────────────────

  /// 將 DateTime 格式化為 yyyy/MM/dd
  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  /// 是否有任一篩選條件啟用
  bool get _hasFilter =>
      _selectedCountries.isNotEmpty ||
      _minRating != null ||
      _dateRange != null;

  // ── 搜尋與篩選觸發 ────────────────────────────────────────────────────────

  /// 搜尋文字變更時呼叫，合併目前篩選條件一起送出
  void _onSearchChanged() => _applySearch();

  /// 統一入口：將所有篩選條件傳給 notifier.search()
  Future<void> _applySearch() async {
    await ref.read(markerNotifierProvider.notifier).search(
          title: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          // 多選國家目前 notifier 只接受單一 String，
          // 若僅選一個國家則傳入，多選時暫不篩選（後續可擴充）
          country: _selectedCountries.length == 1
              ? _selectedCountries.first
              : null,
          minRating: _minRating,
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        );
  }

  /// 清除所有篩選條件並重新搜尋
  Future<void> _clearFilters() async {
    setState(() {
      _selectedCountries = {};
      _minRating = null;
      _dateRange = null;
    });
    await _applySearch();
  }

  // ── 篩選對話框 ────────────────────────────────────────────────────────────

  /// 國家多選對話框（從目前所有地標取出不重複的國家清單）
  Future<void> _showCountryDialog(List<MarkerEntity> allMarkers) async {
    // 從現有地標取出所有不重複國家，排序後展示
    final countries = allMarkers.map((m) => m.country).toSet().toList()..sort();
    if (countries.isEmpty) return;

    // 暫存選取狀態（對話框內的臨時副本，確認才套用）
    var tempSelected = Set<String>.from(_selectedCountries);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('篩選國家'),
          // 讓對話框可捲動（國家清單可能很長）
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: countries.map((c) {
                return CheckboxListTile(
                  title: Text(c),
                  value: tempSelected.contains(c),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(c);
                      } else {
                        tempSelected.remove(c);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('確認'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _selectedCountries = tempSelected);
    await _applySearch();
  }

  /// 評分篩選對話框（SimpleDialog 選最低評分 1–5 星）
  Future<void> _showRatingDialog() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('最低評分'),
        children: List.generate(5, (i) {
          final stars = i + 1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, stars),
            child: Row(
              children: [
                // 顯示對應數量的實心星星
                ...List.generate(
                  stars,
                  (_) => const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 8),
                Text('$stars 星以上'),
              ],
            ),
          );
        }),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _minRating = picked);
    await _applySearch();
  }

  /// 日期區間篩選（showDateRangePicker）
  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: '選擇拜訪日期區間',
      confirmText: '確認',
      cancelText: '取消',
      saveText: '確認',
    );

    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
    await _applySearch();
  }

  // ── 下拉刷新 ──────────────────────────────────────────────────────────────

  /// 下拉刷新：重置搜尋條件，重新載入全部資料
  Future<void> _onRefresh() async {
    _searchController.clear();
    await _clearFilters();
  }

  // ── 建構 UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final markersAsync = ref.watch(markerNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('旅遊地標')),
      body: Column(
        children: [
          // ── 搜尋欄 ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋地標名稱…',
                prefixIcon: const Icon(Icons.search),
                // 有輸入文字時顯示清除按鈕
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '清除搜尋',
                        onPressed: () {
                          _searchController.clear();
                          // 清除後讓鍵盤收起
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // ── 篩選 Chip 列 ─────────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // 國家篩選 Chip
                _FilterChipButton(
                  label: _selectedCountries.isEmpty
                      ? '國家'
                      : '國家（${_selectedCountries.length}）',
                  icon: Icons.flag_outlined,
                  isActive: _selectedCountries.isNotEmpty,
                  onPressed: () => markersAsync.whenData(
                      (list) => _showCountryDialog(list)),
                ),
                const SizedBox(width: 8),

                // 評分篩選 Chip
                _FilterChipButton(
                  label: _minRating == null ? '評分' : '$_minRating★ 以上',
                  icon: Icons.star_outline_rounded,
                  isActive: _minRating != null,
                  onPressed: _showRatingDialog,
                ),
                const SizedBox(width: 8),

                // 日期區間篩選 Chip
                _FilterChipButton(
                  label: _dateRange == null
                      ? '日期'
                      : '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}',
                  icon: Icons.date_range_outlined,
                  isActive: _dateRange != null,
                  onPressed: _showDateRangePicker,
                ),

                // 有篩選條件時顯示清除按鈕
                if (_hasFilter) ...[
                  const SizedBox(width: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_list_off, size: 16),
                      label: const Text('清除篩選'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // ── 列表主體 ──────────────────────────────────────────────────────
          Expanded(
            child: markersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('載入失敗：$e',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(markerNotifierProvider),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
              data: (markers) => markers.isEmpty
                  ? _EmptyState(
                      onAdd: _navigateToCreate,
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: markers.length,
                        itemBuilder: (_, i) => _MarkerCard(
                          marker: markers[i],
                          onTap: () => _navigateToDetail(markers[i]),
                          onDelete: () => _deleteMarker(markers[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),

      // ── FAB：新增地標 ──────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('新增地標'),
        tooltip: '新增旅遊地標',
      ),
    );
  }

  // ── 頁面導覽 ───────────────────────────────────────────────────────────────

  /// 進入 CreateMarkerPage，返回後強制刷新列表
  Future<void> _navigateToCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateMarkerPage()),
    );
    // CreateMarkerPage 儲存後 invalidateSelf，但以防萬一再 invalidate 一次
    if (mounted) ref.invalidate(markerNotifierProvider);
  }

  /// 進入 MarkerDetailPage
  Future<void> _navigateToDetail(MarkerEntity marker) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarkerDetailPage(marker: marker),
      ),
    );
    // 詳情頁可能執行了編輯或刪除，返回後刷新列表
    if (mounted) ref.invalidate(markerNotifierProvider);
  }

  /// 左滑確認刪除
  Future<void> _deleteMarker(MarkerEntity marker) async {
    await ref.read(markerNotifierProvider.notifier).remove(marker.id);
  }
}

// ── FilterChip 按鈕 ────────────────────────────────────────────────────────────

/// 可點擊的篩選 Chip（選取時顯示填色狀態）
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// 是否處於啟用篩選狀態（影響顏色與選取外觀）
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isActive,
      // 選取時使用 secondaryContainer 底色突出顯示
      selectedColor: cs.secondaryContainer,
      checkmarkColor: cs.onSecondaryContainer,
      showCheckmark: false,
      onSelected: (_) => onPressed(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── 地標卡片 ───────────────────────────────────────────────────────────────────

/// 單筆地標卡片，支援左滑刪除（Dismissible）
class _MarkerCard extends StatelessWidget {
  const _MarkerCard({
    required this.marker,
    required this.onTap,
    required this.onDelete,
  });

  final MarkerEntity marker;
  final VoidCallback onTap;

  /// 確認後刪除的回呼（由外層呼叫 notifier）
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // 以 id 作為唯一鍵，確保左滑動作對應到正確資料
      key: ValueKey(marker.id),
      direction: DismissDirection.endToStart,
      // 左滑時顯示的紅色刪除背景
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text('刪除',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      // 左滑放開前彈出確認對話框
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('刪除地標'),
            content: Text('確定要刪除「${marker.title}」嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('刪除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── 左側縮圖 ──────────────────────────────────────────
                _Thumbnail(
                    photoPath: marker.photoPaths.isNotEmpty
                        ? marker.photoPaths.first
                        : null),
                const SizedBox(width: 12),

                // ── 中間資訊 ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題（粗體，最多 1 行）
                      Text(
                        marker.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // 國家 + 日期（小字灰色）
                      Text(
                        '${marker.country}  ·  '
                        '${marker.createdAt.year}/'
                        '${marker.createdAt.month.toString().padLeft(2, '0')}/'
                        '${marker.createdAt.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // 星號評分（size 16 實心/空心 icon）
                      _StarRow(rating: marker.rating),
                    ],
                  ),
                ),

                // ── 右側箭頭 ──────────────────────────────────────────
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 縮圖 ───────────────────────────────────────────────────────────────────────

/// 60×60 圓角縮圖；無照片時顯示佔位圖示
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: photoPath != null
            ? Image.file(
                File(photoPath!),
                fit: BoxFit.cover,
                // 圖片路徑失效時退回佔位圖示
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.place,
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

// ── 星號列 ─────────────────────────────────────────────────────────────────────

/// 只讀 1–5 星顯示（size 16）
class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < rating ? Colors.amber : Colors.grey[400],
          size: 16,
        );
      }),
    );
  }
}

// ── 空白狀態 ───────────────────────────────────────────────────────────────────

/// 無地標資料時的置中插圖 + 新增按鈕
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '尚無旅遊紀錄',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '點擊下方按鈕開始記錄您的旅遊足跡',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('立即新增'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
