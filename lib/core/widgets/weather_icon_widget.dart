import 'package:flutter/material.dart';

/// 依 [condition] 代碼顯示對應的天氣圖示與顏色。
///
/// [condition] 來自 [WeatherService] 的 `WeatherResult.icon`，
/// 例如 `"clear"`、`"rain"`、`"snow"`。
///
/// [showLabel] 為 true 時，在圖示下方顯示中文天氣描述小字。
class WeatherIconWidget extends StatelessWidget {
  const WeatherIconWidget({
    super.key,
    required this.condition,
    this.size = 24,
    this.showLabel = false,
  });

  final String condition;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final style = _weatherStyle(condition);

    if (!showLabel) {
      return Icon(style.icon, size: size, color: style.color);
    }

    // showLabel = true：圖示下方附中文描述
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, size: size, color: style.color),
        const SizedBox(height: 2),
        Text(
          style.label,
          style: TextStyle(
            fontSize: size * 0.42, // 字體隨圖示等比縮放
            color: style.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── 天氣樣式資料類別 ────────────────────────────────────────────────────────────

/// 單一天氣狀況的顯示資料：圖示、顏色、中文標籤。
class _WeatherStyle {
  const _WeatherStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

// ── condition → 樣式對照 ────────────────────────────────────────────────────────

/// 將 [condition] 代碼對應至 [_WeatherStyle]。
///
/// 未知代碼統一以「多雲」樣式顯示，避免顯示空白。
_WeatherStyle _weatherStyle(String condition) => switch (condition) {
      'clear' => const _WeatherStyle(
          icon: Icons.wb_sunny,
          color: Color(0xFFF59E0B), // 琥珀黃
          label: '晴天',
        ),
      'cloudy' => const _WeatherStyle(
          icon: Icons.cloud,
          color: Color(0xFF94A3B8), // 淡藍灰
          label: '多雲',
        ),
      'fog' => const _WeatherStyle(
          icon: Icons.foggy,
          color: Color(0xFF9CA3AF), // 灰
          label: '霧',
        ),
      'drizzle' => const _WeatherStyle(
          icon: Icons.grain,
          color: Color(0xFF60A5FA), // 淡藍
          label: '毛毛雨',
        ),
      'rain' => const _WeatherStyle(
          icon: Icons.umbrella,
          color: Color(0xFF3B82F6), // 藍
          label: '雨天',
        ),
      'snow' => const _WeatherStyle(
          icon: Icons.ac_unit,
          color: Color(0xFFBAE6FD), // 冰藍
          label: '雪天',
        ),
      'shower' => const _WeatherStyle(
          icon: Icons.thunderstorm,
          color: Color(0xFF6366F1), // 靛紫
          label: '陣雨',
        ),
      'snow_shower' => const _WeatherStyle(
          icon: Icons.cloudy_snowing,
          color: Color(0xFFBAE6FD), // 冰藍
          label: '陣雪',
        ),
      'thunderstorm' => const _WeatherStyle(
          icon: Icons.flash_on,
          color: Color(0xFFEF4444), // 紅
          label: '雷陣雨',
        ),
      'heavy_thunderstorm' => const _WeatherStyle(
          icon: Icons.flash_on,
          color: Color(0xFFDC2626), // 深紅
          label: '強雷陣雨',
        ),
      // 未知代碼 fallback
      _ => const _WeatherStyle(
          icon: Icons.wb_cloudy,
          color: Color(0xFF94A3B8),
          label: '未知',
        ),
    };
