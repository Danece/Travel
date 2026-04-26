import '../../../../core/services/preferences_service.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';

// ── SettingsRepositoryImpl ────────────────────────────────────────────────────
//
// 透過注入的 [PreferencesService] 讀寫設定，
// 不直接依賴 SharedPreferences，便於測試替換。

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._prefs);

  final PreferencesService _prefs;

  @override
  Future<AppSettingsEntity> getSettings() async {
    // 並行讀取所有設定值以減少等待時間
    final results = await Future.wait([
      _prefs.getThemeMode(),
      _prefs.getLocale(),
      _prefs.getAutoBackup(),
      _prefs.getAutoBackupFrequency(),
    ]);

    return AppSettingsEntity(
      themeMode: results[0] as dynamic,        // ThemeMode
      locale: results[1] as String,
      autoBackup: results[2] as bool,
      backupFrequency: results[3] as String,
    );
  }

  @override
  Future<void> saveSettings(AppSettingsEntity settings) async {
    // 並行寫入所有設定值
    await Future.wait([
      _prefs.setThemeMode(settings.themeMode),
      _prefs.setLocale(settings.locale),
      _prefs.setAutoBackup(settings.autoBackup),
      _prefs.setAutoBackupFrequency(settings.backupFrequency),
    ]);
  }
}
