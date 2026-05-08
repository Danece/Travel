import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../data/datasources/marker_local_datasource_impl.dart';
import '../../data/repositories/marker_repository_impl.dart';
import '../../domain/entities/marker_entity.dart';
import '../../domain/usecases/delete_marker.dart';
import '../../domain/usecases/get_all_markers.dart';
import '../../domain/usecases/save_marker.dart';
import '../../domain/usecases/search_markers.dart';
import '../../domain/usecases/update_marker.dart';

part 'marker_provider.g.dart';

// ── dependency providers ───────────────────────────────────────────────────

@riverpod
MarkerRepositoryImpl markerRepository(Ref ref) => MarkerRepositoryImpl(
      MarkerLocalDatasourceImpl(DatabaseHelper.instance),
    );

// ── list notifier ──────────────────────────────────────────────────────────

@riverpod
class MarkerNotifier extends _$MarkerNotifier {
  @override
  Future<List<MarkerEntity>> build() async {
    final repo = ref.watch(markerRepositoryProvider);
    return GetAllMarkers(repo).call();
  }

  Future<void> add({
    required String title,
    required String country,
    required double latitude,
    required double longitude,
    required int rating,
    DateTime? createdAt,
    String note = '',
    List<String> photoPaths = const [],
    String category = 'attraction',
  }) async {
    final repo = ref.read(markerRepositoryProvider);
    final marker = MarkerEntity(
      id: const Uuid().v4(),
      title: title,
      country: country,
      createdAt: createdAt ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      rating: rating,
      note: note,
      photoPaths: photoPaths,
      category: category,
    );
    await SaveMarker(repo).call(marker);
    ref.invalidateSelf();
  }

  Future<void> edit(MarkerEntity marker) async {
    final repo = ref.read(markerRepositoryProvider);
    await UpdateMarker(repo).call(marker);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    final repo = ref.read(markerRepositoryProvider);
    await DeleteMarker(repo).call(id);
    ref.invalidateSelf();
  }

  Future<void> search({
    String? title,
    List<String>? countries,
    int? minRating,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
  }) async {
    final repo = ref.read(markerRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SearchMarkers(repo).call(
        title: title,
        countries: countries,
        minRating: minRating,
        startDate: startDate,
        endDate: endDate,
        categories: categories,
      ),
    );
  }
}
