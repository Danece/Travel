import 'dart:io';
import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/pages/marker_detail_page.dart';
import '../providers/map_provider.dart';

// ── 地圖總覽頁 ────────────────────────────────────────────────────────────────
//
// 功能摘要：
//   1. 全螢幕 Google Map，初始鏡頭對準台灣中心
//   2. 原生 ClusterManager（google_maps_flutter 2.6+）聚合所有地標
//      · 個別標記 → 縮圖圓形 icon（有照片）或藍色預設 icon
//      · 聚合標記 → 平台原生樣式（藍圈 + 數字）
//   3. 點擊聚合圓圈 → 縮放到群組 LatLngBounds
//   4. 點擊個別標記 → 底部卡片（縮圖 + 標題 + 評分），點卡片進詳情頁
//   5. 右上角篩選按鈕 → BottomSheet（國家多選 + 最低評分）

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // ── 地圖控制器 ─────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;

  // ── 原生聚合管理器（google_maps_flutter 2.6+）──────────────────────────────
  static const _clusterManagerId = ClusterManagerId('travel_markers');
  late ClusterManager _clusterManager;

  /// Google Map 目前顯示的 Marker 集合
  Set<Marker> _markers = {};

  // ── 資料快取 ───────────────────────────────────────────────────────────────
  List<MarkerEntity> _allMarkers = [];

  // 效能優化：以照片路徑為 key 快取圓形縮圖，避免重複解碼
  final Map<String, BitmapDescriptor> _bitmapCache = {};

  // 防止多次 _refreshMarkers 並發時舊的結果覆蓋新的
  int _refreshToken = 0;

  // ── 篩選狀態 ───────────────────────────────────────────────────────────────
  Set<String> _filterCountries = {};
  int? _filterMinRating;

  // ── 位置權限 ───────────────────────────────────────────────────────────────
  bool _locationEnabled = false;

  // ── 預設鏡頭位置：台灣中心 ────────────────────────────────────────────────
  static const _initCamera = CameraPosition(
    target: LatLng(23.5, 121.0),
    zoom: 7,
  );

  // ── 生命週期 ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _clusterManager = ClusterManager(
      clusterManagerId: _clusterManagerId,
      onClusterTap: _onClusterTap,
    );
    _checkLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── 位置權限檢查 ──────────────────────────────────────────────────────────

  Future<void> _checkLocation() async {
    final status = await Permission.location.status;
    if (mounted) {
      setState(() => _locationEnabled = status.isGranted);
    }
    if (!status.isGranted) {
      final result = await Permission.location.request();
      if (mounted) {
        setState(() => _locationEnabled = result.isGranted);
        if (result.isPermanentlyDenied) {
          _showLocationDeniedDialog();
        }
      }
    }
  }

  void _showLocationDeniedDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.locationPermission),
        content: Text(l10n.locationPermissionContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  }

  // ── 地圖事件 ──────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_allMarkers.isNotEmpty) _refreshMarkers();
  }

  // ── 聚合點擊：縮放到群組範圍 ──────────────────────────────────────────────

  void _onClusterTap(Cluster cluster) {
    final bounds = cluster.bounds;
    if (bounds.southwest.latitude == bounds.northeast.latitude &&
        bounds.southwest.longitude == bounds.northeast.longitude) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.position, 16),
      );
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 64),
    );
  }

  // ── 標記刷新 ──────────────────────────────────────────────────────────────

  /// 套用篩選條件，非同步建立所有 Marker（含縮圖）並更新地圖
  Future<void> _refreshMarkers() async {
    final token = ++_refreshToken;

    final filtered = _allMarkers.where((m) {
      if (_filterCountries.isNotEmpty &&
          !_filterCountries.contains(m.country)) {
        return false;
      }
      if (_filterMinRating != null && m.rating < _filterMinRating!) {
        return false;
      }
      return true;
    }).toList();

    final markers = await Future.wait(
      filtered.map(_buildSingleMarker),
    );

    if (mounted && token == _refreshToken) {
      setState(() => _markers = markers.toSet());
    }
  }

  /// 建立單一 Marker（含自訂圓形縮圖 icon），並關聯至原生 ClusterManager
  Future<Marker> _buildSingleMarker(MarkerEntity entity) async {
    final icon = await _getMarkerIcon(entity);
    return Marker(
      markerId: MarkerId(entity.id),
      position: LatLng(entity.latitude, entity.longitude),
      icon: icon,
      clusterManagerId: _clusterManagerId,
      onTap: () => _onMarkerTap(entity),
    );
  }

  // ── Marker Icon 取得（含快取）──────────────────────────────────────────────

  /// 取得個別地標的 icon：有照片 → 圓形縮圖；無照片 → 藍色預設
  Future<BitmapDescriptor> _getMarkerIcon(MarkerEntity entity) async {
    // 效能優化：標記總數超過 200 時跳過自訂縮圖解碼
    if (_allMarkers.length > 200) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }

    if (entity.photoPaths.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }

    final path = entity.photoPaths.first;
    if (_bitmapCache.containsKey(path)) return _bitmapCache[path]!;

    try {
      final icon = await _buildCircularPhotoIcon(path);
      _bitmapCache[path] = icon;
      return icon;
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  // ── Bitmap 建構（dart:ui）────────────────────────────────────────────────

  /// 從照片路徑建立圓形縮圖 BitmapDescriptor（56×56 dp，2x 解析度生成）
  Future<BitmapDescriptor> _buildCircularPhotoIcon(String path) async {
    const int logical = 56;
    const int pixel = logical * 2;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: pixel,
      targetHeight: pixel,
    );
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const double cx = pixel / 2;

    canvas.drawCircle(
      const Offset(cx, cx),
      cx,
      Paint()..color = Colors.white,
    );

    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: const Offset(cx, cx), radius: cx - 3),
        ),
    );

    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(
          0, 0, srcImage.width.toDouble(), srcImage.height.toDouble()),
      Rect.fromLTWH(3.0, 3.0, pixel - 6.0, pixel - 6.0),
      Paint(),
    );

    final img = await recorder.endRecording().toImage(pixel, pixel);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(
      data!.buffer.asUint8List(),
      size: Size(logical.toDouble(), logical.toDouble()),
    );
  }

  // ── 標記互動事件 ──────────────────────────────────────────────────────────

  void _onMarkerTap(MarkerEntity entity) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MarkerInfoCard(
        entity: entity,
        onNavigate: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MarkerDetailPage(marker: entity)),
          );
        },
      ),
    );
  }

  // ── 篩選 BottomSheet ──────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        allMarkers: _allMarkers,
        selectedCountries: _filterCountries,
        minRating: _filterMinRating,
        onApply: (countries, rating) {
          Navigator.pop(context);
          setState(() {
            _filterCountries = countries;
            _filterMinRating = rating;
          });
          _refreshMarkers();
        },
      ),
    );
  }

  // ── 建構 UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<MarkerEntity>>>(
      mapMarkersProvider,
      (_, next) => next.whenData((markers) {
        _allMarkers = markers;
        _refreshMarkers();
      }),
    );

    ref.watch(mapMarkersProvider).whenData((markers) {
      if (_allMarkers.isEmpty && markers.isNotEmpty) {
        _allMarkers = markers;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshMarkers();
        });
      }
    });

    final hasFilter =
        _filterCountries.isNotEmpty || _filterMinRating != null;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapPageTitle),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: l10n.mapFilterTooltip,
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterSheet,
              ),
              if (hasFilter)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initCamera,
            mapType: MapType.normal,
            myLocationEnabled: _locationEnabled,
            myLocationButtonEnabled: _locationEnabled,
            zoomControlsEnabled: false,
            clusterManagers: {_clusterManager},
            markers: _markers,
            onMapCreated: _onMapCreated,
          ),

          if (ref.watch(mapMarkersProvider).isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),

          if (hasFilter)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _FilterBadge(
                  countries: _filterCountries,
                  minRating: _filterMinRating,
                  onClear: () {
                    setState(() {
                      _filterCountries = {};
                      _filterMinRating = null;
                    });
                    _refreshMarkers();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 地標資訊底部卡片 ───────────────────────────────────────────────────────────

class _MarkerInfoCard extends StatelessWidget {
  const _MarkerInfoCard({
    required this.entity,
    required this.onNavigate,
  });

  final MarkerEntity entity;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 120 + bottomPadding,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      child: InkWell(
        onTap: onNavigate,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 76,
                height: 76,
                child: entity.photoPaths.isNotEmpty
                    ? Image.file(
                        File(entity.photoPaths.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _photoPlaceholder(context),
                      )
                    : _photoPlaceholder(context),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entity.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entity.country,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < entity.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < entity.rating
                            ? Colors.amber
                            : Colors.grey[400],
                        size: 16,
                      );
                    }),
                  ),
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
    );
  }

  Widget _photoPlaceholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.place,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

