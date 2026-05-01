// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marker_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarkerEntity {
  String get id;
  String get title;
  String get country;
  DateTime get createdAt;
  double get latitude;
  double get longitude;
  int get rating;
  String get note;
  List<String> get photoPaths;

  /// Create a copy of MarkerEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MarkerEntityCopyWith<MarkerEntity> get copyWith =>
      _$MarkerEntityCopyWithImpl<MarkerEntity>(
          this as MarkerEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MarkerEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality()
                .equals(other.photoPaths, photoPaths));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      country,
      createdAt,
      latitude,
      longitude,
      rating,
      note,
      const DeepCollectionEquality().hash(photoPaths));

  @override
  String toString() {
    return 'MarkerEntity(id: $id, title: $title, country: $country, createdAt: $createdAt, latitude: $latitude, longitude: $longitude, rating: $rating, note: $note, photoPaths: $photoPaths)';
  }
}

/// @nodoc
abstract mixin class $MarkerEntityCopyWith<$Res> {
  factory $MarkerEntityCopyWith(
          MarkerEntity value, $Res Function(MarkerEntity) _then) =
      _$MarkerEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String country,
      DateTime createdAt,
      double latitude,
      double longitude,
      int rating,
      String note,
      List<String> photoPaths});
}

/// @nodoc
class _$MarkerEntityCopyWithImpl<$Res> implements $MarkerEntityCopyWith<$Res> {
  _$MarkerEntityCopyWithImpl(this._self, this._then);

  final MarkerEntity _self;
  final $Res Function(MarkerEntity) _then;

  /// Create a copy of MarkerEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? country = null,
    Object? createdAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? rating = null,
    Object? note = null,
    Object? photoPaths = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      country: null == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      rating: null == rating
          ? _self.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as int,
      note: null == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      photoPaths: null == photoPaths
          ? _self.photoPaths
          : photoPaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [MarkerEntity].
extension MarkerEntityPatterns on MarkerEntity {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_MarkerEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_MarkerEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity():
        return $default(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_MarkerEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String title,
            String country,
            DateTime createdAt,
            double latitude,
            double longitude,
            int rating,
            String note,
            List<String> photoPaths)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.country,
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.rating,
            _that.note,
            _that.photoPaths);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String title,
            String country,
            DateTime createdAt,
            double latitude,
            double longitude,
            int rating,
            String note,
            List<String> photoPaths)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity():
        return $default(
            _that.id,
            _that.title,
            _that.country,
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.rating,
            _that.note,
            _that.photoPaths);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String title,
            String country,
            DateTime createdAt,
            double latitude,
            double longitude,
            int rating,
            String note,
            List<String> photoPaths)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MarkerEntity() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.country,
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.rating,
            _that.note,
            _that.photoPaths);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _MarkerEntity implements MarkerEntity {
  const _MarkerEntity(
      {required this.id,
      required this.title,
      required this.country,
      required this.createdAt,
      required this.latitude,
      required this.longitude,
      required this.rating,
      this.note = '',
      final List<String> photoPaths = const []})
      : assert(rating >= 1 && rating <= 5, 'rating must be between 1 and 5'),
        _photoPaths = photoPaths;

  @override
  final String id;
  @override
  final String title;
  @override
  final String country;
  @override
  final DateTime createdAt;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final int rating;
  @override
  @JsonKey()
  final String note;
  final List<String> _photoPaths;
  @override
  @JsonKey()
  List<String> get photoPaths {
    if (_photoPaths is EqualUnmodifiableListView) return _photoPaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photoPaths);
  }

  /// Create a copy of MarkerEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MarkerEntityCopyWith<_MarkerEntity> get copyWith =>
      __$MarkerEntityCopyWithImpl<_MarkerEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MarkerEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality()
                .equals(other._photoPaths, _photoPaths));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      country,
      createdAt,
      latitude,
      longitude,
      rating,
      note,
      const DeepCollectionEquality().hash(_photoPaths));

  @override
  String toString() {
    return 'MarkerEntity(id: $id, title: $title, country: $country, createdAt: $createdAt, latitude: $latitude, longitude: $longitude, rating: $rating, note: $note, photoPaths: $photoPaths)';
  }
}

/// @nodoc
abstract mixin class _$MarkerEntityCopyWith<$Res>
    implements $MarkerEntityCopyWith<$Res> {
  factory _$MarkerEntityCopyWith(
          _MarkerEntity value, $Res Function(_MarkerEntity) _then) =
      __$MarkerEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String country,
      DateTime createdAt,
      double latitude,
      double longitude,
      int rating,
      String note,
      List<String> photoPaths});
}

/// @nodoc
class __$MarkerEntityCopyWithImpl<$Res>
    implements _$MarkerEntityCopyWith<$Res> {
  __$MarkerEntityCopyWithImpl(this._self, this._then);

  final _MarkerEntity _self;
  final $Res Function(_MarkerEntity) _then;

  /// Create a copy of MarkerEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? country = null,
    Object? createdAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? rating = null,
    Object? note = null,
    Object? photoPaths = null,
  }) {
    return _then(_MarkerEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      country: null == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      rating: null == rating
          ? _self.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as int,
      note: null == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      photoPaths: null == photoPaths
          ? _self._photoPaths
          : photoPaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
