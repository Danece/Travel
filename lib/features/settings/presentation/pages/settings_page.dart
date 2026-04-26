import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_provider.dart';

// ── SettingsPage ───────────────────────────────────────────────────────────────
//
// 分為四個區塊：
//   1. 外觀    — 主題模式（SegmentedButton）
//   2. 語言    — 顯示目前語言（暫不支援切換）
//   3. 備份    — 自動備份頻率（DropdownButton，與 BackupPage 同步）
//   4. 關於    — 版本號、著作權、第三方套件聲明

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (settings) => ListView(
          children: [
            // ── 1. 外觀 ───────────────────────────────────────────────────
            _SectionHeader('外觀'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 區塊說明文字
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '主題模式',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // SegmentedButton：系統 / 淺色 / 深色
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('跟隨系統'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('淺色'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setThemeMode(selection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── 2. 語言 ───────────────────────────────────────────────────
            _SectionHeader('語言'),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('顯示語言'),
              // 目前僅支援繁體中文，預留未來擴充
              trailing: Text(
                '繁體中文',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),

            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── 3. 備份 ───────────────────────────────────────────────────
            _SectionHeader('備份'),
            // 自動備份頻率（與 BackupPage 中的 DropdownButton 同步）
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('自動備份頻率'),
              trailing: _FrequencyDropdown(
                value: settings.backupFrequency,
                onChanged: (v) => ref
                    .read(settingsNotifierProvider.notifier)
                    .setBackupFrequency(v),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.backup_outlined),
              title: const Text('自動備份'),
              subtitle: const Text('依所選頻率自動備份至 Google Drive'),
              value: settings.autoBackup,
              onChanged: (_) =>
                  ref.read(settingsNotifierProvider.notifier).toggleAutoBackup(),
            ),

            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── 4. 資料工具 ────────────────────────────────────────────────
            _SectionHeader('資料工具'),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Excel 匯出 / 匯入'),
              subtitle: const Text('將地標資料匯出為 .xlsx 或從檔案匯入'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/excel'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('備份與還原'),
              subtitle: const Text('備份至 Google Drive 或從備份還原'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/backup'),
            ),

            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── 5. 關於 ───────────────────────────────────────────────────
            _SectionHeader('關於'),
            _AboutSection(),
          ],
        ),
      ),
    );
  }
}

// ── 自動備份頻率下拉選單（與 BackupPage 共用相同選項）────────────────────────────

class _FrequencyDropdown extends StatelessWidget {
  const _FrequencyDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = {
    'off': '關閉',
    'daily': '每日',
    'weekly': '每週',
    'monthly': '每月',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: _options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── 關於 App 區塊 ──────────────────────────────────────────────────────────────
//
// 依賴 packageInfoProvider 非同步取得版本號與 Build 號。

class _AboutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(packageInfoProvider);

    // 版本字串：載入中顯示 '…'，失敗顯示預設值
    final versionText = infoAsync.when(
      loading: () => '…',
      error: (_, __) => '1.0.0',
      data: (info) => info.buildNumber.isNotEmpty
          ? '${info.version} (${info.buildNumber})'
          : info.version,
    );

    return Column(
      children: [
        // 版本號
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('版本'),
          trailing: Text(
            versionText,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),

        // 著作權聲明
        ListTile(
          leading: const Icon(Icons.copyright_outlined),
          title: const Text('著作權'),
          subtitle: Text(
            '© ${DateTime.now().year} Travel Mark. All rights reserved.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),

        // 第三方套件聲明（跳出 Flutter 內建授權頁）
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('第三方套件聲明'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final version = infoAsync.valueOrNull?.version ?? '';
            showLicensePage(
              context: context,
              applicationName: 'Travel Mark',
              applicationVersion: version,
              applicationLegalese:
                  '© ${DateTime.now().year} Travel Mark. All rights reserved.',
            );
          },
        ),
      ],
    );
  }
}

// ── 區塊標題 ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