// ── 篩選 BottomSheet ────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.allMarkers,
    required this.selectedCountries,
    required this.minRating,
    required this.onApply,
  });

  final List<MarkerEntity> allMarkers;
  final Set<String> selectedCountries;
  final int? minRating;
  final void Function(Set<String> countries, int? minRating) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _countries;
  late int? _minRating;

  @override
  void initState() {
    super.initState();
    _countries = Set<String>.from(widget.selectedCountries);
    _minRating = widget.minRating;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allCountries = widget.allMarkers
        .map((m) => m.country)
        .toSet()
        .toList()
      ..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  l10n.mapFilterTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _countries = {};
                    _minRating = null;
                  }),
                  child: Text(l10n.resetFilter),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _SheetSection(
                  title: l10n.filterMinRating,
                  child: Wrap(
                    spacing: 8,
                    children: List.generate(5, (i) {
                      final v = i + 1;
                      final isSelected = _minRating == v;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                  : Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(l10n.starsAbove(v)),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        onSelected: (_) => setState(
                          () => _minRating = isSelected ? null : v,
                        ),
                      );
                    }),
                  ),
                ),

                if (allCountries.isNotEmpty)
                  _SheetSection(
                    title: l10n.mapCountryMultiSelect,
                    child: Column(
                      children: allCountries.map((c) {
                        return CheckboxListTile(
                          title: Text(c),
                          value: _countries.contains(c),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _countries.add(c);
                            } else {
                              _countries.remove(c);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            child: FilledButton(
              onPressed: () => widget.onApply(_countries, _minRating),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.applyFilter),
            ),
          ),
        ],
      ),
    );
  }
}

/// 篩選面板中的小節標題包裝
class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ],
    );
  }
}

// ── 篩選狀態浮動 Badge ─────────────────────────────────────────────────────────

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({
    required this.countries,
    required this.minRating,
    required this.onClear,
  });

  final Set<String> countries;
  final int? minRating;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (countries.isNotEmpty) parts.add(l10n.mapCountriesCount(countries.length));
    if (minRating != null) parts.add(l10n.starsAbove(minRating!));
    final separator = l10n.isEn ? ', ' : '、';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(blurRadius: 6, color: Colors.black26)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.mapFilterActive(parts.join(separator)),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close,
                size: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
