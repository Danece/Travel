// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$markerRepositoryHash() => r'34040832630e3c6b8b6976009295ab676901bb13';

/// See also [markerRepository].
@ProviderFor(markerRepository)
final markerRepositoryProvider =
    AutoDisposeProvider<MarkerRepositoryImpl>.internal(
  markerRepository,
  name: r'markerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$markerRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarkerRepositoryRef = AutoDisposeProviderRef<MarkerRepositoryImpl>;
String _$markerNotifierHash() => r'2f624d26a30733f23375805a5d73cabc6d46ab72';

/// See also [MarkerNotifier].
@ProviderFor(MarkerNotifier)
final markerNotifierProvider = AutoDisposeAsyncNotifierProvider<MarkerNotifier,
    List<MarkerEntity>>.internal(
  MarkerNotifier.new,
  name: r'markerNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$markerNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MarkerNotifier = AutoDisposeAsyncNotifier<List<MarkerEntity>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
