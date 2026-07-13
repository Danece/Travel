import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/country_names.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/weather_service.dart';
import '../../../../core/utils/country_flag.dart';
import '../../../../core/widgets/weather_icon_widget.dart';
import '../../domain/entities/marker_category.dart';
import '../providers/marker_provider.dart';
import '../models/map_picker_result.dart';
import 'map_picker_page.dart';


const int _kMaxPhotos = 10;

class CreateMarkerPage extends ConsumerStatefulWidget {
  const CreateMarkerPage({super.key});

  @override
  ConsumerState<CreateMarkerPage> createState() => _CreateMarkerPageState();
}

class _CreateMarkerPageState extends ConsumerState<CreateMarkerPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _dateController = TextEditingController();

  String? _selectedCountry;
  /// true 表示國家為 Geocoding API 自動偵測填入，用於顯示提示圖示
  bool _countryAutoDetected = false;
  DateTime _selectedDate = DateTime.now();
  int _rating = 3;
  MarkerCategory _category = MarkerCategory.attraction;
  final List<String> _photoPaths = [];
  bool _isSubmitting = false;

  /// 天氣 API 回傳結果；null 表示尚未取得或取得失敗
  WeatherResult? _weatherResult;
  /// true 表示正在呼叫天氣 API（顯示 loading 狀態）
  bool _isLoadingWeather = false;
  /// true 表示曾嘗試取得天氣但失敗（區分「未取得」與「取得失敗」）
  bool _weatherFetchFailed = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
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

  String _formatDate(DateTime date) =>
      '${date.year}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';

  Future<String> _copyToDocuments(XFile xfile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }
    final ext = p.extension(xfile.name).isNotEmpty
        ? p.extension(xfile.name)
        : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(photosDir.path, fileName);
    await File(xfile.path).copy(destPath);
    return destPath;
  }

  void _showPhotoSourcePicker() {
    final l10n = AppLocalizations.of(context);
    if (_photoPaths.length >= _kMaxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosReached(_kMaxPhotos))),
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
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.fromGallery),
              subtitle: Text(l10n.multipleSelection),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhoto),
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

  Future<void> _pickFromGallery() async {
    final l10n = AppLocalizations.of(context);
    final remaining = _kMaxPhotos - _photoPaths.length;
    if (remaining <= 0) return;

    final files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;

    final toAdd = files.take(remaining).toList();
    final copied = <String>[];
    for (final xfile in toAdd) {
      copied.add(await _copyToDocuments(xfile));
    }

    if (!mounted) return;
    setState(() => _photoPaths.addAll(copied));

    if (files.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onlyAddedFirst(remaining))),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    if (_photoPaths.length >= _kMaxPhotos) return;

    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null || !mounted) return;

    final destPath = await _copyToDocuments(xfile);
    if (!mounted) return;
    setState(() => _photoPaths.add(destPath));
  }

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: l10n.selectDate,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
      // 日期變更後重新取得天氣（座標已填入才有意義）
      await _fetchWeather();
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result == null || !mounted) return;

    // 更新座標欄位
    setState(() {
      _latController.text = result.latLng.latitude.toStringAsFixed(6);
      _lngController.text = result.latLng.longitude.toStringAsFixed(6);
    });

    // 若 Geocoding API 成功偵測到國家，自動填入並提示用戶
    final detected = result.detectedCountry;
    if (detected != null) {
      final en = toEnglishName(detected); // 中文 → 英文鍵（資料庫儲存值）
      if (en != null && mounted) {
        setState(() {
          _selectedCountry = en;
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

    // 座標確認後自動取得天氣資訊
    await _fetchWeather();
  }

  /// 依目前座標與日期呼叫天氣 API，更新 [_weatherResult]。
  ///
  /// 座標尚未填入時直接返回；取得失敗時設定 [_weatherFetchFailed] 為 true。
  Future<void> _fetchWeather() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherFetchFailed = false;
    });

    final service = ref.read(weatherServiceProvider);
    final result = await service.getWeather(lat, lng, _selectedDate);

    if (!mounted) return;
    setState(() {
      _weatherResult = result;
      _isLoadingWeather = false;
      _weatherFetchFailed = result == null;
    });
  }

  void _removePhoto(int index) {
    final l10n = AppLocalizations.of(context);
    showDialog<bool>(
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
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() => _photoPaths.removeAt(index));
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

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
            category: _category.name,
            // 天氣資訊（取得失敗時欄位為 null，不影響儲存）
            weatherCondition: _weatherResult?.condition,
            weatherDescription: _weatherResult?.description,
            temperature: _weatherResult?.temperature,
            humidity: _weatherResult?.humidity,
            weatherIcon: _weatherResult?.icon,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.markerSaved)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createMarkerTitle),
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
            TextButton(
              onPressed: _submit,
              child: Text(l10n.save),
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
              _SectionHeader(l10n.basicInfo),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.titleField,
                  hintText: l10n.titleHint,
                  prefixIcon: const Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.titleRequired;
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedCountry,
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
                // 選項列表：使用 countryNameMap 的完整國家清單
                items: countryNameMap.keys
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
                selectedItemBuilder: (context) => countryNameMap.keys
                    .map((c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(countryFlag(c),
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(l10n.isEn ? c : (countryNameMap[c] ?? c)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedCountry = v;
                  _countryAutoDetected = false; // 手動選擇後清除自動偵測標記
                }),
                validator: (v) =>
                    v == null ? l10n.countryRequired : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dateController,
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

              _SectionHeader(l10n.overallRating),

              Row(
                children: [
                  _StarRating(
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

              _SectionHeader(l10n.markerCategory),

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

              _SectionHeader(l10n.coordinates),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: InputDecoration(
                        labelText: l10n.latitude,
                        hintText: l10n.latHint,
                        prefixIcon: const Icon(Icons.north),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*')),
                      ],
                      textInputAction: TextInputAction.next,
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
                      controller: _lngController,
                      decoration: InputDecoration(
                        labelText: l10n.longitude,
                        hintText: l10n.lngHint,
                        prefixIcon: const Icon(Icons.east),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*')),
                      ],
                      textInputAction: TextInputAction.done,
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

              // ── 天氣資訊區塊（有座標後才顯示）──────────────────────────
              if (_latController.text.isNotEmpty &&
                  _lngController.text.isNotEmpty) ...[
                _SectionHeader('天氣資訊'),
                _WeatherSection(
                  isLoading: _isLoadingWeather,
                  result: _weatherResult,
                  failed: _weatherFetchFailed,
                  onRetry: _fetchWeather,
                ),
                const SizedBox(height: 4),
              ],

              _SectionHeader(l10n.travelNotes),

              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: l10n.travelNotes,
                  hintText: l10n.notesHint,
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.edit_note_outlined),
                  ),
                ),
                maxLines: 5,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
              ),

              _SectionHeader(
                  l10n.travelPhotos(_photoPaths.length, _kMaxPhotos)),

              _PhotoGrid(
                photoPaths: _photoPaths,
                showAddButton: _photoPaths.length < _kMaxPhotos,
                onAdd: _showPhotoSourcePicker,
                onRemove: _removePhoto,
                l10n: l10n,
              ),

              const SizedBox(height: 32),

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
                label: Text(_isSubmitting ? l10n.saving : l10n.saveMarker),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 私有子元件 ────────────────────────────────────────────────────────────────

/// 天氣資訊顯示區塊：loading / 成功卡片 / 失敗提示 三種狀態。
class _WeatherSection extends StatelessWidget {
  const _WeatherSection({
    required this.isLoading,
    required this.result,
    required this.failed,
    required this.onRetry,
  });

  final bool isLoading;
  final WeatherResult? result;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 載入中
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('取得天氣中…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 取得失敗
    if (failed && result == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '天氣資訊取得失敗，可手動略過',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重新取得', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    // 有資料：顯示天氣卡片
    if (result != null) {
      return _WeatherCard(result: result!, onRetry: onRetry);
    }

    // 初始狀態（座標剛填入但尚未觸發 fetch）
    return const SizedBox.shrink();
  }
}

/// 天氣資訊卡片：圖示 + 描述 + 溫度 + 濕度 + 重新取得按鈕。
class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.result, required this.onRetry});

  final WeatherResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標頭列：「天氣資訊」 + 重新取得按鈕
          Row(
            children: [
              const Icon(Icons.wb_cloudy_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                '天氣資訊',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重新取得', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 資料列：天氣圖示 + 描述 + 溫度 + 濕度
          Row(
            children: [
              WeatherIconWidget(
                condition: result.icon,
                size: 28,
                showLabel: false,
              ),
              const SizedBox(width: 10),
              Text(
                result.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.thermostat_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                '${result.temperature}°C',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.water_drop_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                '濕度 ${result.humidity}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onChanged});

  final int rating;
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
          tooltip: '$starValue ★',
          icon: Icon(
            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isSelected ? Colors.amber : Colors.grey[400],
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

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photoPaths,
    required this.showAddButton,
    required this.onAdd,
    required this.onRemove,
    required this.l10n,
  });

  final List<String> photoPaths;
  final bool showAddButton;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final itemCount = photoPaths.length + (showAddButton ? 1 : 0);
    if (itemCount == 0) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (showAddButton && i == photoPaths.length) {
          return _AddPhotoCell(onTap: onAdd, l10n: l10n);
        }
        return _PhotoCell(
          path: photoPaths[i],
          isCover: i == 0,
          onRemove: () => onRemove(i),
          l10n: l10n,
        );
      },
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.path,
    required this.onRemove,
    required this.l10n,
    this.isCover = false,
  });

  final String path;
  final VoidCallback onRemove;
  final bool isCover;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined,
                  size: 28, color: Colors.grey),
            ),
          ),
        ),
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
                boxShadow: [
                  BoxShadow(blurRadius: 3, color: Colors.black38)
                ],
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        if (isCover)
          Positioned(
            left: 0,
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6)
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Text(
                l10n.cover,
                textAlign: TextAlign.center,
                style: const TextStyle(
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

class _AddPhotoCell extends StatelessWidget {
  const _AddPhotoCell({required this.onTap, required this.l10n});
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.5),
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
              l10n.addPhoto,
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
