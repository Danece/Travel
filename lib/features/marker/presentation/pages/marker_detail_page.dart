import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/marker_entity.dart';
import '../providers/marker_provider.dart';
import 'map_picker_page.dart';

// ── 常見國家清單（與 create_marker_page.dart 相同，獨立宣告避免跨檔案耦合）────
const List<String> _kCountries = [
  'Taiwan', 'Japan', 'South Korea', 'China', 'Hong Kong', 'Macau', 'Mongolia',
  'Thailand', 'Vietnam', 'Singapore', 'Malaysia', 'Indonesia',
  'Philippines', 'Cambodia', 'Myanmar',
  'India', 'Nepal', 'Sri Lanka', 'Maldives', 'Bhutan',
  'United Kingdom', 'France', 'Germany', 'Italy', 'Spain',
  'Portugal', 'Netherlands', 'Switzerland', 'Austria', 'Belgium',
  'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland',
  'Czech Republic', 'Hungary', 'Greece', 'Croatia', 'Iceland',
  'United States', 'Canada', 'Mexico', 'Brazil', 'Argentina', 'Peru',
  'Australia', 'New Zealand',
  'UAE', 'Israel',
  'Egypt', 'Morocco',
];

const List<String> _kRatingLabels = ['很差', '普通', '不錯', '推薦', '必去！'];
const int _kMaxPhotos = 10;

// ── 地標詳情頁 ────────────────────────────────────────────────────────────────
//
// 頁面接收一個 MarkerEntity，分三個視覺區域呈現：
//   1. 頂部照片 PageView（可左右滑動，顯示頁碼；長按可移除單張）
//   2. 捲動式基本資訊（標題、國家、日期、評分、座標、心得）
//   3. 底部固定「新增照片」按鈕列
//
// AppBar 右側有 編輯（pencil）與 刪除（trash）兩個 IconButton。

class MarkerDetailPage extends ConsumerStatefulWidget {
  const MarkerDetailPage({super.key, required this.marker});

  /// 進入頁面時傳入的初始地標資料
  final MarkerEntity marker;

  @override
  ConsumerState<MarkerDetailPage> createState() => _MarkerDetailPageState();
}

class _MarkerDetailPageState extends ConsumerState<MarkerDetailPage> {
  // 以 local state 持有最新 marker，編輯或新增照片後即時刷新 UI
  late MarkerEntity _marker;

  // 照片 PageView 的頁碼控制器
  final _pageController = PageController();
  int _photoIndex = 0;

  // 照片選取器（整頁共用）
  final _picker = ImagePicker();

  // 是否正在執行非同步操作（新增照片 / 刪除地標）
  bool _isBusy = false;

  // ── 生命週期 ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _marker = widget.marker;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── 工具方法 ───────────────────────────────────────────────────────────────

  /// 將 DateTime 格式化為 yyyy/MM/dd（不依賴 intl 套件）
  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  /// 將 XFile 複製到 App Documents/photos/ 目錄，回傳持久路徑
  ///
  /// image_picker 回傳的暫存路徑在 App 重啟後可能失效，
  /// 因此需複製到 getApplicationDocumentsDirectory() 確保長期存取。
  Future<String> _copyToDocuments(XFile xfile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }
    final ext = p.extension(xfile.name).isNotEmpty
        ? p.extension(xfile.name)
        : '.jpg';
    final dest = p.join(photosDir.path,
        '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(xfile.path).copy(dest);
    return dest;
  }

  // ── 事件：座標開啟 Google Maps ─────────────────────────────────────────────

  /// 點擊座標列，以 geo: URI 開啟外部地圖 App；
  /// 無地圖 App 時退回 Google Maps 網頁版
  Future<void> _openInMaps() async {
    final lat = _marker.latitude;
    final lng = _marker.longitude;
    final geoUri =
        Uri.parse('geo:$lat,$lng?q=$lat,$lng(${_marker.title})');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      final webUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── 事件：底部新增照片 ─────────────────────────────────────────────────────

  /// 從相簿多選照片，複製後 append 到現有 photoPaths 並寫入資料庫
  Future<void> _addPhotos() async {
    final remaining = _kMaxPhotos - _marker.photoPaths.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能新增 $_kMaxPhotos 張照片')),
      );
      return;
    }

