import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/import_result.dart';
import '../providers/excel_provider.dart';

// ── Excel 匯出 / 匯入頁 ───────────────────────────────────────────────────────
//
// 頁面提供兩個主要操作：
//   1. 匯出：將所有地標寫入 xlsx 並顯示儲存路徑
//   2. 匯入：以 FilePicker 選取 .xlsx 後批量寫入資料庫，完成後顯示摘要 Dialog

class ExcelPage extends ConsumerWidget {
  const ExcelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(excelNotifierProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Excel 匯出 / 匯入')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 說明卡片 ────────────────────────────────────────────────
            _InfoCard(),
            const SizedBox(height: 32),

            // ── 匯出區塊 ────────────────────────────────────────────────
            const _SectionLabel('匯出'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isLoading ? null : () => _onExport(context, ref),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(isLoading ? '處理中…' : '匯出為 Excel（.xlsx）'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 32),

            // ── 匯入區塊 ────────────────────────────────────────────────
            const _SectionLabel('匯入'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => _onImport(context, ref),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(isLoading ? '處理中…' : '選取 .xlsx 檔案並匯入'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // ── 錯誤訊息（AsyncError 時顯示）───────────────────────────
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
                        color: Theme.of(context).colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '錯誤：${state.error}',
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

  // ── 匯出流程 ───────────────────────────────────────────────────────────────

  Future<void> _onExport(BuildContext context, WidgetRef ref) async {
    final savedPath =
        await ref.read(excelNotifierProvider.notifier).export();

    if (!context.mounted) return;

    if (savedPath != null) {
      // 成功：顯示包含完整路徑的 SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已儲存至 $savedPath'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '知道了',
            onPressed: () {},
          ),
        ),
      );
    }
    // 失敗時 state 已更新為 AsyncError，UI 自動顯示錯誤訊息
  }

  // ── 匯入流程 ───────────────────────────────────────────────────────────────

  Future<void> _onImport(BuildContext context, WidgetRef ref) async {
    // 1. 以 FilePicker 讓使用者選取 .xlsx 檔案
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return; // 使用者取消

    final filePath = result.files.single.path;
    if (filePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法取得檔案路徑，請重試')),
        );
      }
      return;
    }

    // 2. 執行匯入
    final importResult =
        await ref.read(excelNotifierProvider.notifier).import(filePath);

    if (!context.mounted) return;

    // 3. 顯示結果摘要 Dialog
    if (importResult != null) {
      await _showImportResultDialog(context, importResult);
    }
  }

  /// 顯示匯入結果摘要 Dialog（失敗列可捲動展示原因）
  Future<void> _showImportResultDialog(
    BuildContext context,
    ImportResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          result.failedRows.isEmpty
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          size: 40,
          color: result.failedRows.isEmpty ? Colors.green : Colors.orange,
        ),
        title: const Text('匯入完成'),
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
                  label: '成功匯入',
                  value: '${result.successCount} 筆',
                ),
                const SizedBox(height: 6),
                _ResultRow(
                  icon: Icons.skip_next_outlined,
                  color: Colors.grey,
                  label: '跳過（空白列）',
                  value: '${result.skippedCount} 列',
                ),
                if (result.failedRows.isEmpty)
                  ...[
                    const SizedBox(height: 6),
                    _ResultRow(
                      icon: Icons.error_outline,
                      color: Colors.grey,
                      label: '驗證失敗',
                      value: '無',
                    ),
                  ]
                else ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    '驗證失敗（${result.failedRows.length} 筆）',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(result.failedRows.length, (i) {
                    final msg = i < result.failedMessages.length
                        ? result.failedMessages[i]
                        : '第 ${result.failedRows[i]} 列：未知錯誤';
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
            onPressed: () => Navigator.pop(context),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }
}

// ── 說明卡片 ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
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
                'Excel 格式說明',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '匯出欄位：ID、標題、國家、建立日期、緯度、經度、評分、心得內容、照片數量\n'
            '匯入必填：標題、國家、緯度、經度、評分（1–5）\n'
            '日期格式：yyyy-MM-dd（例：2024-04-15）\n'
            '照片路徑不匯出，跨裝置路徑無效',
            style: TextStyle(fontSize: 12),
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
