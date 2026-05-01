import 'dart:io';
import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// google_maps_flutter 和 google_maps_cluster_manager 都有同名的
// ClusterManager / Cluster 型別，使用 prefix 消除歧義
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart'
    as cm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/pages/marker_detail_page.dart';
import '../providers/map_provider.dart';

// ── 地圖總覽頁 ────────────────────────────────────────────────────────────────
//
// 功能摘要：
//   1. 全螢幕 Google Map，初始鏡頭對準台灣中心
//   2. ClusterManager 聚合所有地標：
//      · 單一標記 → 縮圖圓形 icon（有照片）或藍色預設 icon
//      · 2–9 個聚合 → 顯示實際數字的藍色圓圈
//      · 10–29 個 → "10+"，30–49 → "30+"，50–99 → "50+"，100+ → "100+"
//   3. 點擊聚合圓圈 → 縮放到群組範圍
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

  // ── 聚合管理器 ─────────────────────────────────────────────────────────────
  late cm.ClusterManager<_MapItem> _clusterManager;

  /// Google Map 目前顯示的 Marker 集合（由 ClusterManager 更新）
  Set<Marker> _markers = {};

  // ── 資料快取 ───────────────────────────────────────────────────────────────
  /// 目前從 provider 取得的完整地標清單（用於篩選）
  List<MarkerEntity> _allMarkers = [];

  // 效能優化：自訂圓形縮圖需解碼圖片 + dart:ui Canvas 繪製，建立成本高
  // 以照片路徑為 key 快取結果，相同路徑的標記直接讀快取，避免重複解碼
  final Map<String, BitmapDescriptor> _bitmapCache = {};

  // 效能優化：聚合圓圈依數量等級快取，同等級標記共用同一 BitmapDescriptor
  final Map<int, BitmapDescriptor> _clusterIconCache = {};

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
    // ClusterManager 初始化（空列表，資料載入後透過 setItems 更新）
    _clusterManager = cm.ClusterManager<_MapItem>(
      const <_MapItem>[],   // 明確型別，避免 Dart 推斷為 dynamic
      _onMarkersUpdated,
      // 套件將 markerBuilder 定義為 Function(dynamic)，
      // 需以 dynamic 接收再向下轉型為 cm.Cluster<_MapItem>
      markerBuilder: (dynamic cluster) =>
          _buildMarker(cluster as cm.Cluster<_MapItem>),
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
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要位置權限'),
        content: const Text('定位功能已被關閉，請前往系統設定開啟位置存取權限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('前往設定'),
          ),
        ],
      ),
    );
  }

  // ── ClusterManager 回呼 ───────────────────────────────────────────────────

  /// ClusterManager 計算完成後更新 Marker 集合
  void _onMarkersUpdated(Set<Marker> markers) {
    if (mounted) setState(() => _markers = markers);
  }

  // ── 地圖事件 ──────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // 告知 ClusterManager 地圖已建立，後續操作需要 mapId
    _clusterManager.setMapId(controller.mapId);
    // 地圖建立後若資料已就緒，立即渲染標記
    if (_allMarkers.isNotEmpty) _refreshCluster();
  }

  void _onCameraMove(CameraPosition position) =>
      _clusterManager.onCameraMove(position);

  // v3.x API：camera idle 時呼叫 updateMap() 觸發聚合重算
  void _onCameraIdle() => _clusterManager.updateMap();

  // ── 聚合刷新 ──────────────────────────────────────────────────────────────

  /// 套用目前篩選條件並更新 ClusterManager 的 items
  void _refreshCluster() {
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

    _clusterManager.setItems(
      filtered.map((e) => _MapItem(e)).toList(),
    );
  }

  // ── Marker 建構（ClusterManager markerBuilder）────────────────────────────

  /// ClusterManager 呼叫此方法建立每個 Marker（包含聚合與個別）
  Future<Marker> _buildMarker(cm.Cluster<_MapItem> cluster) async {
    if (!cluster.isMultiple) {
      // ── 個別標記 ──────────────────────────────────────────────────────
      final entity = cluster.items.first.entity;
      final icon = await _getMarkerIcon(entity);
      return Marker(
        markerId: MarkerId(cluster.getId()),
        position: cluster.location,
        icon: icon,
        onTap: () => _onMarkerTap(entity),
      );
    } else {
      // ── 聚合標記 ──────────────────────────────────────────────────────
      final icon = await _getClusterIcon(cluster.count);
      return Marker(
        markerId: MarkerId(cluster.getId()),
        position: cluster.location,
        icon: icon,
        onTap: () => _onClusterTap(cluster),
      );
    }
  }

  // ── Bitmap 取得（含快取）──────────────────────────────────────────────────

  /// 取得個別地標的 icon：有照片 → 圓形縮圖；無照片 → 藍色預設
  Future<BitmapDescriptor> _getMarkerIcon(MarkerEntity entity) async {
    // 效能優化：標記總數超過 200 時跳過自訂縮圖解碼
    // 大量標記同時呼叫 _buildCircularPhotoIcon 會造成 UI jank（主執行緒圖片解碼阻塞）
    // 改用輕量的預設藍色標記，確保地圖操作流暢
    if (_allMarkers.length > 200) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }

    if (entity.photoPaths.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }

    final path = entity.photoPaths.first;
    // 效能優化：命中快取時直接回傳，避免重複解碼同一張照片
    if (_bitmapCache.containsKey(path)) return _bitmapCache[path]!;

    try {
      final icon = await _buildCircularPhotoIcon(path);
      _bitmapCache[path] = icon;
      return icon;
    } catch (_) {
      // 圖片讀取失敗（路徑已刪除等）→ 退回藍色預設
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// 取得聚合圓圈 icon（依數量等級快取）
  Future<BitmapDescriptor> _getClusterIcon(int count) async {
    // 以等級作為快取 key，同等級共用相同 bitmap
    final tier = _clusterTier(count);
    if (_clusterIconCache.containsKey(tier)) return _clusterIconCache[tier]!;

    final icon = await _buildClusterBitmap(count, tier);
    _clusterIconCache[tier] = icon;
    return icon;
  }

  /// 判斷聚合數量等級（用於快取 key 與標籤）
  static int _clusterTier(int count) {
    if (count >= 100) return 100;
    if (count >= 50) return 50;
    if (count >= 30) return 30;
    if (count >= 10) return 10;
    return count; // 2–9：以實際數量為 key，確保顯示正確數字
  }

  // ── Bitmap 建構（dart:ui）────────────────────────────────────────────────

  /// 從照片路徑建立圓形縮圖 BitmapDescriptor（56×56 dp，2x 解析度生成）
  Future<BitmapDescriptor> _buildCircularPhotoIcon(String path) async {
    const int logical = 56; // 邏輯尺寸（dp）
    const int pixel = logical * 2; // 2x 解析度像素尺寸

    // 解碼照片並縮放至目標尺寸
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

    // 白色外框圓
    canvas.drawCircle(
      const Offset(cx, cx),
      cx,
      Paint()..color = Colors.white,
    );

    // 裁切路徑（圓形，留 3px 邊框）
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: const Offset(cx, cx), radius: cx - 3),
        ),
    );

    // 繪製照片到圓形區域
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(
          0, 0, srcImage.width.toDouble(), srcImage.height.toDouble()),
      Rect.fromLTWH(3.0, 3.0, pixel - 6.0, pixel - 6.0),
      Paint(),
    );

    final img =
        await recorder.endRecording().toImage(pixel, pixel);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    // ignore: deprecated_member_use — bytes() API 在 ^2.10.0 尚未穩定，fromBytes 仍可用
    return BitmapDescriptor.fromBytes(
      data!.buffer.asUint8List(),
      size: Size(logical.toDouble(), logical.toDouble()),
    );
  }

  /// 建立聚合數字圓圈 BitmapDescriptor（藍底白字，大小隨數量增加）
  Future<BitmapDescriptor> _buildClusterBitmap(int count, int tier) async {
    // 標籤文字與邏輯尺寸
    final String label;
    final int logical;
    if (tier >= 100) {
      label = '100+';
      logical = 80;
    } else if (tier >= 50) {
      label = '50+';
      logical = 72;
    } else if (tier >= 30) {
      label = '30+';
      logical = 64;
    } else if (tier >= 10) {
      label = '10+';
      logical = 56;
    } else {
      label = '$count'; // 2–9：顯示實際數字
      logical = 56;
    }

    final int pixel = logical * 2;
    final double cx = pixel / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 深藍底色
    canvas.drawCircle(
      Offset(cx, cx),
      cx - 3,
      Paint()..color = const Color(0xFF1565C0), // blue[800]
    );

    // 淺藍外圈（視覺層次感）
    canvas.drawCircle(
      Offset(cx, cx),
      cx,
      Paint()
        ..color = const Color(0xFF42A5F5) // blue[400]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 白色數字文字（使用 dart:ui ParagraphBuilder）
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontWeight: ui.FontWeight.w700,
        fontSize: pixel * 0.27,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
      ..addText(label);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: pixel.toDouble()));

    // 垂直置中
    canvas.drawParagraph(
      paragraph,
      Offset(0, (pixel - paragraph.height) / 2),
    );

    final img =
        await recorder.endRecording().toImage(pixel, pixel);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(
      data!.buffer.asUint8List(),
      size: Size(logical.toDouble(), logical.toDouble()),
    );
  }

  // ── 標記互動事件 ──────────────────────────────────────────────────────────

  /// 點擊個別標記 → 底部資訊卡片
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

  /// 點擊聚合圓圈 → 縮放到群組 LatLngBounds
  void _onClusterTap(cm.Cluster<_MapItem> cluster) {
    final lats = cluster.items.map((i) => i.entity.latitude).toList();
    final lngs = cluster.items.map((i) => i.entity.longitude).toList();

    final sw = LatLng(lats.reduce(min), lngs.reduce(min));
    final ne = LatLng(lats.reduce(max), lngs.reduce(max));

    // 所有點在同一位置時直接放大到街道層級
    if (sw.latitude == ne.latitude && sw.longitude == ne.longitude) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.location, 16),
      );
      return;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        64, // padding（dp）
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
          _refreshCluster();
        },
      ),
    );
  }

  // ── 建構 UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 監聽資料變化，自動刷新 ClusterManager
    ref.listen<AsyncValue<List<MarkerEntity>>>(
      mapMarkersProvider,
      (_, next) => next.whenData((markers) {
        _allMarkers = markers;
        _refreshCluster();
      }),
    );

    // 初次載入時同步讀取（避免 ref.listen 錯過第一次 emit）
    ref.watch(mapMarkersProvider).whenData((markers) {
      if (_allMarkers.isEmpty && markers.isNotEmpty) {
        _allMarkers = markers;
        // 用 addPostFrameCallback 避免在 build 中呼叫 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshCluster();
        });
      }
    });

    final hasFilter =
        _filterCountries.isNotEmpty || _filterMinRating != null;

    return Scaffold(
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('地圖總覽'),
        actions: [
          // 篩選按鈕（有篩選條件時顯示 Badge 提示）
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: '篩選顯示標記',
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

      // ── 地圖主體 ─────────────────────────────────────────────────────────
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initCamera,
            mapType: MapType.normal,
            myLocationEnabled: _locationEnabled,
            myLocationButtonEnabled: _locationEnabled,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // 資料載入中時顯示頂部進度條
          if (ref.watch(mapMarkersProvider).isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),

          // 有篩選條件時顯示提示 Chip
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
                    _refreshCluster();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ClusterItem 包裝器 ─────────────────────────────────────────────────────────

/// 將 MarkerEntity 包裝為 ClusterManager 所需的 ClusterItem
class _MapItem implements cm.ClusterItem {
  const _MapItem(this.entity);

  final MarkerEntity entity;

  @override
  LatLng get location => LatLng(entity.latitude, entity.longitude);

  /// 標準 Geohash 編碼（precision 12），供 ClusterManager 空間索引使用
  @override
  String get geohash {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    final lat = entity.latitude;
    final lng = entity.longitude;
    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    final buf = StringBuffer();
    var evenBit = true;
    var hashVal = 0;
    var bits = 0;
    while (buf.length < 12) {
      if (evenBit) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          hashVal = (hashVal << 1) + 1;
          minLng = mid;
        } else {
          hashVal = hashVal << 1;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          hashVal = (hashVal << 1) + 1;
          minLat = mid;
        } else {
          hashVal = hashVal << 1;
          maxLat = mid;
        }
      }
      evenBit = !evenBit;
      if (++bits == 5) {
        buf.write(base32[hashVal]);
        bits = 0;
        hashVal = 0;
      }
    }
    return buf.toString();
  }
}