    final files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;

    setState(() => _isBusy = true);
    try {
      // 複製每張照片到文件資料夾，確保路徑持久
      final copied = <String>[];
      for (final xfile in files.take(remaining)) {
        copied.add(await _copyToDocuments(xfile));
      }

      final updated = _marker.copyWith(
        photoPaths: [..._marker.photoPaths, ...copied],
      );
      await ref.read(markerNotifierProvider.notifier).edit(updated);

      if (!mounted) return;
      setState(() => _marker = updated);

      if (files.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已達上限，僅新增前 $remaining 張')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── 事件：移除單張照片 ─────────────────────────────────────────────────────

  /// 長按縮圖後顯示確認對話框，確認後移除並更新資料庫
  Future<void> _removePhoto(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('移除照片'),
        content: const Text('確定要移除這張照片嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final newPaths = List<String>.from(_marker.photoPaths)..removeAt(index);
    final updated = _marker.copyWith(photoPaths: newPaths);
    await ref.read(markerNotifierProvider.notifier).edit(updated);
    if (!mounted) return;
    setState(() {
      _marker = updated;
      // 頁碼超出範圍時退到最後一頁
      if (_photoIndex >= newPaths.length && _photoIndex > 0) {
        _photoIndex = newPaths.length - 1;
        _pageController.jumpToPage(_photoIndex);
      }
    });
  }

  // ── 事件：進入編輯頁 ───────────────────────────────────────────────────────

  /// 推入 EditMarkerPage，儲存成功後接收回傳的更新 entity 並刷新詳情頁
  Future<void> _goToEdit() async {
    final result = await Navigator.of(context).push<MarkerEntity>(
      MaterialPageRoute(
        builder: (_) => EditMarkerPage(marker: _marker),
      ),
    );
    if (result != null && mounted) {
      setState(() => _marker = result);
    }
  }

  // ── 事件：刪除地標 ─────────────────────────────────────────────────────────

  /// 顯示確認對話框，確認後呼叫 notifier.remove()，完成後返回列表頁
  Future<void> _deleteMarker() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined,
            size: 40, color: Colors.red),
        title: const Text('刪除地標'),
        content: Text('確定要刪除「${_marker.title}」嗎？\n此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await ref.read(markerNotifierProvider.notifier).remove(_marker.id);
    if (mounted) Navigator.of(context).pop();
  }

  // ── 建構 UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final photos = _marker.photoPaths;

    return Scaffold(
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Text(_marker.title, overflow: TextOverflow.ellipsis),
        actions: [
          // 編輯按鈕：pencil icon
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isBusy ? null : _goToEdit,
          ),
          // 刪除按鈕：trash icon，紅色以強調危險操作
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            color: Colors.red[400],
            onPressed: _isBusy ? null : _deleteMarker,
          ),
        ],
      ),

      // ── 主體 ────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // 可捲動區域（照片 + 資訊）
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 頂部照片 PageView
                  _PhotoSection(
                    photos: photos,
                    pageController: _pageController,
                    currentIndex: _photoIndex,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    onLongPressPhoto: _removePhoto,
                  ),

                  // 2. 基本資訊區塊
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: _InfoSection(
                      marker: _marker,
                      formattedDate: _fmtDate(_marker.createdAt),
                      onTapCoords: _openInMaps,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 底部「新增照片」按鈕列（固定在底部，不隨頁面捲動）
          _AddPhotoBar(
            isBusy: _isBusy,
            photoCount: photos.length,
            onAdd: _addPhotos,
          ),
        ],
      ),
    );
  }
}

// ── 1. 照片區塊 ────────────────────────────────────────────────────────────────

/// 頂部照片 PageView，長按可移除單張照片；無照片時顯示佔位插圖
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onLongPressPhoto,
  });

  final List<String> photos;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  /// 長按後由外層處理移除邏輯
  final ValueChanged<int> onLongPressPhoto;

  @override
  Widget build(BuildContext context) {
    // 無照片：顯示佔位插圖
    if (photos.isEmpty) {
      return Container(
        height: 220,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                '尚無照片',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // ── PageView 主體 ────────────────────────────────────────────────
          PageView.builder(
            controller: pageController,
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => GestureDetector(
              onLongPress: () => onLongPressPhoto(i),
              child: File(photos[i]).existsSync()
                  ? Image.file(
                      File(photos[i]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _brokenImage(),
                    )
                  : _brokenImage(),
            ),
          ),

          // ── 右下角頁碼標籤 「n / total」──────────────────────────────────
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentIndex + 1} / ${photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── 底部漸層 + 操作提示（長按刪除）──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                  ),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 8),
                child: const Text(
                  '長按照片可移除',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokenImage() => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image_outlined,
            size: 40, color: Colors.grey),
      );
}

