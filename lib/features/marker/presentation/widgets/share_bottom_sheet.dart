import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../core/services/share_service.dart';
import '../../../../core/widgets/share_card_widget.dart';
import '../../domain/entities/marker_entity.dart';

// ── 旅遊卡片分享底部選單 ───────────────────────────────────────────────────────────

/// 顯示旅遊卡片分享底部選單。
///
/// 包含卡片預覽、「儲存到相簿」與「分享」兩個操作按鈕。
/// 在任何持有 [BuildContext] 的地方呼叫即可：
///
/// ```dart
/// showShareBottomSheet(context, marker);
/// ```
Future<void> showShareBottomSheet(
  BuildContext context,
  MarkerEntity marker,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShareBottomSheet(marker: marker),
  );
}

class _ShareBottomSheet extends StatefulWidget {
  const _ShareBottomSheet({required this.marker});
  final MarkerEntity marker;

  @override
  State<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<_ShareBottomSheet> {
  final _screenshotController = ScreenshotController();
  bool _isBusy = false;

  // 以 3x 像素比截圖，確保輸出圖質細膩
  Future<Uint8List?> _capture() =>
      _screenshotController.capture(pixelRatio: 3.0);

  Future<void> _saveToGallery() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _capture();
      if (bytes == null || !mounted) return;

      final success = await ShareService.saveToGallery(bytes);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已儲存到相簿 ✓' : '儲存失敗，請確認相簿權限'),
          backgroundColor: success ? null : Colors.red[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲存失敗：$e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _capture();
      if (bytes == null || !mounted) return;
      await ShareService.shareImage(bytes, title: widget.marker.title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分享失敗：$e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖曳把手
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 標題列
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.share_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  '分享旅遊卡片',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 16),

          // 卡片預覽（水平可滾動，避免窄螢幕溢出）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Screenshot(
              controller: _screenshotController,
              child: ShareCardWidget(marker: widget.marker),
            ),
          ),

          const SizedBox(height: 20),

          // 操作按鈕列：儲存 / 分享
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // 儲存到相簿
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _saveToGallery,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('儲存到相簿'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 系統分享
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _shareImage,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('分享'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