// ── 地標資訊底部卡片 ───────────────────────────────────────────────────────────

/// 點擊地圖 Marker 後顯示的底部卡片（高度 120，含縮圖、標題、評分）
class _MarkerInfoCard extends StatelessWidget {
  const _MarkerInfoCard({
    required this.entity,
    required this.onNavigate,
  });

  final MarkerEntity entity;

  /// 點擊卡片整列後進入詳情頁的回呼
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
            // 縮圖（有照片顯示 File image，無照片顯示佔位圖示）
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

            // 文字資訊
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 標題
                  Text(
                    entity.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 國家
                  Text(
                    entity.country,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  // 星號評分
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

            // 進入詳情頁箭頭
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

/// 篩選面板：國家多選 CheckboxListTile + 最低評分 SimpleDialogOption
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
    // 以目前篩選條件初始化（取副本，避免直接修改外部狀態）
    _countries = Set<String>.from(widget.selectedCountries);
    _minRating = widget.minRating;
  }

  @override
  Widget build(BuildContext context) {
    // 從所有地標取出不重複國家清單（排序後展示）
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
          // 拖拉把手
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 標題列
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '篩選顯示條件',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // 重置按鈕
                TextButton(
                  onPressed: () => setState(() {
                    _countries = {};
                    _minRating = null;
                  }),
                  child: const Text('重置'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 捲動內容
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // ── 最低評分 ──────────────────────────────────────────────
                _SheetSection(
                  title: '最低評分',
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
                            Text('$v 以上'),
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

                // ── 國家多選 ──────────────────────────────────────────────
                if (allCountries.isNotEmpty)
                  _SheetSection(
                    title: '國家（可多選）',
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

          // ── 確認按鈕 ──────────────────────────────────────────────────────
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
              child: const Text('套用篩選'),
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

/// 有篩選條件時懸浮於地圖頂部的提示 Chip，點擊可一鍵清除
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
    final parts = <String>[];
    if (countries.isNotEmpty) parts.add('${countries.length} 個國家');
    if (minRating != null) parts.add('$minRating★ 以上');

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
              '篩選中：${parts.join('、')}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            // 一鍵清除按鈕
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
