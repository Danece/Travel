import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../domain/entities/import_result.dart';
import '../providers/excel_provider.dart';

class ExcelPage extends ConsumerWidget {
  const ExcelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(excelNotifierProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.excelPageTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 說明卡片 ──────────────────────────────────────────────────
            _InfoCard(l10n: l10n),
            const SizedBox(height: 32),

            // ── 匯出區塊 ──────────────────────────────────────────────────
            _SectionLabel(l10n.exportSection),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isLoading ? null : () => _onExport(context, ref, l10n),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(isLoading ? l10n.processing : l10n.exportButton),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 32),

            // ── 匯入區塊 ──────────────────────────────────────────────────
            _SectionLabel(l10n.importSection),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => _onImport(context, ref, l10n),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(isLoading ? l10n.processing : l10n.importButton),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // ── 錯誤訊息 ──────────────────────────────────────────────────
            if (state.hasError) ...[
              const SizedBox(height: 16),
              Container(
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
                        color: Theme.of(context).colorScheme.error,
                        size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.errorPrefix}${state.error}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onExport(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final savedPath =
        await ref.read(excelNotifierProvider.notifier).export();

    if (!context.mounted) return;

    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.savedTo(savedPath)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.gotIt,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _onImport(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cannotGetFilePath)),
        );
      }
      return;
    }

    if (!filePath.toLowerCase().endsWith('.csv')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.csvOnlyError)),
        );
      }
      return;
    }

    final importResult =
        await ref.read(excelNotifierProvider.notifier).import(filePath);

    if (!context.mounted) return;

    if (importResult != null) {
      await _showImportResultDialog(context, importResult, l10n);
    }
  }

  Future<void> _showImportResultDialog(
    BuildContext context,
    ImportResult result,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          result.failedRows.isEmpty
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          size: 40,
          color: result.failedRows.isEmpty ? Colors.green : Colors.orange,
        ),
        title: Text(l10n.importComplete),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultRow(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  label: l10n.importSuccess,
                  value: '${result.successCount} ${l10n.isEn ? 'records' : '筆'}',
                ),
                const SizedBox(height: 6),
                _ResultRow(
                  icon: Icons.skip_next_outlined,
                  color: Colors.grey,
                  label: l10n.importSkipped,
                  value: '${result.skippedCount} ${l10n.isEn ? 'rows' : '列'}',
                ),
                if (result.failedRows.isEmpty) ...[
                  const SizedBox(height: 6),
                  _ResultRow(
                    icon: Icons.error_outline,
                    color: Colors.grey,
                    label: l10n.importValidationFailed,
                    value: l10n.noneLabel,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    l10n.importFailedCount(result.failedRows.length),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(result.failedRows.length, (i) {
                    final msg = i < result.failedMessages.length
                        ? result.failedMessages[i]
                        : l10n.unknownError(result.failedRows[i]);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              msg,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

// ── 說明卡片 ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                l10n.excelFormatInfo,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.excelFormatContent,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── 區塊標題 ───────────────────────────────────────────────────────────────────

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

// ── 結果 Dialog 內的單列 ────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
