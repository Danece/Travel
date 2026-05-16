import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // 單一主控制器，總時長 2600ms
  late final AnimationController _ctrl;

  // ── icon 動畫 ──────────────────────────────────────────────────────────────
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _ringRotate; // 外環旋轉

  // ── 文字動畫 ────────────────────────────────────────────────────────────────
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;

  // ── 退場 ────────────────────────────────────────────────────────────────────
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // icon 從 0.2 縮放到 1.1 再彈回 1.0（帶 bounce）
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.36),
    ));

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.02, curve: Curves.easeIn),
      ),
    );

    // 外裝飾環緩慢旋轉一整圈
    _ringRotate = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
      ),
    );

    // 標題：向上滑入 + 淡入
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.18, 0.42, curve: Curves.easeOutCubic),
    ));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.40, curve: Curves.easeIn),
      ),
    );

    // 副標題淡入
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.32, 0.52, curve: Curves.easeIn),
      ),
    );

    // 退場淡出
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/');
      }
    });

    // 等第一幀繪製完畢才啟動，確保動畫從使用者看到畫面的瞬間開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitOpacity,
      builder: (context, child) => Opacity(
        opacity: _exitOpacity.value,
        child: child,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
              colors: [
                Color(0xFF00897B), // teal 600
                Color(0xFF00695C), // teal 700
                Color(0xFF004D40), // teal 900
              ],
            ),
          ),
          child: Stack(
            children: [
              // ── 裝飾圓點 ────────────────────────────────────────────────────
              Positioned(
                top: -60,
                right: -60,
                child: _DecorCircle(size: 220, opacity: 0.08),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: _DecorCircle(size: 300, opacity: 0.06),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.72,
                right: 40,
                child: _DecorCircle(size: 80, opacity: 0.10),
              ),

              // ── 主體 ─────────────────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // icon 容器
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Opacity(
                        opacity: _iconOpacity.value,
                        child: Transform.scale(
                          scale: _iconScale.value,
                          child: _SplashIcon(rotation: _ringRotate.value),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // APP 名稱
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleOpacity,
                        child: const _AppTitle(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 副標題
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: const _AppSubtitle(),
                    ),
                  ],
                ),
              ),

              // ── 底部版本文字 ─────────────────────────────────────────────
              FadeTransition(
                opacity: _subtitleOpacity,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Text(
                      'v1.0.5',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
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
}

// ── 圖示元件 ──────────────────────────────────────────────────────────────────

class _SplashIcon extends StatelessWidget {
  const _SplashIcon({required this.rotation});
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外環（旋轉虛線裝飾）
          Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _DashedCirclePainter(),
            ),
          ),
          // 主圓形容器
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 虛線外環 Painter ──────────────────────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 20;
    const dashAngle = 2 * pi / dashCount;
    const gapRatio = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapRatio);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── APP 標題 ──────────────────────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB2DFDB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'Travel Mark',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 副標題 ────────────────────────────────────────────────────────────────────

class _AppSubtitle extends StatelessWidget {
  const _AppSubtitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '記錄每一段旅程',
      style: TextStyle(
        color: Colors.white60,
        fontSize: 14,
        letterSpacing: 4.0,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

// ── 裝飾圓 ────────────────────────────────────────────────────────────────────

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
