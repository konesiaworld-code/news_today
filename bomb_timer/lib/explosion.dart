import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 폭발 연출: 섬광 → 불덩이 → 파편 → 연기, 그리고 "BOOM!".
class Explosion extends StatelessWidget {
  const Explosion({super.key, required this.progress, required this.onRestart});

  /// 0~1 애니메이션 진행도.
  final double progress;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = progress;
    final textIn = Curves.elasticOut.transform(((t - 0.08) / 0.4).clamp(0.0, 1.0));
    final buttonIn = ((t - 0.6) / 0.3).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ExplosionPainter(t)),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Transform.rotate(
                angle: -0.12,
                child: Transform.scale(
                  scale: 0.2 + textIn * 0.8,
                  child: Opacity(
                    opacity: textIn.clamp(0.0, 1.0),
                    child: const _BoomText(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: buttonIn,
                child: Text('1시간이 지났습니다',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const Spacer(flex: 2),
              Opacity(
                opacity: buttonIn,
                child: IgnorePointer(
                  ignoring: buttonIn < 1,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8501A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('새 폭탄 설치'),
                  ),
                ),
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoomText extends StatelessWidget {
  const _BoomText();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 96, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1);
    return Stack(
      children: [
        Text('BOOM!',
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 14
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF3A0A00),
            )),
        Text('BOOM!',
            style: style.copyWith(
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF27A), Color(0xFFFFA000), Color(0xFFE53A0A)],
                ).createShader(const Rect.fromLTWH(0, 0, 300, 96)),
            )),
      ],
    );
  }
}

class _ExplosionPainter extends CustomPainter {
  _ExplosionPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.45);
    final maxR = size.longestSide;

    // 배경: 그을린 어둠
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFFFF7A1A), const Color(0xFF2A1208), (t * 2.2).clamp(0.0, 1.0))!,
            const Color(0xFF0A0605),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.8)),
    );

    // 연기
    final rnd = math.Random(3);
    for (var i = 0; i < 18; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final speed = 0.15 + rnd.nextDouble() * 0.25;
      final p = c + Offset(math.cos(a), math.sin(a) - 0.4) * maxR * speed * Curves.easeOut.transform(t);
      final r = maxR * (0.08 + rnd.nextDouble() * 0.08) * (0.4 + t);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Color.fromRGBO(60, 50, 45, 0.35 * (1 - t * 0.6) * (t * 4).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
      );
    }

    // 불덩이
    final fb = Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    final fade = (1 - (t - 0.25) / 0.5).clamp(0.0, 1.0);
    if (fade > 0) {
      final r = maxR * 0.55 * fb + 1;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 255, 220, fade),
              Color.fromRGBO(255, 210, 60, fade),
              Color.fromRGBO(255, 100, 20, fade * 0.9),
              Color.fromRGBO(180, 30, 0, 0),
            ],
            stops: const [0.0, 0.25, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // 충격파 링
    final ring = (t / 0.45).clamp(0.0, 1.0);
    if (ring < 1) {
      canvas.drawCircle(
        c,
        maxR * 0.9 * Curves.easeOut.transform(ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18 * (1 - ring)
          ..color = Color.fromRGBO(255, 230, 180, 0.6 * (1 - ring)),
      );
    }

    // 파편
    final debris = Paint();
    for (var i = 0; i < 40; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final speed = 0.3 + rnd.nextDouble() * 0.6;
      final dist = maxR * speed * Curves.easeOutCubic.transform(t);
      final gravity = maxR * 0.25 * t * t;
      final p = c + Offset(math.cos(a) * dist, math.sin(a) * dist + gravity);
      final life = (1 - t * (0.8 + rnd.nextDouble() * 0.6)).clamp(0.0, 1.0);
      debris.color = (i.isEven ? const Color(0xFFFFC040) : const Color(0xFF2A2A2E)).withValues(alpha: life);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t * 10 * (rnd.nextDouble() - 0.5));
      final s = 4 + rnd.nextDouble() * 10;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.6), debris);
      canvas.restore();
    }

    // 하얀 섬광
    final flash = (1 - t / 0.12).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: flash));
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter old) => old.t != t;
}
