// ── 匯入結果資料物件 ──────────────────────────────────────────────────────────
//
// 匯入完成後回傳此物件，包含：
//   - successCount：成功寫入的地標數量
//   - skippedCount：資料不完整而跳過的列數
//   - failedRows：驗證失敗的列號清單（1-indexed，包含標題列在內的原始行號）
//   - failedMessages：每筆失敗的原因說明（與 failedRows 等長）

class ImportResult {
  const ImportResult({
    required this.successCount,
    required this.skippedCount,
    required this.failedRows,
    this.failedMessages = const [],
  });

  /// 成功匯入的地標筆數
  final int successCount;

  /// 跳過的列數（空白列）
  final int skippedCount;

  /// 驗證失敗的原始列號清單（如 [3, 7] 代表第 3、7 列有問題）
  final List<int> failedRows;

  /// 每筆失敗的原因說明（與 failedRows 等長）
  final List<String> failedMessages;

  /// 是否所有列都處理成功
  bool get isAllSuccess => failedRows.isEmpty && skippedCount == 0;
}
