// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'travel_summary_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TravelSummaryEntity {
  /// 地標（旅遊足跡）總筆數
  int get totalMarkers;

  /// 造訪的不同國家數量
  int get totalCountries;

  /// 所有地標的平均評分（0.0 表示尚無資料）
  double get averageRating;

  /// 最後一筆資料的建立時間
  DateTime get lastUpdated;

  /// Create a copy of TravelSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TravelSummaryEntityCopyWith<TravelSummaryEntity> get copyWith =>
      _$TravelSummaryEntityCopyWithImpl<TravelSummaryEntity>(
          this as TravelSummaryEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TravelSummaryEntity &&
            (identical(other.totalMarkers, totalMarkers) ||
                other.totalMarkers == totalMarkers) &&
            (identical(other.totalCountries, totalCountries) ||
                other.totalCountries == totalCountries) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, totalMarkers, totalCountries, averageRating, lastUpdated);

  @override
  String toString() {
    return 'TravelSummaryEntity(totalMarkers: $totalMarkers, totalCountries: $totalCountries, averageRating: $averageRating, lastUpdated: $lastUpdated)';
  }
}

/// @nodoc
abstract mixin class $TravelSummaryEntityCopyWith<$Res> {
  factory $TravelSummaryEntityCopyWith(
          TravelSummaryEntity value, $Res Function(TravelSummaryEntity) _then) =
      _$TravelSummaryEntityCopyWithImpl;
  @useResult
  $Res call(
      {int totalMarkers,
      int totalCountries,
      double averageRating,
      DateTime lastUpdated});
}

/// @nodoc
class _$TravelSummaryEntityCopyWithImpl<$Res>
    implements $TravelSummaryEntityCopyWith<$Res> {
  _$TravelSummaryEntityCopyWithImpl(this._self, this._then);

  final TravelSummaryEntity _self;
  final $Res Function(TravelSummaryEntity) _then;

  /// Create a copy of TravelSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMarkers = null,
    Object? totalCountries = null,
    Object? averageRating = null,
    Object? lastUpdated = null,
  }) {
    return _then(_self.copyWith(
      totalMarkers: null == totalMarkers
          ? _self.totalMarkers
          : totalMarkers // ignore: cast_nullable_to_non_nullable
              as int,
      totalCountries: null == totalCountries
          ? _self.totalCountries
          : totalCountries // ignore: cast_nullable_to_non_nullable
              as int,
      averageRating: null == averageRating
          ? _self.averageRating
          : averageRating // ignore: cast_nullable_to_non_nullable
              as double,
      lastUpdated: null == lastUpdated
          ? _self.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [TravelSummaryEntity].
extension TravelSummaryEntityPatterns on TravelSummaryEntity {
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
    TResult Function(_TravelSummaryEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity() when $default != null:
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
    TResult Function(_TravelSummaryEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity():
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
    TResult? Function(_TravelSummaryEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity() when $default != null:
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
    TResult Function(int totalMarkers, int totalCountries, double averageRating,
            DateTime lastUpdated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity() when $default != null:
        return $default(_that.totalMarkers, _that.totalCountries,
            _that.averageRating, _that.lastUpdated);
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
    TResult Function(int totalMarkers, int totalCountries, double averageRating,
            DateTime lastUpdated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity():
        return $default(_that.totalMarkers, _that.totalCountries,
            _that.averageRating, _that.lastUpdated);
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
    TResult? Function(int totalMarkers, int totalCountries,
            double averageRating, DateTime lastUpdated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryEntity() when $default != null:
        return $default(_that.totalMarkers, _that.totalCountries,
            _that.averageRating, _that.lastUpdated);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TravelSummaryEntity implements TravelSummaryEntity {
  const _TravelSummaryEntity(
      {required this.totalMarkers,
      required this.totalCountries,
      required this.averageRating,
      required this.lastUpdated});

  /// 地標（旅遊足跡）總筆數
  @override
  final int totalMarkers;

  /// 造訪的不同國家數量
  @override
  final int totalCountries;

  /// 所有地標的平均評分（0.0 表示尚無資料）
  @override
  final double averageRating;

  /// 最後一筆資料的建立時間
  @override
  final DateTime lastUpdated;

  /// Create a copy of TravelSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TravelSummaryEntityCopyWith<_TravelSummaryEntity> get copyWith =>
      __$TravelSummaryEntityCopyWithImpl<_TravelSummaryEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TravelSummaryEntity &&
            (identical(other.totalMarkers, totalMarkers) ||
                other.totalMarkers == totalMarkers) &&
            (identical(other.totalCountries, totalCountries) ||
                other.totalCountries == totalCountries) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, totalMarkers, totalCountries, averageRating, lastUpdated);

  @override
  String toString() {
    return 'TravelSummaryEntity(totalMarkers: $totalMarkers, totalCountries: $totalCountries, averageRating: $averageRating, lastUpdated: $lastUpdated)';
  }
}

/// @nodoc
abstract mixin class _$TravelSummaryEntityCopyWith<$Res>
    implements $TravelSummaryEntityCopyWith<$Res> {
  factory _$TravelSummaryEntityCopyWith(_TravelSummaryEntity value,
          $Res Function(_TravelSummaryEntity) _then) =
      __$TravelSummaryEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int totalMarkers,
      int totalCountries,
      double averageRating,
      DateTime lastUpdated});
}

/// @nodoc
class __$TravelSummaryEntityCopyWithImpl<$Res>
    implements _$TravelSummaryEntityCopyWith<$Res> {
  __$TravelSummaryEntityCopyWithImpl(this._self, this._then);

  final _TravelSummaryEntity _self;
  final $Res Function(_TravelSummaryEntity) _then;

  /// Create a copy of TravelSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? totalMarkers = null,
    Object? totalCountries = null,
    Object? averageRating = null,
    Object? lastUpdated = null,
  }) {
    return _then(_TravelSummaryEntity(
      totalMarkers: null == totalMarkers
          ? _self.totalMarkers
          : totalMarkers // ignore: cast_nullable_to_non_nullable
              as int,
      totalCountries: null == totalCountries
          ? _self.totalCountries
          : totalCountries // ignore: cast_nullable_to_non_nullable
              as int,
      averageRating: null == averageRating
          ? _self.averageRating
          : averageRating // ignore: cast_nullable_to_non_nullable
              as double,
      lastUpdated: null == lastUpdated
          ? _self.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
