import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_mark/core/database/database_helper.dart';
import 'package:travel_mark/features/marker/data/datasources/marker_local_datasource_impl.dart';
import 'package:travel_mark/features/marker/data/datasources/marker_table.dart';
import 'package:travel_mark/features/marker/data/models/marker_model.dart';

void main() {
  late MarkerLocalDatasourceImpl datasource;

  // 初始化 sqflite FFI（僅需執行一次）
  setUpAll(() {
    sqfliteFfiInit();
  });

  // 每個 test 前建立全新的 in-memory 資料庫
  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(MarkerTable.createTableSql);
        },
      ),
    );
    DatabaseHelper.injectForTesting(db);
    datasource = MarkerLocalDatasourceImpl(DatabaseHelper.instance);
  });

  // 每個 test 後關閉 DB，確保下次 setUp 得到乾淨環境
  tearDown(() async {
    await DatabaseHelper.instance.closeDatabase();
  });

  // ── 測試用資料工廠 ──────────────────────────────────────────────────────────

  MarkerModel _marker({
    String id = 'm-001',
    String title = 'Tokyo Tower',
    String country = 'Japan',
    int rating = 3,
    String note = '',
    List<String> photoPaths = const [],
  }) =>
      MarkerModel(
        id: id,
        title: title,
        country: country,
        createdAt: DateTime(2024, 1, 1),
        latitude: 35.6586,
        longitude: 139.7454,
        rating: rating,
        note: note,
        photoPaths: photoPaths,
      );

  // ── insert / getAll ───────────────────────────────────────────────────────

  group('insert + getAll', () {
    test('empty DB returns empty list', () async {
      final result = await datasource.getAll();
      expect(result, isEmpty);
    });

    test('inserted marker is returned by getAll', () async {
      final m = _marker();
      await datasource.insert(m);

      final result = await datasource.getAll();
      expect(result.length, 1);
      expect(result.first.id, m.id);
      expect(result.first.title, m.title);
      expect(result.first.country, m.country);
      expect(result.first.rating, m.rating);
    });

    test('multiple inserts are all returned', () async {
      await datasource.insert(_marker(id: 'm-001', title: 'A'));
      await datasource.insert(_marker(id: 'm-002', title: 'B'));
      await datasource.insert(_marker(id: 'm-003', title: 'C'));

      final result = await datasource.getAll();
      expect(result.length, 3);
    });

    test('getAll returns in descending createdAt order', () async {
      await datasource.insert(
        MarkerModel(
          id: 'old',
          title: 'Old',
          country: 'Japan',
          createdAt: DateTime(2023, 1, 1),
          latitude: 0,
          longitude: 0,
          rating: 1,
        ),
      );
      await datasource.insert(
        MarkerModel(
          id: 'new',
          title: 'New',
          country: 'Japan',
          createdAt: DateTime(2025, 1, 1),
          latitude: 0,
          longitude: 0,
          rating: 1,
        ),
      );

      final result = await datasource.getAll();
      expect(result.first.id, 'new');
      expect(result.last.id, 'old');
    });

    test('photoPaths are persisted and restored', () async {
      final m = _marker(photoPaths: ['a.jpg', 'b.jpg', 'c.jpg']);
      await datasource.insert(m);

      final result = await datasource.getAll();
      expect(result.first.photoPaths, ['a.jpg', 'b.jpg', 'c.jpg']);
    });

    test('inserting duplicate id throws', () async {
      await datasource.insert(_marker(id: 'dup'));
      expect(() => datasource.insert(_marker(id: 'dup')), throwsException);
    });
  });

  // ── search: title ─────────────────────────────────────────────────────────

  group('search — title LIKE', () {
    setUp(() async {
      await datasource.insert(_marker(id: '1', title: 'Tokyo Tower'));
      await datasource.insert(_marker(id: '2', title: 'Tokyo Skytree'));
      await datasource.insert(_marker(id: '3', title: 'Eiffel Tower'));
    });

    test('partial title match returns correct results', () async {
      final result = await datasource.search(title: 'Tokyo');
      expect(result.length, 2);
      expect(result.map((m) => m.id), containsAll(['1', '2']));
    });

    test('full title match returns single result', () async {
      final result = await datasource.search(title: 'Eiffel Tower');
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('case-insensitive match via LIKE', () async {
      final result = await datasource.search(title: 'tower');
      expect(result.length, 2);
    });

    test('no match returns empty list', () async {
      final result = await datasource.search(title: 'Nowhere');
      expect(result, isEmpty);
    });

    test('null title returns all records', () async {
      final result = await datasource.search();
      expect(result.length, 3);
    });
  });

  // ── search: countries (IN clause) ─────────────────────────────────────────

  group('search — countries IN', () {
    setUp(() async {
      await datasource.insert(_marker(id: '1', country: 'Japan'));
      await datasource.insert(_marker(id: '2', country: 'France'));
      await datasource.insert(_marker(id: '3', country: 'Italy'));
      await datasource.insert(_marker(id: '4', country: 'Japan'));
    });

    test('single country filter', () async {
      final result = await datasource.search(countries: ['Japan']);
      expect(result.length, 2);
      expect(result.every((m) => m.country == 'Japan'), isTrue);
    });

    test('multi-country filter returns all matching', () async {
      final result = await datasource.search(countries: ['France', 'Italy']);
      expect(result.length, 2);
      expect(result.map((m) => m.country), containsAll(['France', 'Italy']));
    });

    test('three-country filter', () async {
      final result =
          await datasource.search(countries: ['Japan', 'France', 'Italy']);
      expect(result.length, 4);
    });

    test('country not in DB returns empty', () async {
      final result = await datasource.search(countries: ['Germany']);
      expect(result, isEmpty);
    });

    test('null countries returns all records', () async {
      final result = await datasource.search(countries: null);
      expect(result.length, 4);
    });

    test('empty countries list returns all records', () async {
      final result = await datasource.search(countries: []);
      expect(result.length, 4);
    });
  });

  // ── search: minRating ─────────────────────────────────────────────────────

  group('search — minRating', () {
    setUp(() async {
      await datasource.insert(_marker(id: '1', rating: 1));
      await datasource.insert(_marker(id: '2', rating: 3));
      await datasource.insert(_marker(id: '3', rating: 5));
    });

    test('minRating 1 returns all', () async {
      final result = await datasource.search(minRating: 1);
      expect(result.length, 3);
    });

    test('minRating 3 returns rating >= 3', () async {
      final result = await datasource.search(minRating: 3);
      expect(result.length, 2);
      expect(result.every((m) => m.rating >= 3), isTrue);
    });

    test('minRating 5 returns only top-rated', () async {
      final result = await datasource.search(minRating: 5);
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('minRating above max returns empty', () async {
      // This won't happen in practice (DB CHECK enforces 1–5),
      // but the filter logic should still return empty.
      final result = await datasource.search(minRating: 6);
      expect(result, isEmpty);
    });
  });

  // ── search: combined filters ──────────────────────────────────────────────

  group('search — combined filters', () {
    setUp(() async {
      await datasource.insert(
          _marker(id: '1', title: 'Mt Fuji', country: 'Japan', rating: 5));
      await datasource.insert(
          _marker(id: '2', title: 'Kyoto', country: 'Japan', rating: 3));
      await datasource.insert(
          _marker(id: '3', title: 'Eiffel', country: 'France', rating: 5));
    });

    test('title + country narrows results', () async {
      final result =
          await datasource.search(title: 'Mt', countries: ['Japan']);
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('countries + minRating filters correctly', () async {
      final result =
          await datasource.search(countries: ['Japan'], minRating: 5);
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('all filters combined', () async {
      final result = await datasource.search(
        title: 'Mt',
        countries: ['Japan'],
        minRating: 4,
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });

  // ── update ────────────────────────────────────────────────────────────────

  group('update', () {
    test('title update is reflected in getAll', () async {
      await datasource.insert(_marker(id: 'm-1', title: 'Before'));
      final original = (await datasource.getAll()).first;

      final updated = MarkerModel(
        id: original.id,
        title: 'After',
        country: original.country,
        createdAt: original.createdAt,
        latitude: original.latitude,
        longitude: original.longitude,
        rating: original.rating,
        note: original.note,
        photoPaths: original.photoPaths,
      );
      await datasource.update(updated);

      final result = await datasource.getAll();
      expect(result.first.title, 'After');
    });

    test('rating update is reflected in getById', () async {
      await datasource.insert(_marker(id: 'u-1', rating: 2));
      final model = (await datasource.getById('u-1'))!;

      await datasource.update(
        MarkerModel(
          id: model.id,
          title: model.title,
          country: model.country,
          createdAt: model.createdAt,
          latitude: model.latitude,
          longitude: model.longitude,
          rating: 5,
          note: model.note,
          photoPaths: model.photoPaths,
        ),
      );

      final result = await datasource.getById('u-1');
      expect(result?.rating, 5);
    });

    test('update with new photoPaths is persisted', () async {
      await datasource.insert(_marker(id: 'p-1', photoPaths: ['old.jpg']));
      final model = (await datasource.getById('p-1'))!;

      await datasource.update(
        MarkerModel(
          id: model.id,
          title: model.title,
          country: model.country,
          createdAt: model.createdAt,
          latitude: model.latitude,
          longitude: model.longitude,
          rating: model.rating,
          note: model.note,
          photoPaths: ['new1.jpg', 'new2.jpg'],
        ),
      );

      final result = await datasource.getById('p-1');
      expect(result?.photoPaths, ['new1.jpg', 'new2.jpg']);
    });

    test('updating non-existent id does not throw', () async {
      final ghost = _marker(id: 'ghost');
      await expectLater(datasource.update(ghost), completes);
    });
  });

  // ── delete ────────────────────────────────────────────────────────────────

  group('delete', () {
    test('deleted marker no longer appears in getAll', () async {
      await datasource.insert(_marker(id: 'd-1'));
      await datasource.delete('d-1');

      final result = await datasource.getAll();
      expect(result, isEmpty);
    });

    test('getById returns null after delete', () async {
      await datasource.insert(_marker(id: 'd-2'));
      await datasource.delete('d-2');

      expect(await datasource.getById('d-2'), isNull);
    });

    test('deleting one of many leaves the rest intact', () async {
      await datasource.insert(_marker(id: 'keep-1'));
      await datasource.insert(_marker(id: 'keep-2'));
      await datasource.insert(_marker(id: 'remove'));

      await datasource.delete('remove');

      final result = await datasource.getAll();
      expect(result.length, 2);
      expect(result.map((m) => m.id), containsAll(['keep-1', 'keep-2']));
    });

    test('deleting non-existent id does not throw', () async {
      await expectLater(datasource.delete('no-such-id'), completes);
    });
  });
}
