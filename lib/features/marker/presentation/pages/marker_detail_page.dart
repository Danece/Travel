import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/country_names.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/country_flag.dart';
import '../../../../core/widgets/weather_icon_widget.dart';
import '../../domain/entities/marker_category.dart';
import '../../domain/entities/marker_entity.dart';
import '../providers/marker_provider.dart';
import '../models/map_picker_result.dart';
import 'map_picker_page.dart';

const int _kMaxPhotos = 10;

// ── 地標詳情頁 ────────────────────────────────────────────────────────────────

class MarkerDetailPage extends ConsumerStatefulWidget {
  const MarkerDetailPage({super.key, required this.marker});

  final MarkerEntity marker;

  @override
  ConsumerState<MarkerDetailPage> createState() => _MarkerDetailPageState();
}

class _MarkerDetailPageState extends ConsumerState<MarkerDetailPage> {
  late MarkerEntity _marker;
  final _pageController = PageController();
  int _photoIndex = 0;
  final _picker = ImagePicker();
  bool _isBusy = false;

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

  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  Future<String> _copyToDocuments(XFile xfile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }
    final ext = p.extension(xfile.name).isNotEmpty
        ? p.extension(xfile.name)
        : '.jpg';
    final dest = p.join(
        photosDir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(xfile.path).copy(dest);
    return dest;
  }

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

