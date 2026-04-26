import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.local(String message) = LocalFailure;
  const factory Failure.network(String message) = NetworkFailure;
  const factory Failure.unknown(String message) = UnknownFailure;
}
