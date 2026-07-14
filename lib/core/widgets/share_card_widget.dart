import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/marker/domain/entities/marker_category.dart';
import '../../features/marker/domain/entities/marker_entity.dart';
import '../utils/country_flag.dart';
import 'weather_icon_widget.dart';

// ── 旅遊分享卡片 ──────────────────────────────────────────────────────────────────
//
// 固定寬度 360dp，供 screenshot 套件截圖後分享或儲存到相簿。
// 不使用 Theme，改用硬編碼色彩，確保截圖結果不受系統深色模式影響。

/// 旅遊分享卡片，由上往下分三區：
///   1. 照片（或類別漸層）+ 覆蓋資訊（標題 / 國家 / 日期 / 天氣）
///   2. 白底資訊區（星號評分 + 旅遊筆記預覽）
///   3. 品牌底條（Teal 700）
class ShareCardWidget extends StatelessWidget {
  const ShareCardWidget({super.key, required this.marker});

  final MarkerEntity marker;

  static const double cardWidth = 360;

  @override
  Widget build(BuildContext context) {
    final category = MarkerCategory.fromString(marker.category);
    final photoPath =
        marker.photoPaths.isNotEmpty ? marker.photoPaths.first : null;

    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 上方照片 / 漸層 + 覆蓋資訊 ───────────────────────────────────
              SizedBox(
                height: 230,
                width: cardWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景：照片或類別漸層
                    _CardBackground(photoPath: photoPath, category: category),

                    // 由上至下的深色漸層，確保底部文字可讀
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.25, 1.0],
                        ),
                      ),
                    ),

                    // 左上角 App 品牌文字
                    const Positioned(
                      top: 14,
                      left: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore,
                              color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Travel Mark',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 右上角：類別 emoji 標籤
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    // 底部覆蓋資訊（國家 / 標題 / 日期 / 天氣）
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: _OverlayInfo(marker: marker),
                    ),
                  ],
                ),
              ),

              // ── 白底資訊區（評分 + 筆記） ─────────────────────────────────────
              ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 五星評分 + 評分標籤
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < marker.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < marker.rating
                                  ? Colors.amber
                                  : Colors.grey[300],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _ratingLabel(marker.rating),
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // 旅遊筆記（有且非空才顯示，最多 2 行）
                      if (marker.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          marker.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 品牌底條 ───────────────────────────────────────────────────────
              ColoredBox(
                color: const Color(0xFF00695C), // Teal 700，與 App 主題色一致
                child: SizedBox(
                  height: 38,
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.travel_explore,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Travel Mark',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Made with ♥',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ratingLabel(int rating) => switch (rating) {
        1 => '普通',
        2 => '還不錯',
        3 => '不錯',
        4 => '很棒',
        5 => '超讚！',
        _ => '',
      };
}

// ── 背景：照片 or 類別漸層 ────────────────────────────────────────────────────────

class _CardBackground extends StatelessWidget {
  const _CardBackground({
    required this.photoPath,
    required this.category,
  });

  final String? photoPath;
  final MarkerCategory category;

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && File(photoPath!).existsSync()) {
      return Image.file(
        File(photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _categoryColors(category),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  static List<Color> _categoryColors(MarkerCategory cat) => switch (cat) {
        MarkerCategory.attraction => [
            const Color(0xFF1565C0),
            const Color(0xFF42A5F5),
          ],
        MarkerCategory.food => [
            const Color(0xFFBF360C),
            const Color(0xFFFFA000),
          ],
        MarkerCategory.accommodation => [
            const Color(0xFF4A148C),
            const Color(0xFF9C27B0),
          ],
        MarkerCategory.shopping => [
            const Color(0xFFAD1457),
            const Color(0xFFE91E63),
          ],
        MarkerCategory.nature => [
            const Color(0xFF1B5E20),
            const Color(0xFF4CAF50),
          ],
        MarkerCategory.culture => [
            const Color(0xFF4E342E),
            const Color(0xFF8D6E63),
          ],
        MarkerCategory.entertainment => [
            const Color(0xFF880E4F),
            const Color(0xFFE91E63),
          ],
        MarkerCategory.transport => [
            const Color(0xFF0D47A1),
            const Color(0xFF1976D2),
          ],
        MarkerCategory.other => [
            const Color(0xFF37474F),
            const Color(0xFF78909C),
          ],
      };
}

// ── 照片下方文字覆蓋 ──────────────────────────────────────────────────────────────

class _OverlayInfo extends StatelessWidget {
  const _OverlayInfo({required this.marker});
  final MarkerEntity marker;

  @override
  Widget build(BuildContext context) {
    final d = marker.createdAt;
    final dateStr =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 國旗 + 國家名
        Row(
          children: [
            Text(
              countryFlag(marker.country),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              marker.country,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // 標題（最多 2 行）
        Text(
          marker.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),

        // 日期 + 天氣（有天氣資料才顯示）
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Colors.white60, size: 12),
            const SizedBox(width: 4),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (marker.weatherCondition != null) ...[
              const SizedBox(width: 10),
              WeatherIconWidget(
                condition: marker.weatherCondition!,
                size: 14,
                showLabel: false,
              ),
              if (marker.temperature != null) ...[
                const SizedBox(width: 4),
                Text(
                  '${marker.temperature}°C',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }
}
