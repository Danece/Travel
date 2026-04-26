import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

part 'app_settings_entity.freezed.dart';

/// 自動備份頻率的可用值（儲存為字串，方便 SharedPreferences 存取）
///   'off'     關閉
///   'daily'   每日
///   'weekly'  每週
///   'monthly' 每月
@freezed
sealed class AppSettingsEntity with _$AppSettingsEntity {
  const factory AppSettingsEntity({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default('zh-TW') String locale,
    @Default(true) bool autoBackup,
    @Default('off') String backupFrequency,
  }) = _AppSettingsEntity;
}
