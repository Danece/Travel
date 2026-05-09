import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/country_flag.dart';
import '../../domain/entities/marker_category.dart';
import '../../domain/entities/marker_entity.dart';
import '../providers/marker_provider.dart';
import 'create_marker_page.dart';
import 'marker_detail_page.dart';

class MarkerPage extends ConsumerStatefulWidget {
  const MarkerPage({super.key});

  @override
  ConsumerState<MarkerPage> createState() => _MarkerPageState();
}

class _MarkerPageState extends ConsumerState<MarkerPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  Set<String> _selectedCountries = {};
  int? _minRating;
  DateTimeRange? _dateRange;
  Set<MarkerCategory> _selectedCategories = {};

  // 累積所有出現過的國家，確保篩選後重開對話框時仍能看到完整清單
  final Set<String> _allCountries = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  bool get _hasFilter =>
      _selectedCountries.isNotEmpty ||
      _minRating != null ||
      _dateRange != null ||
      _selectedCategories.isNotEmpty;

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _applySearch);
  }

  Future<void> _applySearch() async {
    await ref.read(markerNotifierProvider.notifier).search(
          title: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          countries: _selectedCountries.isEmpty
              ? null
              : _selectedCountries.toList(),
          minRating: _minRating,
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
          categories: _selectedCategories.isEmpty
              ? null
              : _selectedCategories.map((c) => c.name).toList(),
        );
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedCountries = {};
      _minRating = null;
      _dateRange = null;
      _selectedCategories = {};
    });
    await _applySearch();
  }

  Future<void> _showCountryDialog(AppLocalizations l10n) async {
    // 若快取還未建立，直接從 provider 讀一次補進去
    if (_allCountries.isEmpty) {
      final snapshot = ref.read(markerNotifierProvider);
      snapshot.whenData(
        (list) => _allCountries.addAll(list.map((m) => m.country)),
      );
    }
    // 合併快取清單與已選清單，確保已選的國家一定出現
    final countries = _allCountries.union(_selectedCountries).toList()..sort();
    if (countries.isEmpty) return;

    var tempSelected = Set<String>.from(_selectedCountries);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.filterCountryTitle),
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
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _selectedCountries = tempSelected);
    await _applySearch();
  }

  Future<void> _showRatingDialog(AppLocalizations l10n) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.filterMinRating),
        children: List.generate(5, (i) {
          final stars = i + 1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, stars),
            child: Row(
              children: [
                ...List.generate(
                  stars,
                  (_) => const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 8),
                Text(l10n.starsAbove(stars)),
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

  Future<void> _showDateRangePicker(AppLocalizations l10n) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: l10n.selectDateRange,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
      saveText: l10n.confirm,
    );

    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
    await _applySearch();
  }

  Future<void> _showCategoryDialog(AppLocalizations l10n) async {
    var tempSelected = Set<MarkerCategory>.from(_selectedCategories);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.filterCategoryTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: MarkerCategory.values.map((cat) {
                final sel = tempSelected.contains(cat);
                return FilterChip(
                  label: Text(cat.localizedDisplay(l10n.isEn)),
                  selected: sel,
                  onSelected: (v) => setDialogState(() {
                    if (v) {
                      tempSelected.add(cat);
                    } else {
                      tempSelected.remove(cat);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _selectedCategories = tempSelected);
    await _applySearch();
  }

  Future<void> _onRefresh() async {
    _searchController.clear();
    await _clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final markersAsync = ref.watch(markerNotifierProvider);

    // 每次資料更新就把出現的國家加入快取（只增不減）
    ref.listen(markerNotifierProvider, (_, next) {
      next.whenData((list) {
        final incoming = list.map((m) => m.country).toSet();
        if (!_allCountries.containsAll(incoming)) {
          setState(() => _allCountries.addAll(incoming));
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.markerPageTitle)),
      body: Column(
        children: [
          // ── 搜尋欄 ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _searchController.clear();
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
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: [
                _FilterChipButton(
                  label: _selectedCountries.isEmpty
                      ? l10n.filterCountry
                      : l10n.filterCountryActive(
                          _selectedCountries.length),
                  icon: Icons.flag_outlined,
                  isActive: _selectedCountries.isNotEmpty,
                  onPressed: () => _showCountryDialog(l10n),
                ),
                const SizedBox(width: 8),

                _FilterChipButton(
                  label: _minRating == null
                      ? l10n.filterRating
                      : l10n.starsAbove(_minRating!),
                  icon: Icons.star_outline_rounded,
                  isActive: _minRating != null,
                  onPressed: () => _showRatingDialog(l10n),
                ),
                const SizedBox(width: 8),

                _FilterChipButton(
                  label: _dateRange == null
                      ? l10n.filterDate
                      : '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}',
                  icon: Icons.date_range_outlined,
                  isActive: _dateRange != null,
                  onPressed: () => _showDateRangePicker(l10n),
                ),
                const SizedBox(width: 8),

                _FilterChipButton(
                  label: _selectedCategories.isEmpty
                      ? l10n.filterCategory
                      : l10n
                          .filterCategoryActive(_selectedCategories.length),
                  icon: Icons.category_outlined,
                  isActive: _selectedCategories.isNotEmpty,
                  onPressed: () => _showCategoryDialog(l10n),
                ),

                if (_hasFilter) ...[
                  const SizedBox(width: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_list_off, size: 16),
                      label: Text(l10n.clearFilters),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),

          // ── 列表主體 ──────────────────────────────────────────────────────
          Expanded(
            child: markersAsync.when(
              loading: () => const _LoadingSkeleton(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('${l10n.loadFailed}：$e',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(markerNotifierProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (markers) => markers.isEmpty
                  ? _EmptyState(onAdd: _navigateToCreate, l10n: l10n)
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: markers.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (_, i) => RepaintBoundary(
                          child: _MarkerCard(
                            marker: markers[i],
                            l10n: l10n,
                            onTap: () => _navigateToDetail(markers[i]),
                            onDelete: () => _deleteMarker(markers[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addMarker),
        tooltip: l10n.addMarker,
      ),
    );
  }

  Future<void> _navigateToCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateMarkerPage()),
    );
    if (mounted) ref.invalidate(markerNotifierProvider);
  }

  Future<void> _navigateToDetail(MarkerEntity marker) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarkerDetailPage(marker: marker),
      ),
    );
    if (mounted) ref.invalidate(markerNotifierProvider);
  }

  Future<void> _deleteMarker(MarkerEntity marker) async {
    await ref.read(markerNotifierProvider.notifier).remove(marker.id);
  }
}

// ── FilterChip 按鈕 ────────────────────────────────────────────────────────────

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
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
      selectedColor: cs.secondaryContainer,
      checkmarkColor: cs.onSecondaryContainer,
      showCheckmark: false,
      onSelected: (_) => onPressed(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── 地標卡片 ───────────────────────────────────────────────────────────────────

class _MarkerCard extends StatelessWidget {
  const _MarkerCard({
    required this.marker,
    required this.onTap,
    required this.onDelete,
    required this.l10n,
  });

  final MarkerEntity marker;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(marker.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 26),
            const SizedBox(height: 2),
            Text(l10n.swipeToDelete,
                style:
                    const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteMarker),
            content: Text(l10n.deleteMarkerConfirm(marker.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
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
                _Thumbnail(
                    photoPath: marker.photoPaths.isNotEmpty
                        ? marker.photoPaths.first
                        : null),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(
                        '${MarkerCategory.fromString(marker.category).emoji}  '
                        '${countryFlag(marker.country)} ${marker.country}  ·  '
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
                      _StarRow(rating: marker.rating),
                    ],
                  ),
                ),

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
        child: Icon(
          Icons.place,
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

// ── 星號列 ─────────────────────────────────────────────────────────────────────

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.l10n});
  final VoidCallback onAdd;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.noRecordsYet,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.startRecording,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.addNow),
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

// ── Shimmer 載入骨架 ───────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 12,
                      width: 120,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
