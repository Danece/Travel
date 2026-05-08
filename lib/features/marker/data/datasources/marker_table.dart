abstract final class MarkerTable {
  static const String tableName = 'markers';

  // columns
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colCountry = 'country';
  static const String colCreatedAt = 'created_at';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colRating = 'rating';
  static const String colNote = 'note';
  static const String colPhotoPaths = 'photo_paths';
  static const String colCategory = 'category';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $colId          TEXT PRIMARY KEY,
      $colTitle       TEXT NOT NULL,
      $colCountry     TEXT NOT NULL,
      $colCreatedAt   INTEGER NOT NULL,
      $colLatitude    REAL NOT NULL,
      $colLongitude   REAL NOT NULL,
      $colRating      INTEGER NOT NULL CHECK($colRating BETWEEN 1 AND 5),
      $colNote        TEXT NOT NULL DEFAULT '',
      $colPhotoPaths  TEXT NOT NULL DEFAULT '[]',
      $colCategory    TEXT NOT NULL DEFAULT 'attraction'
    )
  ''';
}
