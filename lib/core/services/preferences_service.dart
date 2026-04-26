import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── PreferencesService ────────────────────────────────────────────────────────
//
// 封裝 SharedPreferences 的讀寫，對外提供強型別的 get / set 方法。
// 採用單例模式，確保整個 App 共用同一個 SharedPreferences 實例。
//
// 管理的鍵值：
//   settings_theme_mode          → ThemeMode（int index）
//   settings_locale              → String（例：'zh-TW'）
//   settings_auto_backup         → bool
//   settings_backup_frequency    → String（'off' | 'daily' | 'weekly' | 'monthly'）

class PreferencesService {
  PreferencesService._();

  /// 全域單例
  static final PreferencesService instance = PreferencesService._();

  // ── SharedPreferences 鍵名常數 ─────────────────────────────────────────────

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyLocale = 'settings_locale';
  static const _keyAutoBackup = 'settings_auto_backup';
  static const _keyAutoBackupFrequency = 'settings_backup_frequency';

  // ── 取得快取的 SharedPreferences 實例 ─────────────────────────────────────

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ══════════════════════════════════════════════════════════════════════════
  // ThemeMode
  // ══════════════════════════════════════════════════════════════════════════

  /// 讀取使用者選擇的主題模式；預設為 [ThemeMode.system]
  Future<ThemeMode> getThemeMode() async {
    final prefs = await _prefs;
    final index = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    // 防止 index 超出範圍（例如將來 ThemeMode 新增值）
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  /// 儲存主題模式
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 語系 Locale
  // ══════════════════════════════════════════════════════════════════════════

  /// 讀取 locale 代碼；預設 'zh-TW'
  Future<String> getLocale() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLocale) ?? 'zh-TW';
  }

  /// 儲存 locale 代碼
  Future<void> setLocale(String locale) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLocale, locale);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 自動備份開關
  // ══════════════════════════════════════════════════════════════════════════

  /// 讀取自動備份是否開啟；預設 true
  Future<bool> getAutoBackup() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAutoBackup) ?? true;
  }

  /// 儲存自動備份開關
  Future<void> setAutoBackup(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAutoBackup, enabled);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 自動備份頻率 autoBackupFrequency
  // ══════════════════════════════════════════════════════════════════════════

  /// 讀取備份頻率代碼；預設 'off'
  /// 可用值：'off' | 'daily' | 'weekly' | 'monthly'
  Future<String> getAutoBackupFrequency() async {
    final prefs = await _prefs;
    return prefs.getString(_keyAutoBackupFrequency) ?? 'off';
  }

  /// 儲存備份頻率代碼
  Future<void> setAutoBackupFrequency(String frequency) async {
    final prefs = await _prefs;
    await prefs.setString(_keyAutoBackupFrequency, frequency);
  }
}
