// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'travel_summary_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TravelSummaryModel {
  int get totalMarkers;
  int get totalCountries;
  double get averageRating;
  DateTime get lastUpdated;

  /// Create a copy of TravelSummaryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TravelSummaryModelCopyWith<TravelSummaryModel> get copyWith =>
      _$TravelSummaryModelCopyWithImpl<TravelSummaryModel>(
          this as TravelSummaryModel, _$identity);

  /// Serializes this TravelSummaryModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TravelSummaryModel &&
            (identical(other.totalMarkers, totalMarkers) ||
                other.totalMarkers == totalMarkers) &&
            (identical(other.totalCountries, totalCountries) ||
                other.totalCountries == totalCountries) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, totalMarkers, totalCountries, averageRating, lastUpdated);

  @override
  String toString() {
    return 'TravelSummaryModel(totalMarkers: $totalMarkers, totalCountries: $totalCountries, averageRating: $averageRating, lastUpdated: $lastUpdated)';
  }
}

/// @nodoc
abstract mixin class $TravelSummaryModelCopyWith<$Res> {
  factory $TravelSummaryModelCopyWith(
          TravelSummaryModel value, $Res Function(TravelSummaryModel) _then) =
      _$TravelSummaryModelCopyWithImpl;
  @useResult
  $Res call(
      {int totalMarkers,
      int totalCountries,
      double averageRating,
      DateTime lastUpdated});
}

/// @nodoc
class _$TravelSummaryModelCopyWithImpl<$Res>
    implements $TravelSummaryModelCopyWith<$Res> {
  _$TravelSummaryModelCopyWithImpl(this._self, this._then);

  final TravelSummaryModel _self;
  final $Res Function(TravelSummaryModel) _then;

  /// Create a copy of TravelSummaryModel
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

/// Adds pattern-matching-related methods to [TravelSummaryModel].
extension TravelSummaryModelPatterns on TravelSummaryModel {
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
    TResult Function(_TravelSummaryModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryModel() when $default != null:
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
    TResult Function(_TravelSummaryModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryModel():
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
    TResult? Function(_TravelSummaryModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TravelSummaryModel() when $default != null:
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
      case _TravelSummaryModel() when $default != null:
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
      case _TravelSummaryModel():
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
      case _TravelSummaryModel() when $default != null:
        return $default(_that.totalMarkers, _that.totalCountries,
            _that.averageRating, _that.lastUpdated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TravelSummaryModel implements TravelSummaryModel {
  const _TravelSummaryModel(
      {required this.totalMarkers,
      required this.totalCountries,
      required this.averageRating,
      required this.lastUpdated});
  factory _TravelSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$TravelSummaryModelFromJson(json);

  @override
  final int totalMarkers;
  @override
  final int totalCountries;
  @override
  final double averageRating;
  @override
  final DateTime lastUpdated;

  /// Create a copy of TravelSummaryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TravelSummaryModelCopyWith<_TravelSummaryModel> get copyWith =>
      __$TravelSummaryModelCopyWithImpl<_TravelSummaryModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TravelSummaryModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TravelSummaryModel &&
            (identical(other.totalMarkers, totalMarkers) ||
                other.totalMarkers == totalMarkers) &&
            (identical(other.totalCountries, totalCountries) ||
                other.totalCountries == totalCountries) &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, totalMarkers, totalCountries, averageRating, lastUpdated);

  @override
  String toString() {
    return 'TravelSummaryModel(totalMarkers: $totalMarkers, totalCountries: $totalCountries, averageRating: $averageRating, lastUpdated: $lastUpdated)';
  }
}

/// @nodoc
abstract mixin class _$TravelSummaryModelCopyWith<$Res>
    implements $TravelSummaryModelCopyWith<$Res> {
  factory _$TravelSummaryModelCopyWith(
          _TravelSummaryModel value, $Res Function(_TravelSummaryModel) _then) =
      __$TravelSummaryModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int totalMarkers,
      int totalCountries,
      double averageRating,
      DateTime lastUpdated});
}

/// @nodoc
class __$TravelSummaryModelCopyWithImpl<$Res>
    implements _$TravelSummaryModelCopyWith<$Res> {
  __$TravelSummaryModelCopyWithImpl(this._self, this._then);

  final _TravelSummaryModel _self;
  final $Res Function(_TravelSummaryModel) _then;

  /// Create a copy of TravelSummaryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? totalMarkers = null,
    Object? totalCountries = null,
    Object? averageRating = null,
    Object? lastUpdated = null,
  }) {
    return _then(_TravelSummaryModel(
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
