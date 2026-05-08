// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$packageInfoHash() => r'd24b99b0542a449e1a782fa3acd9cf5d63a4bb57';

/// See also [packageInfo].
@ProviderFor(packageInfo)
final packageInfoProvider = FutureProvider<PackageInfo>.internal(
  packageInfo,
  name: r'packageInfoProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$packageInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PackageInfoRef = FutureProviderRef<PackageInfo>;
String _$settingsNotifierHash() => r'ac49f5e1fb65bf2aa6b97350523f32c7676e0f50';

/// See also [SettingsNotifier].
@ProviderFor(SettingsNotifier)
final settingsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    SettingsNotifier, AppSettingsEntity>.internal(
  SettingsNotifier.new,
  name: r'settingsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SettingsNotifier = AutoDisposeAsyncNotifier<AppSettingsEntity>;
String _$colorVariantNotifierHash() =>
    r'dc54e1e3d5359afcf136700b36328d2de95d011e';

/// See also [ColorVariantNotifier].
@ProviderFor(ColorVariantNotifier)
final colorVariantNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ColorVariantNotifier, String>.internal(
  ColorVariantNotifier.new,
  name: r'colorVariantNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$colorVariantNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ColorVariantNotifier = AutoDisposeAsyncNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