  Future<void> _addPhotos() async {
    final l10n = AppLocalizations.of(context);
    final remaining = _kMaxPhotos - _marker.photoPaths.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosReached(_kMaxPhotos))),
      );
      return;
    }

    final files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;

    setState(() => _isBusy = true);
    try {
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
          SnackBar(content: Text(l10n.onlyAddedFirst(remaining))),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _removePhoto(int index) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removePhoto),
        content: Text(l10n.removePhotoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove,
                style: const TextStyle(color: Colors.red)),
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
      if (_photoIndex >= newPaths.length && _photoIndex > 0) {
        _photoIndex = newPaths.length - 1;
        _pageController.jumpToPage(_photoIndex);
      }
    });
  }

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

  Future<void> _deleteMarker() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined,
            size: 40, color: Colors.red),
        title: Text(l10n.deleteMarkerTitle),
        content: Text(l10n.deleteMarkerContent(_marker.title)),
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
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await ref.read(markerNotifierProvider.notifier).remove(_marker.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photos = _marker.photoPaths;

    return Scaffold(
      appBar: AppBar(
        title: Text(_marker.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.editTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isBusy ? null : _goToEdit,
          ),
          IconButton(
            tooltip: l10n.deleteTooltip,
            icon: const Icon(Icons.delete_outline),
            color: Colors.red[400],
            onPressed: _isBusy ? null : _deleteMarker,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PhotoSection(
                    photos: photos,
                    pageController: _pageController,
                    currentIndex: _photoIndex,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    onTapPhoto: (i) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PhotoViewerPage(
                          photos: photos,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    onLongPressPhoto: _removePhoto,
                    l10n: l10n,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: _InfoSection(
                      marker: _marker,
                      formattedDate: _fmtDate(_marker.createdAt),
                      onTapCoords: _openInMaps,
                      l10n: l10n,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _AddPhotoBar(
            isBusy: _isBusy,
            photoCount: photos.length,
            onAdd: _addPhotos,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

// ── 1. 照片區塊 ────────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapPhoto,
    required this.onLongPressPhoto,
    required this.l10n,
  });

  final List<String> photos;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTapPhoto;
  final ValueChanged<int> onLongPressPhoto;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
                l10n.noPhotos,
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
          PageView.builder(
            controller: pageController,
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onTapPhoto(i),
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
                child: Text(
                  l10n.longPressHint,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
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

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.marker,
    required this.formattedDate,
    required this.onTapCoords,
    required this.l10n,
  });

  final MarkerEntity marker;
  final String formattedDate;
  final VoidCallback onTapCoords;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          marker.title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _InfoRow(
          icon: Icons.flag_outlined,
          label: l10n.countryLabel,
          value: '${countryFlag(marker.country)} ${marker.country}',
        ),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: l10n.dateLabel,
          value: formattedDate,
        ),
        _InfoRow(
          icon: Icons.category_outlined,
          label: l10n.categoryLabel,
          value: MarkerCategory.fromString(marker.category)
              .localizedDisplay(l10n.isEn),
        ),
        _InfoRow(
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          label: l10n.ratingLabel,
          child: _StarDisplay(rating: marker.rating),
        ),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: l10n.coordsLabel,
          value: '${marker.latitude.toStringAsFixed(5)}, '
              '${marker.longitude.toStringAsFixed(5)}',
          onTap: onTapCoords,
          trailing: Icon(
            Icons.open_in_new,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        // 天氣資訊列：有紀錄天氣才顯示，舊資料或未取得時隱藏
        if (marker.weatherCondition != null)
          _WeatherInfoRow(marker: marker),

        if (marker.note.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionLabel(l10n.travelNotesSection),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: child ??
                  Text(
                    value!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
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

/// 天氣資訊列：與座標列使用相同的 Row 排版。
///
/// 左側以 [WeatherIconWidget] 取代一般 [Icon]，
/// 右側依序顯示中文描述、氣溫、濕度。
/// 僅在 [marker.weatherCondition] 不為 null 時渲染。
class _WeatherInfoRow extends StatelessWidget {
  const _WeatherInfoRow({required this.marker});

  final MarkerEntity marker;

  @override
  Widget build(BuildContext context) {
    final condition = marker.weatherCondition!; // 呼叫端已確認非 null
    final description = marker.weatherDescription ?? condition;
    final textTheme = Theme.of(context).textTheme;
    final subtleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 天氣 icon（與座標列 Icons.location_on_outlined 同寬度區域）
          WeatherIconWidget(condition: condition, size: 28),
          const SizedBox(width: 12),

          // 標籤（與其他列的 label 對齊）
          SizedBox(
            width: 40,
            child: Text(
              '天氣',
              textAlign: TextAlign.right,
              style: textTheme.bodySmall?.copyWith(color: subtleColor),
            ),
          ),
          const SizedBox(width: 12),

          // 天氣資料：描述 + 溫度 + 濕度
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 中文天氣描述
                Text(description, style: textTheme.bodyMedium),

                // 氣溫（有值才顯示）
                if (marker.temperature != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thermostat_outlined,
                          size: 15, color: subtleColor),
                      const SizedBox(width: 2),
                      Text(
                        '${marker.temperature}°C',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),

                // 濕度（有值才顯示）
                if (marker.humidity != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 15, color: subtleColor),
                      const SizedBox(width: 2),
                      Text(
                        '濕度 ${marker.humidity}%',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: subtleColor),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _AddPhotoBar extends StatelessWidget {
  const _AddPhotoBar({
    required this.isBusy,
    required this.photoCount,
    required this.onAdd,
    required this.l10n,
  });

  final bool isBusy;
  final int photoCount;
  final VoidCallback onAdd;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final atLimit = photoCount >= _kMaxPhotos;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
              blurRadius: 10,
              color: Colors.black12,
              offset: Offset(0, -3)),
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
              ? l10n.maxPhotosLabel(_kMaxPhotos)
              : l10n.addPhotoCount(photoCount, _kMaxPhotos),
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

class EditMarkerPage extends ConsumerStatefulWidget {
  const EditMarkerPage({super.key, required this.marker});

  final MarkerEntity marker;

  @override
  ConsumerState<EditMarkerPage> createState() => _EditMarkerPageState();
}

class _EditMarkerPageState extends ConsumerState<EditMarkerPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _dateCtrl;

  late String? _country;
  /// true 表示國家為 Geocoding API 自動偵測填入，用於顯示提示圖示
  bool _countryAutoDetected = false;
  late DateTime _date;
  late int _rating;
  late MarkerCategory _category;

  bool _isSubmitting = false;

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
    _category = MarkerCategory.fromString(m.category);
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

  String _fmtDate(DateTime d) =>
      '${d.year}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: l10n.selectDate,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateCtrl.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result == null || !mounted) return;

    // 更新座標欄位
    setState(() {
      _latCtrl.text = result.latLng.latitude.toStringAsFixed(6);
      _lngCtrl.text = result.latLng.longitude.toStringAsFixed(6);
    });

    // 若 Geocoding API 成功偵測到國家，自動填入並提示用戶
    final detected = result.detectedCountry;
    if (detected != null) {
      final en = toEnglishName(detected); // 中文 → 英文鍵（資料庫儲存值）
      if (en != null && mounted) {
        setState(() {
          _country = en;
          _countryAutoDetected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已自動偵測國家：$detected'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final updated = widget.marker.copyWith(
        title: _titleCtrl.text.trim(),
        country: _country!,
        createdAt: _date,
        latitude: double.parse(_latCtrl.text),
        longitude: double.parse(_lngCtrl.text),
        rating: _rating,
        note: _noteCtrl.text.trim(),
        category: _category.name,
      );

      await ref.read(markerNotifierProvider.notifier).edit(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.markerUpdated)),
        );
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 若現有標記的國家不在 countryNameMap（例如 CSV 匯入的舊資料），加在清單最前面
    final allCountries = countryNameMap.keys.toList();
    final dropdownCountries =
        (_country != null && !countryNameMap.containsKey(_country))
            ? [_country!, ...allCountries]
            : allCountries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editMarkerTitle),
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
            TextButton(onPressed: _submit, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EditHeader(l10n.basicInfo),

              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.titleField,
                  prefixIcon: const Icon(Icons.title),
                ),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.titleRequired : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _country,
                decoration: InputDecoration(
                  labelText: l10n.countryField,
                  prefixIcon: const Icon(Icons.flag_outlined),
                  // 自動偵測時顯示小圖示提示
                  suffix: _countryAutoDetected
                      ? const Tooltip(
                          message: '已自動偵測',
                          child: Icon(
                            Icons.my_location,
                            size: 16,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
                isExpanded: true,
                hint: Text(l10n.selectCountry),
                items: dropdownCountries
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Text(countryFlag(c),
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.isEn ? c : (countryNameMap[c] ?? c),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _country = v;
                  _countryAutoDetected = false; // 手動選擇後清除自動偵測標記
                }),
                validator: (v) => v == null ? l10n.countryRequired : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dateCtrl,
                decoration: InputDecoration(
                  labelText: l10n.visitDate,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: const Icon(Icons.edit_calendar_outlined),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.dateRequired : null,
              ),

              _EditHeader(l10n.overallRating),

              Row(
                children: [
                  _EditStars(
                    rating: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.ratingLabels[_rating - 1],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),

              _EditHeader(l10n.markerCategory),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: MarkerCategory.values.map((cat) {
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat.localizedDisplay(l10n.isEn)),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                          : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  );
                }).toList(),
              ),

              _EditHeader(l10n.coordinates),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.latitude,
                        prefixIcon: const Icon(Icons.north),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.latRequired;
                        }
                        final n = double.tryParse(v);
                        if (n == null) return l10n.formatError;
                        if (n < -90 || n > 90) return '-90 ~ 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.longitude,
                        prefixIcon: const Icon(Icons.east),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.lngRequired;
                        }
                        final n = double.tryParse(v);
                        if (n == null) return l10n.formatError;
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
                label: Text(l10n.pickOnMap),
              ),

              _EditHeader(l10n.travelNotes),

              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: l10n.travelNotes,
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.edit_note_outlined),
                  ),
                ),
                maxLines: 5,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
              ),

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
                label: Text(
                    _isSubmitting ? l10n.saving : l10n.saveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── EditMarkerPage 專用小元件 ─────────────────────────────────────────────────

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

// ── 全螢幕照片查看器 ───────────────────────────────────────────────────────────

class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({
    required this.photos,
    required this.initialIndex,
  });

  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _ctrl;
  late int _index;
  late final List<bool> _fileExists;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
    _fileExists = widget.photos.map((p) => File(p).existsSync()).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_index + 1} / ${widget.photos.length}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          if (!_fileExists[i]) {
            return const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 64),
            );
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.file(File(widget.photos[i]), fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

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
          tooltip: '$v ★',
          icon: Icon(
            v <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: v <= rating ? Colors.amber : Colors.grey[400],
            size: 34,
          ),
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
        );
      }),
    );
  }
}
