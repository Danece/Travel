import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/country_flag.dart';
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

class _MapPageState extends ConsumerState<MapPage> with TickerProviderStateMixin {
  // ── 地圖控制器 ─────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;

  // ── 原生聚合管理器（google_maps_flutter 2.6+）──────────────────────────────
  static const _clusterManagerId = ClusterManagerId('travel_markers');
  late ClusterManager _clusterManager;

  /// Google Map 目前顯示的 Marker 集合（以 entity.id 為 key，O(1) 更新）
  Map<String, Marker> _markerMap = {};

  // ── 資料快取 ───────────────────────────────────────────────────────────────
  List<MarkerEntity> _allMarkers = [];

  // 以 entity.id 為 key 快取已繪製的 icon（含標題標籤）
  final Map<String, BitmapDescriptor> _bitmapCache = {};

  // 防止多次 _refreshMarkers 並發時舊的結果覆蓋新的
  int _refreshToken = 0;

  // ── 跳動動畫 ───────────────────────────────────────────────────────────────
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  MarkerEntity? _bouncingEntity;
  final Map<String, double> _markerAnchorY = {};

  // ── 選取標記（底部資訊卡）──────────────────────────────────────────────────
  MarkerEntity? _selectedMarker;
  MarkerEntity? _lastSelectedMarker; // 保留以讓滑出動畫可顯示內容

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
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceAnim = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    )..addListener(_onBounceFrame);
    _clusterManager = ClusterManager(
      clusterManagerId: _clusterManagerId,
      onClusterTap: _onClusterTap,
    );
    _checkLocation();
  }

  void _onBounceFrame() {
    if (!mounted || _bouncingEntity == null) return;
    final newAnchor = _bounceAnim.value;
    // 跳過變化量極小的幀，避免不必要的 setState
    if ((newAnchor - (_markerAnchorY[_bouncingEntity!.id] ?? 1.0)).abs() < 0.003) return;
    _updateAnchor(_bouncingEntity!, newAnchor);
  }

  @override
  void dispose() {
    _bounceController.dispose();
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

    // 分批建立，每批 20 個，避免大量並發 Canvas 操作
    const batchSize = 20;
    final markers = <Marker>[];
    for (var i = 0; i < filtered.length; i += batchSize) {
      if (token != _refreshToken) return;
      final batch =
          filtered.sublist(i, min(i + batchSize, filtered.length));
      markers.addAll(await Future.wait(batch.map(_buildSingleMarker)));
    }

    if (mounted && token == _refreshToken) {
      setState(() {
        _markerMap = { for (final m in markers) m.markerId.value: m };
      });
    }
  }

  /// 建立單一 Marker（含自訂標籤圖示），並關聯至原生 ClusterManager
  Future<Marker> _buildSingleMarker(MarkerEntity entity) async {
    final icon = await _getMarkerIcon(entity);
    final anchorY = _markerAnchorY[entity.id] ?? 1.0;
    return Marker(
      markerId: MarkerId(entity.id),
      position: LatLng(entity.latitude, entity.longitude),
      icon: icon,
      anchor: Offset(0.5, anchorY),
      clusterManagerId: _clusterManagerId,
      onTap: () => _onMarkerTap(entity),
    );
  }

  // ── Marker Icon 取得（含快取）──────────────────────────────────────────────

  /// 取得個別地標的 icon（含懸浮標題標籤），以 entity.id 為快取 key
  Future<BitmapDescriptor> _getMarkerIcon(MarkerEntity entity) async {
    final cacheKey = '${entity.id}_${entity.rating}';
    if (_bitmapCache.containsKey(cacheKey)) return _bitmapCache[cacheKey]!;

    // 標記數量多時跳過照片解碼（避免大量 I/O），但仍繪製文字標籤
    final skipPhoto = _allMarkers.length > 150;

    try {
      final icon = await _buildLabeledMarkerIcon(entity, skipPhoto: skipPhoto);
      _bitmapCache[cacheKey] = icon;
      return icon;
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  // ── Bitmap 建構（dart:ui）────────────────────────────────────────────────

  /// 建立地標 icon：白底深色文字標籤 + Teal 淚滴形 Pin
  /// （底部尖端 = anchor(0.5, 1.0) = 地理座標位置）
  Future<BitmapDescriptor> _buildLabeledMarkerIcon(
    MarkerEntity entity, {
    bool skipPhoto = false,
  }) async {
    const double scale   = 2.0;
    const double lFont   = 11.5 * scale;
    const double lPadH   = 10.0 * scale;
    const double lPadV   = 5.0  * scale;
    const double lRadius = 50.0 * scale; // 全圓角 pill
    const double pinR    = 15.0 * scale;
    const double tailH   = 12.0 * scale; // 短尾巴
    const double connH   = 4.0  * scale;
    const double connHW  = 7.0  * scale;

    final bool lowRating = entity.rating > 0 && entity.rating < 3;
    const Color teal = Color(0xFF00695C);
    const Color red  = Color(0xFFD32F2F);
    final Color pinColor = lowRating ? red : teal;

    // ── Measure text ───────────────────────────────────────────────────────
    final title = entity.title.length > 12
        ? '${entity.title.substring(0, 12)}…'
        : entity.title;

    // 用 foreground Paint 而非 color，確保 dart:ui 正確渲染文字顏色
    final textPaint = Paint()..color = const Color(0xFF1A1A1A);
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.left, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(
        foreground: textPaint,
        fontSize: lFont,
        fontWeight: ui.FontWeight.w600,
      ))
      ..addText(title);
    final para = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 400));

    final textW = para.maxIntrinsicWidth;
    final textH = para.height;
    final lW    = max(textW + lPadH * 2, pinR * 2 + connHW * 2);
    final lH    = textH + lPadV * 2;

    // ── Canvas layout ──────────────────────────────────────────────────────
    final canvasW = lW;
    final canvasH = lH + connH + pinR * 2 + tailH;
    final cx = canvasW / 2;

    final rec = ui.PictureRecorder();
    final c   = ui.Canvas(rec);

    // ── Label shadow ───────────────────────────────────────────────────────
    c.drawRRect(
      RRect.fromLTRBR(0, 2, lW, lH + 2, Radius.circular(lRadius)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Label: white fill + teal border ───────────────────────────────────
    c.drawRRect(
      RRect.fromLTRBR(0, 0, lW, lH, Radius.circular(lRadius)),
      Paint()..color = Colors.white,
    );
    c.drawRRect(
      RRect.fromLTRBR(0, 0, lW, lH, Radius.circular(lRadius)),
      Paint()
        ..color = pinColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // ── Label text ─────────────────────────────────────────────────────────
    c.drawParagraph(para, Offset((lW - textW) / 2, lPadV));

    // ── Connector triangle ─────────────────────────────────────────────────
    c.drawPath(
      Path()
        ..moveTo(cx - connHW, lH)
        ..lineTo(cx + connHW, lH)
        ..lineTo(cx, lH + connH)
        ..close(),
      Paint()..color = pinColor,
    );

    // ── Pin 圓球 ───────────────────────────────────────────────────────────
    final pinCy = lH + connH + pinR;
    c.drawCircle(Offset(cx, pinCy), pinR, Paint()..color = pinColor);

    // ── Pin 尾巴：從圓下半部延伸出的水滴尖端（quadratic bezier）──────────
    // 起點在圓下方兩側，以二次貝茲曲線向內收束至底部尖端，再 close 回起點。
    final tipY = canvasH;
    c.drawPath(
      Path()
        ..moveTo(cx - pinR * 0.62, pinCy + pinR * 0.72)
        ..quadraticBezierTo(cx - pinR * 0.12, tipY - tailH * 0.3, cx, tipY)
        ..quadraticBezierTo(cx + pinR * 0.12, tipY - tailH * 0.3, cx + pinR * 0.62, pinCy + pinR * 0.72)
        ..close(),
      Paint()..color = pinColor,
    );

    // ── Center mark: white dot (normal) or X (low rating) ─────────────────
    if (lowRating) {
      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = pinR * 0.38
        ..strokeCap = StrokeCap.round;
      final s = pinR * 0.52;
      c.drawLine(Offset(cx - s, pinCy - s), Offset(cx + s, pinCy + s), xPaint);
      c.drawLine(Offset(cx + s, pinCy - s), Offset(cx - s, pinCy + s), xPaint);
    } else {
      c.drawCircle(Offset(cx, pinCy), pinR * 0.45, Paint()..color = Colors.white);
    }

    // ── Output ────────────────────────────────────────────────────────────
    final img  = await rec.endRecording().toImage(canvasW.ceil(), canvasH.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: scale,
    );
  }

  // ── 跳動動畫 ──────────────────────────────────────────────────────────────

  void _updateAnchor(MarkerEntity entity, double anchorY) {
    if (!mounted) return;
    final existing = _markerMap[entity.id];
    if (existing == null) return;
    setState(() {
      _markerAnchorY[entity.id] = anchorY;
      _markerMap[entity.id] = existing.copyWith(anchorParam: Offset(0.5, anchorY));
    });
  }

  // ── 標記互動事件 ──────────────────────────────────────────────────────────

  void _onMarkerTap(MarkerEntity entity) {
    final prevId = _bouncingEntity?.id;
    _bouncingEntity = entity;
    _bounceController..stop()..reset()..forward();

    // 單次 setState：還原舊標記 + 新標記跳起 + 資訊卡更新
    setState(() {
      if (prevId != null && prevId != entity.id) {
        final prev = _markerMap[prevId];
        if (prev != null) {
          _markerMap[prevId] = prev.copyWith(anchorParam: const Offset(0.5, 1.0));
        }
        _markerAnchorY.remove(prevId);
      }
      final cur = _markerMap[entity.id];
      if (cur != null) {
        _markerMap[entity.id] = cur.copyWith(anchorParam: const Offset(0.5, 1.5));
      }
      _markerAnchorY[entity.id] = 1.5;
      _selectedMarker = entity;
      _lastSelectedMarker = entity;
    });
  }

  void _dismissMarkerCard() {
    setState(() => _selectedMarker = null);
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
            markers: _markerMap.values.toSet(),
            onMapCreated: _onMapCreated,
            onTap: (_) => _dismissMarkerCard(),
          ),

          // 初次載入（尚無任何標記）→ 置中 Loading 覆蓋層
          if (ref.watch(mapMarkersProvider).isLoading && _markerMap.isEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(
                              Color(0xFF00695C)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.loadingMarkers,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 重新整理（已有標記）→ 頂部細進度條
          if (ref.watch(mapMarkersProvider).isLoading && _markerMap.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: Color(0xFF00695C),
                backgroundColor: Colors.transparent,
              ),
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

          // ── 非鎖定底部資訊卡（不擋地圖互動）──────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: _selectedMarker == null,
              child: AnimatedSlide(
                offset: _selectedMarker != null
                    ? Offset.zero
                    : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 220),
                curve: _selectedMarker != null
                    ? Curves.easeOut
                    : Curves.easeIn,
                child: _lastSelectedMarker != null
                    ? _MarkerInfoCard(
                        entity: _lastSelectedMarker!,
                        onClose: _dismissMarkerCard,
                        onNavigate: () {
                          _dismissMarkerCard();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MarkerDetailPage(
                                  marker: _lastSelectedMarker!),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
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
    required this.onClose,
  });

  final MarkerEntity entity;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      shadowColor: Colors.black38,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 8, 12 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拉把手
            Center(
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            InkWell(
              onTap: onNavigate,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
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
                      children: [
                        Text(
                          entity.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${countryFlag(entity.country)} ${entity.country}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
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

                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),

                  // 關閉按鈕
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: onClose,
                    tooltip: '關閉',
                  ),
                ],
              ),
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
