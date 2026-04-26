import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers/marker_provider.dart';
import 'map_picker_page.dart';

// ── 常見國家清單（依地區分組，共 50 個）────────────────────────────────────
const List<String> _kCommonCountries = [
  // 東亞
  'Taiwan', 'Japan', 'South Korea', 'China', 'Hong Kong', 'Macau', 'Mongolia',
  // 東南亞
  'Thailand', 'Vietnam', 'Singapore', 'Malaysia', 'Indonesia',
  'Philippines', 'Cambodia', 'Myanmar',
  // 南亞
  'India', 'Nepal', 'Sri Lanka', 'Maldives', 'Bhutan',
  // 歐洲
  'United Kingdom', 'France', 'Germany', 'Italy', 'Spain',
  'Portugal', 'Netherlands', 'Switzerland', 'Austria', 'Belgium',
  'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland',
  'Czech Republic', 'Hungary', 'Greece', 'Croatia', 'Iceland',
  // 美洲
  'United States', 'Canada', 'Mexico', 'Brazil', 'Argentina', 'Peru',
  // 大洋洲
  'Australia', 'New Zealand',
  // 中東
  'UAE', 'Israel',
  // 非洲
  'Egypt', 'Morocco',
];

// 照片數量上限
const int _kMaxPhotos = 10;

// ── 主頁面 ─────────────────────────────────────────────────────────────────

class CreateMarkerPage extends ConsumerStatefulWidget {
  const CreateMarkerPage({super.key});

  @override
  ConsumerState<CreateMarkerPage> createState() => _CreateMarkerPageState();
}

class _CreateMarkerPageState extends ConsumerState<CreateMarkerPage> {
  // 表單驗證 key
  final _formKey = GlobalKey<FormState>();

  // 文字控制器
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _dateController = TextEditingController();

  // 表單狀態
  String? _selectedCountry;
  DateTime _selectedDate = DateTime.now();
  int _rating = 3; // 預設 3 星
  final List<String> _photoPaths = [];
  bool _isSubmitting = false;

  // ImagePicker 實例（整個頁面共用同一個）
  final _picker = ImagePicker();

  // ── 生命週期 ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 初始日期欄位顯示今日
    _dateController.text = _formatDate(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ── 工具方法 ──────────────────────────────────────────────────────────────

  /// 將 DateTime 格式化為 yyyy/MM/dd 字串（不依賴 intl 套件）
  String _formatDate(DateTime date) =>
      '${date.year}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';

  /// 將 XFile 複製到 App Documents/photos/ 資料夾，回傳永久檔案路徑
  ///
  /// 直接使用 image_picker 回傳的暫存路徑在 App 重啟後可能失效，
  /// 因此需要複製到 getApplicationDocumentsDirectory() 確保持久存在。
  Future<String> _copyToDocuments(XFile xfile) async {
    // 取得 App 文件目錄
    final docsDir = await getApplicationDocumentsDirectory();

    // 確保 photos/ 子資料夾存在
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }

    // 以時間戳避免同名衝突，保留原始副檔名
    final ext = p.extension(xfile.name).isNotEmpty
        ? p.extension(xfile.name)
        : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(photosDir.path, fileName);

    // 執行檔案複製
    await File(xfile.path).copy(destPath);
    return destPath;
  }

  // ── 照片選取流程 ──────────────────────────────────────────────────────────

