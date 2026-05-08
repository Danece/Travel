import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../domain/entities/marker_category.dart';
import '../providers/marker_provider.dart';
import 'map_picker_page.dart';

const Map<String, String> _kCountryFlags = {
  'Taiwan': '🇹🇼', 'Japan': '🇯🇵', 'South Korea': '🇰🇷', 'China': '🇨🇳',
  'Hong Kong': '🇭🇰', 'Macau': '🇲🇴', 'Mongolia': '🇲🇳',
  'Thailand': '🇹🇭', 'Vietnam': '🇻🇳', 'Singapore': '🇸🇬',
  'Malaysia': '🇲🇾', 'Indonesia': '🇮🇩', 'Philippines': '🇵🇭',
  'Cambodia': '🇰🇭', 'Myanmar': '🇲🇲',
  'India': '🇮🇳', 'Nepal': '🇳🇵', 'Sri Lanka': '🇱🇰',
  'Maldives': '🇲🇻', 'Bhutan': '🇧🇹',
  'United Kingdom': '🇬🇧', 'France': '🇫🇷', 'Germany': '🇩🇪',
  'Italy': '🇮🇹', 'Spain': '🇪🇸', 'Portugal': '🇵🇹',
  'Netherlands': '🇳🇱', 'Switzerland': '🇨🇭', 'Austria': '🇦🇹',
  'Belgium': '🇧🇪', 'Sweden': '🇸🇪', 'Norway': '🇳🇴',
  'Denmark': '🇩🇰', 'Finland': '🇫🇮', 'Poland': '🇵🇱',
  'Czech Republic': '🇨🇿', 'Hungary': '🇭🇺', 'Greece': '🇬🇷',
  'Croatia': '🇭🇷', 'Iceland': '🇮🇸',
  'United States': '🇺🇸', 'Canada': '🇨🇦', 'Mexico': '🇲🇽',
  'Brazil': '🇧🇷', 'Argentina': '🇦🇷', 'Peru': '🇵🇪',
  'Australia': '🇦🇺', 'New Zealand': '🇳🇿',
  'UAE': '🇦🇪', 'Israel': '🇮🇱',
  'Egypt': '🇪🇬', 'Morocco': '🇲🇦',
};

String _flag(String country) => _kCountryFlags[country] ?? '🌍';

const List<String> _kCommonCountries = [
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
  DateTime _selectedDate = DateTime.now();
  int _rating = 3;
  MarkerCategory _category = MarkerCategory.attraction;
  final List<String> _photoPaths = [];
  bool _isSubmitting = false;

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
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
      });
    }
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
                value: _selectedCountry,
                decoration: InputDecoration(
                  labelText: l10n.countryField,
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
                isExpanded: true,
                hint: Text(l10n.selectCountry),
                items: _kCommonCountries
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Text(_flag(c),
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(c)),
                            ],
                          ),
                        ))
                    .toList(),
                selectedItemBuilder: (context) => _kCommonCountries
                    .map((c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_flag(c),
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCountry = v),
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
