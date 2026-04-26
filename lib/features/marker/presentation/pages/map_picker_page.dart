import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// ── 地圖選點頁面 ───────────────────────────────────────────────────────────
//
// 使用流程：
//   1. 開啟頁面時呼叫 GPS，取得當前位置並移動鏡頭
//   2. 使用者拖動地圖，中央 pin 固定，底部即時顯示座標
//   3. 點擊「確認此位置」後 Navigator.pop() 回傳 LatLng
//
// 呼叫範例：
//   final result = await Navigator.of(context).push<LatLng>(
//     MaterialPageRoute(builder: (_) => const MapPickerPage()),
//   );

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // 預設座標：台北 101（無法取得 GPS 時的 fallback）
  static const _defaultLatLng = LatLng(25.0330, 121.5654);
  static const _defaultZoom = 15.0;

  GoogleMapController? _mapController;

  /// 目前地圖中心座標（隨 onCameraMove 即時更新）
  LatLng _currentLatLng = _defaultLatLng;

  /// 是否正在取得 GPS 位置
  bool _isLocating = true;

  /// 位置權限是否被拒絕（決定是否顯示 myLocationButton）
  bool _locationDenied = false;

  // ── 生命週期 ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 頁面建立後立即嘗試取得 GPS 位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── GPS 初始化流程 ────────────────────────────────────────────────────────

  /// 完整的位置初始化：確認服務 → 請求權限 → 取得座標 → 移動鏡頭
  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _locationDenied = false;
    });

    // 1. 確認裝置 GPS 服務是否開啟
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _handleLocationUnavailable('GPS 服務未開啟，請先至設定啟用位置服務。');
      return;
    }

    // 2. 透過 permission_handler 請求位置權限
    final granted = await _requestLocationPermission();
    if (!granted) {
      _handleLocationUnavailable(null);
      return;
    }

    // 3. 取得目前 GPS 座標
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLatLng = latLng;
        _isLocating = false;
      });
      // 移動地圖鏡頭至目前位置
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    } on LocationServiceDisabledException {
      _handleLocationUnavailable('GPS 服務已關閉，請重新開啟後再試。');
    } catch (_) {
      // 定位逾時或其他錯誤，使用預設座標繼續
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// 位置無法取得時的統一處理
  void _handleLocationUnavailable(String? message) {
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _locationDenied = true;
    });
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  // ── 權限請求（permission_handler）────────────────────────────────────────

  /// 使用 permission_handler 請求位置權限，
  /// 永久拒絕時顯示引導對話框，回傳是否已取得權限
  Future<bool> _requestLocationPermission() async {
    // 先查詢目前狀態，避免重複彈出系統對話框
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) return true;

    // 向系統請求權限（第一次會彈出系統對話框）
    status = await Permission.location.request();

    if (status.isGranted) return true;

    // 使用者永久拒絕：引導至系統設定手動開啟
    if (status.isPermanentlyDenied && mounted) {
      await _showPermissionDeniedDialog();
    }

    return false;
  }

  /// 權限永久拒絕對話框
  Future<void> _showPermissionDeniedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, size: 40),
        title: const Text('需要位置權限'),
        content: const Text(
          '地圖選點功能需要存取您的 GPS 位置。\n\n'
          '請前往「系統設定 → 應用程式 → Travel Mark → 位置」，'
          '將權限設定為「使用 App 時」後再試一次。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍後再說'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // permission_handler 提供，開啟 App 的系統設定頁面
              openAppSettings();
            },
            child: const Text('開啟設定'),
          ),
        ],
      ),
    );
  }

  // ── 建構 UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選取地點'),
        actions: [
          // 重新定位按鈕
          IconButton(
            tooltip: '定位到目前位置',
            onPressed: _isLocating ? null : _initLocation,
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLatLng,
              zoom: _defaultZoom,
            ),
            onMapCreated: (controller) => _mapController = controller,
            // 顯示使用者藍點（需位置權限）
            myLocationEnabled: !_locationDenied,
            // 停用內建定位按鈕，改用 AppBar 自訂按鈕
            myLocationButtonEnabled: false,
            // 停用原生縮放按鈕（使用手勢縮放）
            zoomControlsEnabled: false,
            // 地圖移動時即時更新底部座標文字
            onCameraMove: (position) {
              setState(() => _currentLatLng = position.target);
            },
          ),

          // ── 中央固定 Pin（IgnorePointer 確保觸控事件穿透至地圖）──────
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                // 將 pin 向上偏移，使尖端對齊地圖中心點
                offset: const Offset(0, -26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 紅色位置 pin 圖示
                    Icon(
                      Icons.location_pin,
                      size: 52,
                      color: Colors.red[700],
                    ),
                    // pin 底部的橢圓陰影（視覺回饋，讓 pin 看起來「立」在地圖上）
                    Container(
                      width: 12,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 定位中提示橫幅（取得 GPS 期間顯示）──────────────────────
          if (_isLocating)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: _LocatingBanner()),
            ),

          // ── 底部座標面板 + 確認按鈕 ───────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              latLng: _currentLatLng,
              // 確認時將目前座標 pop 回上一頁
              onConfirm: () => Navigator.of(context).pop(_currentLatLng),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 私有子元件 ───────────────────────────────────────────────────────────────

/// 定位中提示橫幅（圓角 Pill 樣式）
class _LocatingBanner extends StatelessWidget {
  const _LocatingBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '正在取得目前位置…',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部面板：顯示目前座標 + 確認按鈕
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.latLng, required this.onConfirm});

  final LatLng latLng;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // 計入底部安全區域（iPhone Home Indicator 等）
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black12,
            offset: Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拉把手視覺提示
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 座標卡片（緯度 / 經度並排）
          Row(
            children: [
              Expanded(
                child: _CoordTile(
                  label: '緯度',
                  value: latLng.latitude.toStringAsFixed(6),
                  icon: Icons.north_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CoordTile(
                  label: '經度',
                  value: latLng.longitude.toStringAsFixed(6),
                  icon: Icons.east_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 確認按鈕
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('確認此位置'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 單一座標顯示卡片
class _CoordTile extends StatelessWidget {
  const _CoordTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