// ── 2. 資訊區塊 ────────────────────────────────────────────────────────────────

/// 標題、國家、日期、評分、座標（可點擊開啟地圖）、心得 的完整資訊區塊
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.marker,
    required this.formattedDate,
    required this.onTapCoords,
  });

  final MarkerEntity marker;
  final String formattedDate;

  /// 點擊座標列後的回呼（開啟外部地圖）
  final VoidCallback onTapCoords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題（大字）
        Text(
          marker.title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // 國家
        _InfoRow(
          icon: Icons.flag_outlined,
          label: '國家',
          value: marker.country,
        ),
        // 日期
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: '日期',
          value: formattedDate,
        ),
        // 評分（用自訂 Widget 顯示星號）
        _InfoRow(
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          label: '評分',
          child: _StarDisplay(rating: marker.rating),
        ),
        // 座標（點擊後開啟 Google Maps）
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: '座標',
          value: '${marker.latitude.toStringAsFixed(5)}, '
              '${marker.longitude.toStringAsFixed(5)}',
          onTap: onTapCoords,
          trailing: Icon(
            Icons.open_in_new,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        // 心得區塊（有內容才顯示）
        if (marker.note.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionLabel('旅遊心得'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              marker.note,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

// ── 通用小元件 ─────────────────────────────────────────────────────────────────

/// 單列資訊（圖示 ＋ 標籤 ＋ 值），value 與 child 二擇一
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.value,
    this.child,
    this.onTap,
    this.trailing,
  }) : assert(value != null || child != null);

  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側圖示
            Icon(
              icon,
              size: 20,
              color: iconColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            // 固定寬度標籤（對齊各列）
            SizedBox(
              width: 36,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            // 值或自訂 Widget
            Expanded(
              child: child ??
                  Text(
                    value!,
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              // 可點擊時顯示藍色底線提示
                              color: onTap != null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              decoration: onTap != null
                                  ? TextDecoration.underline
                                  : null,
                            ),
                  ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 只讀星號列（1–5 顆星，filled / outline）
class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < rating ? Colors.amber : Colors.grey[400],
          size: 20,
        );
      }),
    );
  }
}

/// 小節標籤（粗體 + 左側色條）
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

// ── 3. 底部新增照片按鈕列 ──────────────────────────────────────────────────────

/// 固定底部的「新增照片」按鈕；達上限或執行中時停用
class _AddPhotoBar extends StatelessWidget {
  const _AddPhotoBar({
    required this.isBusy,
    required this.photoCount,
    required this.onAdd,
  });

  final bool isBusy;
  final int photoCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final atLimit = photoCount >= _kMaxPhotos;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, -3)),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: (isBusy || atLimit) ? null : onAdd,
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          atLimit
              ? '已達照片上限（$_kMaxPhotos 張）'
              : '新增照片（$photoCount / $_kMaxPhotos）',
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EditMarkerPage
// ══════════════════════════════════════════════════════════════════════════════
//
// 獨立的編輯頁面，接收現有 MarkerEntity 並預填所有欄位。
// 儲存成功後呼叫 notifier.edit()，並透過 Navigator.pop(updated)
// 將更新後的 entity 回傳給 MarkerDetailPage 即時刷新。

class EditMarkerPage extends ConsumerStatefulWidget {
  const EditMarkerPage({super.key, required this.marker});

  /// 要編輯的地標資料（預填到各欄位）
  final MarkerEntity marker;

  @override
  ConsumerState<EditMarkerPage> createState() => _EditMarkerPageState();
}

class _EditMarkerPageState extends ConsumerState<EditMarkerPage> {
  final _formKey = GlobalKey<FormState>();

  // 文字控制器以原始資料初始化
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _dateCtrl;

