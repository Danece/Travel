import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../backup/presentation/providers/backup_provider.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final colorVariant =
        ref.watch(colorVariantNotifierProvider).valueOrNull ?? 'default';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.loadFailed}：$e')),
        data: (settings) {
          // 計算目前選取的主題選項（4 選 1）
          final currentThemeOption = colorVariant == 'colorful'
              ? 'colorful'
              : switch (settings.themeMode) {
                  ThemeMode.system => 'system',
                  ThemeMode.light => 'light',
                  ThemeMode.dark => 'dark',
                };

          return ListView(
            children: [
              // ── 1. 外觀 ────────────────────────────────────────────────
              _SectionHeader(l10n.appearance),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.brightness_6_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.themeMode,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 4-option SegmentedButton (system / light / dark / colorful)
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'system',
                          label: Text(l10n.themeSystem),
                          icon: const Icon(Icons.brightness_auto_outlined),
                        ),
                        ButtonSegment(
                          value: 'light',
                          label: Text(l10n.themeLight),
                          icon: const Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: 'dark',
                          label: Text(l10n.themeDark),
                          icon: const Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment(
                          value: 'colorful',
                          label: Text(l10n.themeColorful),
                          icon: const Icon(Icons.auto_awesome),
                        ),
                      ],
                      selected: {currentThemeOption},
                      onSelectionChanged: (s) =>
                          _onThemeChanged(s.first, colorVariant, ref),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(indent: 16, endIndent: 16, height: 24),

              // ── 2. 語言 ────────────────────────────────────────────────
              _SectionHeader(l10n.language),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.displayLanguage,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'zh-TW',
                          label: Text('繁體中文'),
                          icon: Icon(Icons.translate),
                        ),
                        ButtonSegment(
                          value: 'en',
                          label: Text('English'),
                          icon: Icon(Icons.language),
                        ),
                      ],
                      selected: {settings.locale},
                      onSelectionChanged: (s) => ref
                          .read(settingsNotifierProvider.notifier)
                          .setLocale(s.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(indent: 16, endIndent: 16, height: 24),

              // ── 3. 備份 ────────────────────────────────────────────────
              _SectionHeader(l10n.backup),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(l10n.autoBackupFrequency),
                trailing: _FrequencyDropdown(
                  value: settings.backupFrequency,
                  l10n: l10n,
                  onChanged: (v) => ref
                      .read(settingsNotifierProvider.notifier)
                      .setBackupFrequency(v),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.backup_outlined),
                title: Text(l10n.autoBackup),
                subtitle: Text(l10n.autoBackupSubtitle),
                value: settings.autoBackup,
                onChanged: (newValue) => _onAutoBackupChanged(
                    newValue, context, ref, settings.autoBackup, l10n),
              ),

              const Divider(indent: 16, endIndent: 16, height: 24),

              // ── 4. 資料工具 ──────────────────────────────────────────────
              _SectionHeader(l10n.dataTools),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(l10n.excelExportImport),
                subtitle: Text(l10n.excelSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/excel'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(l10n.backupRestore),
                subtitle: Text(l10n.backupRestoreSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/backup'),
              ),

              const Divider(indent: 16, endIndent: 16, height: 24),

              // ── 5. 關於 ────────────────────────────────────────────────
              _SectionHeader(l10n.about),
              _AboutSection(l10n: l10n),
            ],
          );
        },
      ),
    );
  }

  void _onThemeChanged(
      String mode, String currentVariant, WidgetRef ref) {
    if (mode == 'colorful') {
      ref.read(colorVariantNotifierProvider.notifier).setColorVariant('colorful');
    } else {
      if (currentVariant == 'colorful') {
        ref.read(colorVariantNotifierProvider.notifier).setColorVariant('default');
      }
      final themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      ref.read(settingsNotifierProvider.notifier).setThemeMode(themeMode);
    }
  }

  void _onAutoBackupChanged(bool newValue, BuildContext context, WidgetRef ref,
      bool currentValue, AppLocalizations l10n) {
    if (!newValue || GoogleAuthService.instance.isSignedIn) {
      ref.read(settingsNotifierProvider.notifier).toggleAutoBackup();
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_sync_outlined, size: 40),
        title: Text(l10n.needGoogleSignIn),
        content: Text(l10n.needGoogleSignInContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.signIn),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !context.mounted) return;
      final account = await GoogleAuthService.instance.signIn();
      if (account != null && context.mounted) {
        ref.read(settingsNotifierProvider.notifier).toggleAutoBackup();
        ref.invalidate(backupNotifierProvider);
      }
    });
  }
}

// ── 自動備份頻率下拉選單 ──────────────────────────────────────────────────────────

class _FrequencyDropdown extends StatelessWidget {
  const _FrequencyDropdown({
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final options = {
      'off': l10n.freqOff,
      'daily': l10n.freqDaily,
      'weekly': l10n.freqWeekly,
      'monthly': l10n.freqMonthly,
    };

    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── 關於 App 區塊 ──────────────────────────────────────────────────────────────

class _AboutSection extends ConsumerWidget {
  const _AboutSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(packageInfoProvider);

    final versionText = infoAsync.when(
      loading: () => '…',
      error: (_, __) => '1.0.0',
      data: (info) => info.buildNumber.isNotEmpty
          ? '${info.version} (${info.buildNumber})'
          : info.version,
    );

    const copyright = '© 2024–present Danece Chou. All rights reserved.';

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.versionLabel),
          trailing: Text(
            versionText,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.copyright_outlined),
          title: Text(l10n.copyrightLabel),
          subtitle: Text(
            copyright,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(l10n.licenses),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final version = infoAsync.valueOrNull?.version ?? '';
            showLicensePage(
              context: context,
              applicationName: 'Travel Mark',
              applicationVersion: version,
              applicationLegalese: copyright,
            );
          },
        ),
      ],
    );
  }
}

// ── 區塊標題 ──────────────────────────────────────────────────────────────────

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