  /// 顯示來源選擇底部面板（相簿 / 拍照）
  void _showPhotoSourcePicker() {
    // 已達上限時直接提示，不顯示選項
    if (_photoPaths.length >= _kMaxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能新增 $_kMaxPhotos 張照片')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            // 從相簿選取（支援多選）
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('從相簿選取'),
              subtitle: const Text('可一次選取多張'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            // 拍照
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 從相簿多選照片，複製後更新狀態
  Future<void> _pickFromGallery() async {
    // 計算剩餘可新增數量
    final remaining = _kMaxPhotos - _photoPaths.length;
    if (remaining <= 0) return;

    // pickMultiImage 可指定 limit 限制本次最多選幾張
    final files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;

    // 逐一複製到 Documents，若超過上限則截斷並提示
    final toAdd = files.take(remaining).toList();
    final copied = <String>[];
    for (final xfile in toAdd) {
      copied.add(await _copyToDocuments(xfile));
    }

    if (!mounted) return;
    setState(() => _photoPaths.addAll(copied));

    // 如果選取數量超過本次剩餘配額，提示使用者已截斷
    if (files.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已達上限，僅新增前 $remaining 張')),
      );
    }
  }

  /// 使用相機拍照，複製後更新狀態
  Future<void> _pickFromCamera() async {
    if (_photoPaths.length >= _kMaxPhotos) return;

    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null || !mounted) return;

    final destPath = await _copyToDocuments(xfile);
    if (!mounted) return;
    setState(() => _photoPaths.add(destPath));
  }

  // ── 其他事件處理 ──────────────────────────────────────────────────────────

  /// 開啟日期選擇器，選取後更新欄位文字與狀態
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '選擇拜訪日期',
      confirmText: '確認',
      cancelText: '取消',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  /// 開啟 MapPickerPage，接收回傳的 LatLng 後自動填入緯度／經度欄位
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    // result 為 null 表示使用者按返回鍵離開，不更新欄位
    if (result != null && mounted) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
      });
    }
  }

  /// 點擊右上角 X 刪除照片（直接刪除，不需二次確認）
  void _removePhoto(int index) {
    showDialog<bool>(
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
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() => _photoPaths.removeAt(index));
      }
    });
  }

  /// 驗證並送出表單，成功後關閉頁面
  Future<void> _submit() async {
    // 收起鍵盤
    FocusScope.of(context).unfocus();

    // 執行所有欄位驗證
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(markerNotifierProvider.notifier).add(
            title: _titleController.text.trim(),
            country: _selectedCountry!,
            createdAt: _selectedDate,
            latitude: double.parse(_latController.text),
            longitude: double.parse(_lngController.text),
            rating: _rating,
            note: _noteController.text.trim(),
            photoPaths: List<String>.from(_photoPaths),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地標已儲存！')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── 建構 UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增地標'),
        actions: [
          // AppBar 快速送出按鈕
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
            TextButton(
              onPressed: _submit,
              child: const Text('儲存'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 基本資訊區塊 ────────────────────────────────────────────
              const _SectionHeader('基本資訊'),

              // 1. 標題（必填）
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '標題 *',
                  hintText: '例：東京鐵塔',
                  prefixIcon: Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '請輸入標題';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 2. 國家（必填，下拉清單）
              DropdownButtonFormField<String>(
                initialValue: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: '國家 *',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                isExpanded: true,
                hint: const Text('請選擇國家'),
                // 依字母排序並對應 50 個常見國家清單
                items: _kCommonCountries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCountry = v),
                validator: (v) => v == null ? '請選擇國家' : null,
              ),
              const SizedBox(height: 12),

              // 3. 建立日期（點擊觸發 DatePicker，預設今日）
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: '拜訪日期',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                readOnly: true, // 禁止直接鍵盤輸入，只透過 DatePicker 修改
                onTap: _pickDate,
                validator: (v) =>
                    (v == null || v.isEmpty) ? '請選擇拜訪日期' : null,
              ),

              // ── 評分區塊 ────────────────────────────────────────────────
              const _SectionHeader('整體評分'),

              // 5. 星號評分（1–5 星，預設 3 星）
              Row(
                children: [
                  _StarRating(
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

              // ── 座標區塊 ────────────────────────────────────────────────
              const _SectionHeader('座標位置'),

              // 6. 緯度／經度（手動輸入，下一步換成地圖選點）
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: '緯度 *',
                        hintText: '例：25.0330',
                        prefixIcon: Icon(Icons.north),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        // 只允許數字、負號、小數點
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*')),
                      ],
                      textInputAction: TextInputAction.next,
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
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: '經度 *',
                        hintText: '例：121.5654',
                        prefixIcon: Icon(Icons.east),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*')),
                      ],
                      textInputAction: TextInputAction.done,
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

              // 地圖選點按鈕
              OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined),
                label: const Text('使用地圖選取座標'),
              ),

              // ── 旅遊心得區塊 ────────────────────────────────────────────
              const _SectionHeader('旅遊心得'),

              // 4. 心得（maxLines:5，最多 2000 字，字數統計由 maxLength 自動顯示）
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '心得',
                  hintText: '記錄這次旅遊的感受、推薦理由…',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.edit_note_outlined),
                  ),
                ),
                maxLines: 5,
                maxLength: 2000, // Flutter 自動在右下角顯示「已輸入字數/2000」
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
              ),

              // ── 照片區塊 ────────────────────────────────────────────────
              _SectionHeader(
                  '旅遊照片（${_photoPaths.length}/$_kMaxPhotos）'),

              // 7. 照片 GridView + 加號按鈕
              _PhotoGrid(
                photoPaths: _photoPaths,
                // 已達上限時隱藏加號按鈕
                showAddButton: _photoPaths.length < _kMaxPhotos,
                onAdd: _showPhotoSourcePicker,
                onRemove: _removePhoto,
              ),

              // ── 送出按鈕 ────────────────────────────────────────────────
              const SizedBox(height: 32),

              // 8. 送出：呼叫 MarkerNotifier.add()，成功後 Navigator.pop()
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSubmitting ? '儲存中…' : '儲存地標'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 評分文字對照表 ───────────────────────────────────────────────────────────
const List<String> _kRatingLabels = ['很差', '普通', '不錯', '推薦', '必去！'];