  late String? _country;
  late DateTime _date;
  late int _rating;

  bool _isSubmitting = false;

  // ── 生命週期 ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final m = widget.marker;
    _titleCtrl = TextEditingController(text: m.title);
    _noteCtrl = TextEditingController(text: m.note);
    _latCtrl = TextEditingController(text: m.latitude.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: m.longitude.toStringAsFixed(6));
    _date = m.createdAt;
    _dateCtrl = TextEditingController(text: _fmtDate(m.createdAt));
    _country = m.country;
    _rating = m.rating;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── 工具方法 ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  // ── 事件處理 ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '選擇拜訪日期',
      confirmText: '確認',
      cancelText: '取消',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateCtrl.text = _fmtDate(picked);
      });
    }
  }

  /// 開啟 MapPickerPage（直接 import，無需橋接）
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _latCtrl.text = result.latitude.toStringAsFixed(6);
        _lngCtrl.text = result.longitude.toStringAsFixed(6);
      });
    }
  }

  /// 驗證後呼叫 notifier.edit()，成功後 pop 並回傳更新後的 entity
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      // 照片路徑不在編輯頁修改，保留原始清單
      final updated = widget.marker.copyWith(
        title: _titleCtrl.text.trim(),
        country: _country!,
        createdAt: _date,
        latitude: double.parse(_latCtrl.text),
        longitude: double.parse(_lngCtrl.text),
        rating: _rating,
        note: _noteCtrl.text.trim(),
      );

      await ref.read(markerNotifierProvider.notifier).edit(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地標已更新！')),
        );
        // 回傳更新後的 entity，讓詳情頁即時刷新顯示
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── 建構 UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯地標'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _submit, child: const Text('儲存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 基本資訊 ──────────────────────────────────────────────
              const _EditHeader('基本資訊'),

              // 標題
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題 *',
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
              ),
              const SizedBox(height: 12),

              // 國家下拉
              DropdownButtonFormField<String>(
                initialValue: _country,
                decoration: const InputDecoration(
                  labelText: '國家 *',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                isExpanded: true,
                hint: const Text('請選擇國家'),
                items: _kCountries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _country = v),
                validator: (v) => v == null ? '請選擇國家' : null,
              ),
              const SizedBox(height: 12),

              // 日期
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: '拜訪日期',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) =>
                    (v == null || v.isEmpty) ? '請選擇拜訪日期' : null,
              ),

              // ── 評分 ──────────────────────────────────────────────────
              const _EditHeader('整體評分'),

              Row(
                children: [
                  _EditStars(
                    rating: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _kRatingLabels[_rating - 1],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),

              // ── 座標 ──────────────────────────────────────────────────
              const _EditHeader('座標位置'),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: const InputDecoration(
                        labelText: '緯度 *',
                        prefixIcon: Icon(Icons.north),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '請輸入緯度';
                        final n = double.tryParse(v);
                        if (n == null) return '格式錯誤';
                        if (n < -90 || n > 90) return '-90 ~ 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: const InputDecoration(
                        labelText: '經度 *',
                        prefixIcon: Icon(Icons.east),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '請輸入經度';
                        final n = double.tryParse(v);
                        if (n == null) return '格式錯誤';
                        if (n < -180 || n > 180) return '-180 ~ 180';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined),
                label: const Text('使用地圖選取座標'),
              ),

              // ── 心得 ──────────────────────────────────────────────────
              const _EditHeader('旅遊心得'),

              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '心得',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.edit_note_outlined),
                  ),
                ),
                maxLines: 5,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
              ),

              // ── 送出 ──────────────────────────────────────────────────
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSubmitting ? '儲存中…' : '儲存變更'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── EditMarkerPage 專用小元件（避免與詳情頁命名衝突）────────────────────────────

/// 編輯頁區塊標題
class _EditHeader extends StatelessWidget {
  const _EditHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

/// 編輯頁可互動星號評分元件
class _EditStars extends StatelessWidget {
  const _EditStars({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = i + 1;
        return IconButton(
          onPressed: () => onChanged(v),
          tooltip: '$v 星',
          icon: Icon(
            v <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: v <= rating ? Colors.amber : Colors.grey[400],
            size: 34,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        );
      }),
    );
  }
}
