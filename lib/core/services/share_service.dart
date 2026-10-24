import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

// ── 分享與儲存服務 ─────────────────────────────────────────────────────────────────
//
// 封裝 share_plus 與 gal 的操作，提供靜態方法供 UI 層呼叫。
// 呼叫端負責先透過 ScreenshotController.capture() 取得 Uint8List 再傳入。
//
// gal 套件（取代 image_gallery_saver）相容 AGP namespace 規範，
// Android API 29+ 使用 MediaStore 無需額外權限。

/// 旅遊卡片分享服務。
class ShareService {
  const ShareService._();

  /// 將圖片位元組儲存到手機相簿，回傳是否儲存成功。
  ///
  /// [bytes]：PNG 位元組資料（由 screenshot 套件擷取）
  /// [name]：相簿中的檔名（不含副檔名）；若未指定則使用時間戳。
  static Future<bool> saveToGallery(
    Uint8List bytes, {
    String? name,
  }) async {
    final filename =
        name ?? 'travel_mark_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await Gal.putImageBytes(bytes, name: filename);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 透過系統分享介面傳送圖片（iOS 選單 / Android 分享列表）。
  ///
  /// [bytes]：PNG 位元組資料
  /// [title]：分享時附帶的文字標題，預設為標記標題。
  static Future<void> shareImage(
    Uint8List bytes, {
    String title = 'Travel Mark',
  }) async {
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'travel_card.png',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: title,
      ),
    );
  }
}
