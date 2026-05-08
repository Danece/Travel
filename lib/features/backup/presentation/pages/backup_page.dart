import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/backup_file_entity.dart';
import '../providers/backup_provider.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _isOperating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backupAsync = ref.watch(backupNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final account = GoogleAuthService.instance.currentUser;
    final isSignedIn = account != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupPageTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. Google 帳號卡 ─────────────────────────────────────────────
          _AccountCard(
            account: account,
            isLoading: backupAsync.isLoading && !isSignedIn,
            onSignIn: _handleSignIn,
            onSignOut: _handleSignOut,
            l10n: l10n,
          ),

          if (!isSignedIn) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  l10n.signInFirst,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── 2. 自動備份頻率 ──────────────────────────────────────────────
          if (isSignedIn)
            settingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (settings) => _FrequencyCard(
                value: settings.backupFrequency,
                l10n: l10n,
                onChanged: (v) => ref
                    .read(settingsNotifierProvider.notifier)
                    .setBackupFrequency(v),
              ),
            ),

          if (isSignedIn) const SizedBox(height: 20),

          // ── 3. 立即備份按鈕 ──────────────────────────────────────────────
          if (isSignedIn)
            FilledButton.icon(
              onPressed: _isOperating || backupAsync.isLoading
                  ? null
                  : _handleBackup,
              icon: _isOperating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isOperating ? l10n.backingUp : l10n.backupNow),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

          if (isSignedIn) const SizedBox(height: 24),

          // ── 4. 備份歷史清單 ──────────────────────────────────────────────
          if (isSignedIn) ...[
            _SectionLabel(l10n.backupHistory),
            const SizedBox(height: 8),
            backupAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _ErrorBanner(
                  message: e.toString(), l10n: l10n),
              data: (list) => list.isEmpty
                  ? _EmptyBackupState(l10n: l10n)
                  : _BackupList(
                      items: list,
                      disabled: _isOperating,
                      onDelete: _handleDelete,
                      onRestore: _handleRestore,
                    ),
            ),
          ],

          if (!backupAsync.isLoading && backupAsync.hasError)
            _ErrorBanner(
                message: backupAsync.error.toString(), l10n: l10n),
        ],
      ),
    );
  }

  Future<void> _handleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isOperating = true);
    final success =
        await ref.read(backupNotifierProvider.notifier).signIn();
    if (mounted) {
      setState(() => _isOperating = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signInCancelled)),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(backupNotifierProvider.notifier).signOut();
    if (mounted) setState(() {});
  }

  Future<void> _handleBackup() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isOperating = true);

    final name =
        await ref.read(backupNotifierProvider.notifier).createBackup();

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (name != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.backupDone(name)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: l10n.gotIt, onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _handleDelete(BackupFileEntity item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showDeleteDialog(item.name, l10n);
    if (confirmed != true || !mounted) return;

    setState(() => _isOperating = true);
    final success = await ref
        .read(backupNotifierProvider.notifier)
        .deleteBackup(item.id);

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteFailed)),
      );
    }
  }

  Future<void> _handleRestore(BackupFileEntity item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showRestoreDialog(item.name, l10n);
    if (confirmed != true || !mounted) return;

    setState(() => _isOperating = true);
    final success = await ref
        .read(backupNotifierProvider.notifier)
        .restore(item.id);

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.restoreSuccess),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<bool?> _showDeleteDialog(
      String name, AppLocalizations l10n) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteBackup),
          content: Text(l10n.deleteBackupConfirm(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.error),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );

  Future<bool?> _showRestoreDialog(
      String name, AppLocalizations l10n) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined,
              size: 40, color: Colors.orange),
          title: Text(l10n.confirmRestore),
          content: Text(l10n.restoreConfirm(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.error),
              child: Text(l10n.confirmRestoreBtn),
            ),
          ],
        ),
      );
}

// ── Google 帳號卡 ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.isLoading,
    required this.onSignIn,
    required this.onSignOut,
    required this.l10n,
  });

  final dynamic account;
  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: account == null
            ? _buildSignInContent(context)
            : _buildAccountContent(context),
      ),
    );
  }

  Widget _buildSignInContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.googleDriveBackup,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.signInToUseBackupDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onSignIn,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(l10n.signInGoogle),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountContent(BuildContext context) {
    final photoUrl = account?.photoUrl as String?;
    final email = account?.email as String? ?? '';
    final displayName = account?.displayName as String? ?? email;

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage:
              photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 20),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSignOut,
          child: Text(l10n.signOut),
        ),
      ],
    );
  }
}

// ── 自動備份頻率卡 ──────────────────────────────────────────────────────────────

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({
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

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.autoBackupFrequency,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            DropdownButton<String>(
              value: value,
              underline: const SizedBox.shrink(),
              items: options.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 備份歷史清單 ───────────────────────────────────────────────────────────────

class _BackupList extends StatelessWidget {
  const _BackupList({
    required this.items,
    required this.disabled,
    required this.onDelete,
    required this.onRestore,
  });

  final List<BackupFileEntity> items;
  final bool disabled;
  final ValueChanged<BackupFileEntity> onDelete;
  final ValueChanged<BackupFileEntity> onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => _BackupItem(
                item: item,
                disabled: disabled,
                onDelete: () => onDelete(item),
                onRestore: () => onRestore(item),
              ))
          .toList(),
    );
  }
}

class _BackupItem extends StatelessWidget {
  const _BackupItem({
    required this.item,
    required this.disabled,
    required this.onDelete,
    required this.onRestore,
  });

  final BackupFileEntity item;
  final bool disabled;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : onRestore,
        onLongPress: disabled ? null : onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder_zip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatMeta(item),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.restore_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMeta(BackupFileEntity item) {
    final d = item.createdTime;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

    if (item.sizeBytes == null) return date;
    final size = _formatSize(item.sizeBytes!);
    return '$date  ·  $size';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── 空清單狀態 ─────────────────────────────────────────────────────────────────

class _EmptyBackupState extends StatelessWidget {
  const _EmptyBackupState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noBackupRecords,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.createFirstBackup,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── 錯誤橫幅 ────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.l10n});

  final String message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.errorPrefix}$message',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 區塊標題 ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}
