import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/preferences_service.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/app_settings_entity.dart';

part 'settings_provider.g.dart';

// ── SettingsNotifier ──────────────────────────────────────────────────────────
//
// state 型別：AsyncValue<AppSettingsEntity>
//   - build()：從 PreferencesService 載入設定
//   - 各 setter：更新 state 並持久化

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  /// 透過 PreferencesService 建立 Repository，保持可測試性
  SettingsRepositoryImpl get _repo =>
      SettingsRepositoryImpl(PreferencesService.instance);

  @override
  Future<AppSettingsEntity> build() async => _repo.getSettings();

  // ── 主題模式 ───────────────────────────────────────────────────────────────

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = await future;
    final updated = current.copyWith(themeMode: mode);
    await _repo.saveSettings(updated);
    state = AsyncData(updated);
  }

  // ── 語系 ───────────────────────────────────────────────────────────────────

  Future<void> setLocale(String locale) async {
    final current = await future;
    final updated = current.copyWith(locale: locale);
    await _repo.saveSettings(updated);
    state = AsyncData(updated);
  }

  // ── 自動備份開關 ────────────────────────────────────────────────────────────

  Future<void> toggleAutoBackup() async {
    final current = await future;
    final updated = current.copyWith(autoBackup: !current.autoBackup);
    await _repo.saveSettings(updated);
    state = AsyncData(updated);
  }

  // ── 自動備份頻率 ────────────────────────────────────────────────────────────

  Future<void> setBackupFrequency(String frequency) async {
    final current = await future;
    final updated = current.copyWith(backupFrequency: frequency);
    await _repo.saveSettings(updated);
    state = AsyncData(updated);
  }
}

// ── packageInfoProvider ───────────────────────────────────────────────────────
//
// 非同步讀取 App 版本資訊（版本號、Build 號）。
// keepAlive: true 確保整個 App 週期只查詢平台一次。

@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(PackageInfoRef ref) =>
    PackageInfo.fromPlatform();
