import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      );

  /// 繽紛主題：高飽和度多色彩，充滿活力
  static ThemeData get colorful => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          // 主色：亮麗洋紅紫
          primary: Color(0xFFCC00DD),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFF5AAFF),
          onPrimaryContainer: Color(0xFF38003F),
          // 次色：活力橘
          secondary: Color(0xFFFF5500),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFFCDB8),
          onSecondaryContainer: Color(0xFF3B0F00),
          // 三色：電光青藍
          tertiary: Color(0xFF0097C4),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFB3EEFF),
          onTertiaryContainer: Color(0xFF001E2C),
          // 錯誤色
          error: Color(0xFFB3261E),
          onError: Colors.white,
          errorContainer: Color(0xFFF9DEDC),
          onErrorContainer: Color(0xFF410E0B),
          // 背景 / 表面
          surface: Color(0xFFFFFBFF),
          onSurface: Color(0xFF1C1B1F),
          surfaceContainerHighest: Color(0xFFECDCF4),
          onSurfaceVariant: Color(0xFF4A454E),
          outline: Color(0xFF7B747F),
          outlineVariant: Color(0xFFCDC4D0),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Color(0xFF322F35),
          onInverseSurface: Color(0xFFF5EFF7),
          inversePrimary: Color(0xFFEDABFF),
        ),
      );
}
