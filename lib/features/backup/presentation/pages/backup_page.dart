import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/google_auth_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/backup_file_entity.dart';
import '../providers/backup_provider.dart';

// ── 備份與還原頁 ───────────────────────────────────────────────────────────────
//
// 結構：
//   1. Google 帳號卡（已登入顯示頭像 + Email；未登入顯示登入按鈕）
//   2. 自動備份頻率下拉選單（儲存至 SettingsProvider）
//   3. 「立即備份」按鈕
//   4. 備份歷史清單（長按刪除、點擊還原）
//   5. 操作失敗時顯示錯誤橫幅

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  /// 按鈕操作進行中（備份 / 還原 / 刪除），防止重複觸發
  bool _isOperating = false;

  @override
  Widget build(BuildContext context) {
    final backupAsync = ref.watch(backupNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final account = GoogleAuthService.instance.currentUser;
    final isSignedIn = account != null;

    return Scaffold(
      appBar: AppBar(title: const Text('備份與還原')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. Google 帳號卡 ─────────────────────────────────────────────
          _AccountCard(
            account: account,
            isLoading: backupAsync.isLoading && !isSignedIn,
            onSignIn: _handleSignIn,
            onSignOut: _handleSignOut,
          ),

          // ── 未登入提示 ───────────────────────────────────────────────────
          if (!isSignedIn) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '請先登入 Google 帳號以使用備份功能',
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
              label: Text(_isOperating ? '備份中…' : '立即備份'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

          if (isSignedIn) const SizedBox(height: 24),

          // ── 4. 備份歷史清單 ──────────────────────────────────────────────
          if (isSignedIn) ...[
            _SectionLabel('備份歷史'),
            const SizedBox(height: 8),
            backupAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _ErrorBanner(message: e.toString()),
              data: (list) => list.isEmpty
                  ? _EmptyBackupState()
                  : _BackupList(
                      items: list,
                      disabled: _isOperating,
                      onDelete: _handleDelete,
                      onRestore: _handleRestore,
                    ),
            ),
          ],

          // ── 5. 操作失敗橫幅 ─────────────────────────────────────────────
          if (!backupAsync.isLoading && backupAsync.hasError)
            _ErrorBanner(message: backupAsync.error.toString()),
        ],
      ),
    );
  }

  // ── 操作處理 ───────────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    setState(() => _isOperating = true);
    final success =
        await ref.read(backupNotifierProvider.notifier).signIn();
    if (mounted) {
      setState(() => _isOperating = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 登入取消或失敗，請重試')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(backupNotifierProvider.notifier).signOut();
    if (mounted) setState(() {});
  }

  Future<void> _handleBackup() async {
    setState(() => _isOperating = true);

    final name =
        await ref.read(backupNotifierProvider.notifier).createBackup();

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (name != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('備份完成：$name'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '知道了', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _handleDelete(BackupFileEntity item) async {
    final confirmed = await _showDeleteDialog(item.name);
    if (confirmed != true || !mounted) return;

    setState(() => _isOperating = true);
    final success = await ref
        .read(backupNotifierProvider.notifier)
        .deleteBackup(item.id);

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('刪除失敗，請重試')),
      );
    }
  }

  Future<void> _handleRestore(BackupFileEntity item) async {
    final confirmed = await _showRestoreDialog(item.name);
    if (confirmed != true || !mounted) return;

    setState(() => _isOperating = true);
    final success = await ref
        .read(backupNotifierProvider.notifier)
        .restore(item.id);

    if (!mounted) return;
    setState(() => _isOperating = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('還原成功！所有地標資料已更新'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // ── 確認 Dialog ────────────────────────────────────────────────────────────

  Future<bool?> _showDeleteDialog(String name) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('刪除備份'),
          content: Text('確定刪除「$name」？此操作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('刪除'),
            ),
          ],
        ),
      );

  Future<bool?> _showRestoreDialog(String name) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined,
              size: 40, color: Colors.orange),
          title: const Text('確認還原'),
          content: Text(
            '將以「$name」覆蓋目前所有資料。\n此操作無法復原，確定繼續嗎？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('確認還原'),
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
  });

  final dynamic account; // GoogleSignInAccount?
  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'Google Drive 備份',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '登入 Google 帳號以將備份儲存至 Drive，\n可在任何裝置還原您的旅遊資料。',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
            label: const Text('登入 Google 帳號'),
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
        // 帳號頭像
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
        // 帳號資訊
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
        // 登出按鈕
        TextButton(
          onPressed: onSignOut,
          child: const Text('登出'),
        ),
      ],
    );
  }
}

// ── 自動備份頻率卡 ──────────────────────────────────────────────────────────────

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({required this.value, required this.onChanged});

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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '自動備份頻率',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            DropdownButton<String>(
              value: value,
              underline: const SizedBox.shrink(),
              items: _options.entries
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : onRestore,
        onLongPress: disabled ? null : onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 備份圖示
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
              // 備份資訊
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              // 提示圖示
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
            '尚無備份紀錄',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '點擊「立即備份」建立第一份備份',
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
  const _ErrorBanner({required this.message});

  final String message;

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
              '錯誤：$message',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13),
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
