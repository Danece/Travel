import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_mark/features/marker/data/datasources/marker_table.dart';
import 'package:travel_mark/features/marker/data/models/marker_model.dart';
import 'package:travel_mark/features/marker/domain/entities/marker_entity.dart';

void main() {
  // 固定時間（無微秒），確保 millisecondsSinceEpoch 往返精確
  final createdAt = DateTime(2024, 4, 15, 12, 30, 0);

  MarkerModel buildModel({
    String id = 'abc-001',
    String title = 'Tokyo Tower',
    String country = 'Japan',
    int rating = 4,
    String note = 'Great view',
    List<String> photoPaths = const [],
  }) =>
      MarkerModel(
        id: id,
        title: title,
        country: country,
        createdAt: createdAt,
        latitude: 35.6586,
        longitude: 139.7454,
        rating: rating,
        note: note,
        photoPaths: photoPaths,
      );

  // ── fromMap / toMap 往返一致性 ──────────────────────────────────────────────

  group('fromMap / toMap round-trip', () {
    void expectRoundTrip(MarkerModel model) {
      final map = model.toMap();
      final restored = MarkerModel.fromMap(map);

      expect(restored.id, model.id);
      expect(restored.title, model.title);
      expect(restored.country, model.country);
      expect(restored.createdAt, model.createdAt);
      expect(restored.latitude, model.latitude);
      expect(restored.longitude, model.longitude);
      expect(restored.rating, model.rating);
      expect(restored.note, model.note);
      expect(restored.photoPaths, model.photoPaths);
    }

    test('preserves all scalar fields', () {
      expectRoundTrip(buildModel());
    });

    test('createdAt preserved with millisecond precision', () {
      final ms = DateTime.fromMillisecondsSinceEpoch(
        createdAt.millisecondsSinceEpoch,
      );
      expect(buildModel().toMap()[MarkerTable.colCreatedAt],
          createdAt.millisecondsSinceEpoch);
      expect(ms, createdAt);
    });

    test('toMap stores photoPaths as JSON string', () {
      final map = buildModel(photoPaths: ['a.jpg', 'b.jpg']).toMap();
      final raw = map[MarkerTable.colPhotoPaths] as String;
      expect(jsonDecode(raw), ['a.jpg', 'b.jpg']);
    });

    test('note is preserved including empty string', () {
      expectRoundTrip(buildModel(note: ''));
      expectRoundTrip(buildModel(note: '很棒的旅遊景點！'));
    });
  });

  // ── photoPaths 序列化邊界 ──────────────────────────────────────────────────

  group('photoPaths serialization', () {
    test('empty list round-trips correctly', () {
      final model = buildModel(photoPaths: []);
      final map = model.toMap();
      expect(map[MarkerTable.colPhotoPaths], '[]');
      final restored = MarkerModel.fromMap(map);
      expect(restored.photoPaths, isEmpty);
    });

    test('single path round-trips correctly', () {
      final model = buildModel(photoPaths: ['/photos/img.jpg']);
      final restored = MarkerModel.fromMap(model.toMap());
      expect(restored.photoPaths, ['/photos/img.jpg']);
    });

    test('multiple paths round-trip correctly', () {
      final paths = ['/p/a.jpg', '/p/b.jpg', '/p/c.jpg'];
      final model = buildModel(photoPaths: paths);
      final restored = MarkerModel.fromMap(model.toMap());
      expect(restored.photoPaths, paths);
      expect(restored.photoPaths.length, 3);
    });

    test('paths with special characters are preserved', () {
      final paths = ['/storage/emulated/0/DCIM/旅遊照片/photo 1.jpg'];
      final restored = MarkerModel.fromMap(buildModel(photoPaths: paths).toMap());
      expect(restored.photoPaths, paths);
    });
  });

  // ── fromEntity / toEntity ─────────────────────────────────────────────────

  group('fromEntity / toEntity', () {
    MarkerEntity buildEntity({
      String id = 'ent-001',
      int rating = 3,
      List<String> photoPaths = const [],
    }) =>
        MarkerEntity(
          id: id,
          title: 'Eiffel Tower',
          country: 'France',
          createdAt: createdAt,
          latitude: 48.8584,
          longitude: 2.2945,
          rating: rating,
          note: 'Magnifique',
          photoPaths: photoPaths,
        );

    test('fromEntity preserves all fields', () {
      final entity = buildEntity(photoPaths: ['paris.jpg']);
      final model = MarkerModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.title, entity.title);
      expect(model.country, entity.country);
      expect(model.createdAt, entity.createdAt);
      expect(model.latitude, entity.latitude);
      expect(model.longitude, entity.longitude);
      expect(model.rating, entity.rating);
      expect(model.note, entity.note);
      expect(model.photoPaths, entity.photoPaths);
    });

    test('toEntity preserves all fields', () {
      final model = buildModel(photoPaths: ['t.jpg']);
      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.title, model.title);
      expect(entity.country, model.country);
      expect(entity.createdAt, model.createdAt);
      expect(entity.latitude, model.latitude);
      expect(entity.longitude, model.longitude);
      expect(entity.rating, model.rating);
      expect(entity.note, model.note);
      expect(entity.photoPaths, model.photoPaths);
    });

    test('entity → model → entity round-trip preserves equality', () {
      final original = buildEntity(photoPaths: ['a.jpg', 'b.jpg']);
      final roundTripped = MarkerModel.fromEntity(original).toEntity();
      expect(roundTripped, original);
    });

    test('empty photoPaths round-trips through entity ↔ model', () {
      final entity = buildEntity(photoPaths: []);
      final roundTripped = MarkerModel.fromEntity(entity).toEntity();
      expect(roundTripped.photoPaths, isEmpty);
    });

    test('boundary rating 1 is preserved through conversion', () {
      final entity = buildEntity(rating: 1);
      expect(MarkerModel.fromEntity(entity).toEntity().rating, 1);
    });

    test('boundary rating 5 is preserved through conversion', () {
      final entity = buildEntity(rating: 5);
      expect(MarkerModel.fromEntity(entity).toEntity().rating, 5);
    });
  });
}