// ── 私有子元件 ───────────────────────────────────────────────────────────────

/// 區塊標題
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
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

/// 1–5 星評分元件（Row of IconButton）
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onChanged});

  /// 目前評分（1–5）
  final int rating;

  /// 使用者點選後的回呼
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final isSelected = starValue <= rating;
        return IconButton(
          onPressed: () => onChanged(starValue),
          tooltip: '$starValue 星',
          icon: Icon(
            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isSelected ? Colors.amber : Colors.grey[400],
            size: 34,
          ),
          // 縮小按鈕間距，讓五顆星緊湊排列
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        );
      }),
    );
  }
}

/// 照片 GridView：顯示已選縮圖 + 最後一格為加號新增按鈕
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photoPaths,
    required this.showAddButton,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photoPaths;

  /// 是否顯示加號按鈕（達上限時隱藏）
  final bool showAddButton;
  final VoidCallback onAdd;

  /// 傳入索引值，由外層呼叫刪除邏輯
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    // 若顯示加號按鈕，總格數 = 照片數 + 1；否則等於照片數
    final itemCount = photoPaths.length + (showAddButton ? 1 : 0);

    // 沒有任何照片且不顯示加號：回傳空白區域（理論上不會發生）
    if (itemCount == 0) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      // 嵌入 SingleChildScrollView，禁止 GridView 自身捲動
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // 最後一格：加號新增按鈕（僅在未達上限時出現）
        if (showAddButton && i == photoPaths.length) {
          return _AddPhotoCell(onTap: onAdd);
        }
        // 其他格：照片縮圖（含右上角刪除按鈕）
        return _PhotoCell(
          path: photoPaths[i],
          isCover: i == 0, // 第一張標記為封面
          onRemove: () => onRemove(i),
        );
      },
    );
  }
}

/// 照片縮圖格（含刪除按鈕與封面標籤）
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.path,
    required this.onRemove,
    this.isCover = false,
  });

  final String path;
  final VoidCallback onRemove;

  /// 是否為封面（顯示「封面」標籤）
  final bool isCover;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 縮圖（File 圖片）──────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            // 圖片讀取失敗時顯示佔位圖示（例如路徑已被刪除）
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined,
                  size: 28, color: Colors.grey),
            ),
          ),
        ),

        // ── 右上角刪除按鈕（紅色圓形）────────────────────────────────────
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black38)],
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),

        // ── 左下角「封面」標籤（僅第一張顯示）────────────────────────────
        if (isCover)
          Positioned(
            left: 0,
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                // 半透明深色漸層，讓標籤文字清晰可見
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: const Text(
                '封面',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 加號新增照片按鈕格
class _AddPhotoCell extends StatelessWidget {
  const _AddPhotoCell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 30,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              '新增照片',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
