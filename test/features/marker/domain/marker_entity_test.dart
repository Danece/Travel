import 'package:flutter_test/flutter_test.dart';
import 'package:travel_mark/features/marker/domain/entities/marker_entity.dart';

void main() {
  // 基準 entity，所有測試以它為起點
  final base = MarkerEntity(
    id: 'id-001',
    title: 'Tokyo Tower',
    country: 'Japan',
    createdAt: DateTime(2024, 4, 15),
    latitude: 35.6586,
    longitude: 139.7454,
    rating: 3,
  );

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('copyWith', () {
    test('overrides every field independently', () {
      final now = DateTime(2025, 6, 1);
      final updated = base.copyWith(
        id: 'id-999',
        title: 'Eiffel Tower',
        country: 'France',
        createdAt: now,
        latitude: 48.8584,
        longitude: 2.2945,
        rating: 5,
        note: 'Magnifique!',
        photoPaths: ['a.jpg', 'b.jpg'],
      );

      expect(updated.id, 'id-999');
      expect(updated.title, 'Eiffel Tower');
      expect(updated.country, 'France');
      expect(updated.createdAt, now);
      expect(updated.latitude, 48.8584);
      expect(updated.longitude, 2.2945);
      expect(updated.rating, 5);
      expect(updated.note, 'Magnifique!');
      expect(updated.photoPaths, ['a.jpg', 'b.jpg']);
    });

    test('unspecified fields retain original values', () {
      final updated = base.copyWith(title: 'Updated');
      expect(updated.id, base.id);
      expect(updated.country, base.country);
      expect(updated.createdAt, base.createdAt);
      expect(updated.latitude, base.latitude);
      expect(updated.longitude, base.longitude);
      expect(updated.rating, base.rating);
      expect(updated.note, base.note);
      expect(updated.photoPaths, base.photoPaths);
    });

    test('default note is empty string', () {
      expect(base.note, '');
    });

    test('default photoPaths is empty list', () {
      expect(base.photoPaths, isEmpty);
    });

    test('photoPaths can be updated to single-item list', () {
      final updated = base.copyWith(photoPaths: ['cover.jpg']);
      expect(updated.photoPaths, ['cover.jpg']);
    });

    test('photoPaths can be updated to multi-item list', () {
      final updated = base.copyWith(photoPaths: ['a.jpg', 'b.jpg', 'c.jpg']);
      expect(updated.photoPaths.length, 3);
    });

    test('two entities with identical values are equal', () {
      final copy = base.copyWith();
      expect(copy, base);
    });
  });

  // ── rating boundary ────────────────────────────────────────────────────────

  group('rating boundary (assert: 1 ≤ rating ≤ 5)', () {
    test('rating 1 is valid — no exception', () {
      expect(() => base.copyWith(rating: 1), returnsNormally);
      expect(base.copyWith(rating: 1).rating, 1);
    });

    test('rating 5 is valid — no exception', () {
      expect(() => base.copyWith(rating: 5), returnsNormally);
      expect(base.copyWith(rating: 5).rating, 5);
    });

    test('rating 2, 3, 4 are all valid', () {
      for (final r in [2, 3, 4]) {
        expect(() => base.copyWith(rating: r), returnsNormally);
      }
    });

    test('rating 0 throws AssertionError', () {
      expect(
        () => base.copyWith(rating: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rating 6 throws AssertionError', () {
      expect(
        () => base.copyWith(rating: 6),
        throwsA(isA<AssertionError>()),
      );
    });

    test('negative rating throws AssertionError', () {
      expect(
        () => base.copyWith(rating: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
