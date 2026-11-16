import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 클래식 폭탄 + 7세그먼트 표시창 + 타들어가는 심지.
///
/// 좌표는 정사각형 캔버스 기준 0~1 단위로 잡고 크기에 맞춰 늘립니다.
class BombPainter extends CustomPainter {
  BombPainter({
    required this.remaining,
    required this.fuseFraction,
    required this.lit,
    required this.colonOn,
    required this.flicker,
    required this.danger,
  });

  /// 남은 시간 (표시창에 그림).
  final Duration remaining;

  /// 남은 심지 비율 (1 = 처음 길이, 0 = 다 탐).
  final double fuseFraction;

  /// 불꽃이 붙어 있는지 (작동 중).
  final bool lit;

  /// 콜론(:) 표시 여부 (작동 중 깜빡임).
  final bool colonOn;

  /// 불꽃 흔들림용 0~1 값 (애니메이션).
  final double flicker;

  /// 마지막 10초 — 표시창이 더 밝게 빛남.
  final bool danger;

  static const _bodyC = Offset(0.44, 0.60);
  static const _bodyR = 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);

    final c = _bodyC;
    const r = _bodyR;

    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.97), width: r * 1.9, height: r * 0.28),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02),
    );

    // 금속 마개 (오른쪽 위 45도) — 몸통보다 먼저 그려서 아래쪽이 가려지게
    const ang = -math.pi / 4;
    final u = Offset(math.cos(ang), math.sin(ang));
    final v = Offset(-u.dy, u.dx);
    const base = r * 0.86;
    const capH = 0.11;
    const capW = 0.095;
    Path quad(double d0, double d1, double half) {
      final b0 = c + u * d0;
      final b1 = c + u * d1;
      return Path()
        ..moveTo((b0 - v * half).dx, (b0 - v * half).dy)
        ..lineTo((b0 + v * half).dx, (b0 + v * half).dy)
        ..lineTo((b1 + v * half).dx, (b1 + v * half).dy)
        ..lineTo((b1 - v * half).dx, (b1 - v * half).dy)
        ..close();
    }

    canvas.drawPath(quad(base - 0.03, base + capH, capW), Paint()..color = const Color(0xFF464A52));
    canvas.drawPath(quad(base - 0.03, base + capH, capW * 0.55), Paint()..color = const Color(0xFF969CA8));
    canvas.drawPath(quad(base - 0.03, base + capH, capW * 0.18), Paint()..color = const Color(0xFFCDD2DC));
    canvas.drawPath(quad(base + capH - 0.018, base + capH, capW), Paint()..color = const Color(0xFF282A30));

    // 몸통
    final bodyRect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.38, -r * 0.38),
          r * 1.55,
          const [Color(0xFF6E7480), Color(0xFF26282E), Color(0xFF060609)],
          const [0.0, 0.45, 1.0],
        ),
    );
    // 가장자리 반사광 (오른쪽 아래)
    canvas.drawArc(
      bodyRect.deflate(0.006),
      0.15,
      1.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.008
        ..color = const Color(0x334A6080)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.004),
    );
    // 하이라이트
    canvas.save();
    final h = c + Offset(-r * 0.42, -r * 0.42);
    canvas.translate(h.dx, h.dy);
    canvas.rotate(-math.pi / 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.52, height: r * 0.26),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.008),
    );
    canvas.restore();

    _paintDisplay(canvas, c);
    _paintFuse(canvas, c + u * (base + capH));

    canvas.restore();
  }

  // ───────────────── 심지 ─────────────────
  void _paintFuse(Canvas canvas, Offset start) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(0.70, 0.17, 0.87, 0.30, 0.87, 0.13);
    final metric = path.computeMetrics().first;
    final len = metric.length * fuseFraction.clamp(0.0, 1.0);

    // 다 타버린 자리: 희미한 그을음
    canvas.drawPath(
      metric.extractPath(len, metric.length),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.006
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    if (len > 0.0005) {
      final fuse = metric.extractPath(0, len);
      canvas.drawPath(
        fuse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.034
          ..color = const Color(0xFF462D14),
      );
      canvas.drawPath(
        fuse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.024
          ..color = const Color(0xFFC89655),
      );
      // 꼬임 무늬
      final twist = Paint()
        ..strokeWidth = 0.005
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF785028);
      for (double d = 0.012; d < len - 0.006; d += 0.018) {
        final t = metric.getTangentForOffset(d)!;
        final n = Offset(-t.vector.dy, t.vector.dx);
        canvas.drawLine(
          t.position - n * 0.010 - t.vector * 0.006,
          t.position + n * 0.010 + t.vector * 0.006,
          twist,
        );
      }
    }

    final tip = metric.getTangentForOffset(math.max(len, 0.0))!.position;
    if (lit) {
      _paintSpark(canvas, tip);
    } else {
      // 불 꺼진 심지 끝
      canvas.drawCircle(tip, 0.013, Paint()..color = const Color(0xFF2A1A0C));
    }
  }

  void _paintSpark(Canvas canvas, Offset p) {
    final f = flicker;
    final pulse = 0.85 + 0.25 * math.sin(f * math.pi * 2 * 3);
    canvas.drawCircle(
      p,
      0.10 * pulse,
      Paint()
        ..color = const Color(0xFFFF8C00).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.035),
    );

    Path star(double rOut, double rIn, int n, double rot) {
      final path = Path();
      for (var i = 0; i < n * 2; i++) {
        final rr = i.isEven ? rOut : rIn;
        final a = rot + math.pi * i / n;
        final pt = p + Offset(math.cos(a), math.sin(a)) * rr;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path..close();
    }

    final rot = f * math.pi * 2;
    canvas.drawPath(star(0.085 * pulse, 0.035, 10, rot), Paint()..color = const Color(0xFFFF5A14));
    canvas.drawPath(star(0.065 * pulse, 0.028, 10, -rot * 1.3 + 0.4), Paint()..color = const Color(0xFFFFC800));
    canvas.drawPath(star(0.035, 0.018, 8, rot * 2), Paint()..color = const Color(0xFFFFFAD2));

    // 튀는 불똥
    final rnd = math.Random((f * 1000).floor());
    final dot = Paint()..color = const Color(0xFFFFDC50);
    for (var i = 0; i < 9; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = 0.07 + rnd.nextDouble() * 0.08;
      canvas.drawCircle(p + Offset(math.cos(a), math.sin(a)) * d, 0.004 + rnd.nextDouble() * 0.005, dot);
    }
  }

  // ───────────────── 7세그먼트 표시창 ─────────────────
  void _paintDisplay(Canvas canvas, Offset c) {
    final panel = Rect.fromCenter(center: c + const Offset(0, 0.035), width: 0.40, height: 0.15);
    final rr = RRect.fromRectAndRadius(panel, const Radius.circular(0.015));

    // 금속 테두리 + 나사
    canvas.drawRRect(
      rr.inflate(0.012),
      Paint()
        ..shader = ui.Gradient.linear(
          panel.topLeft,
          panel.bottomRight,
          const [Color(0xFF9AA0AA), Color(0xFF3C4048), Color(0xFF7A808A)],
          const [0.0, 0.55, 1.0],
        ),
    );
    final screw = Paint()..color = const Color(0xFF2A2C32);
    for (final o in [
      panel.topLeft + const Offset(-0.004, -0.004),
      panel.topRight + const Offset(0.004, -0.004),
      panel.bottomLeft + const Offset(-0.004, 0.004),
      panel.bottomRight + const Offset(0.004, 0.004),
    ]) {
      canvas.drawCircle(o, 0.004, screw);
    }
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF120404));

    final total = remaining.inSeconds;
    final mm = (total ~/ 60).clamp(0, 99);
    final ss = total % 60;
    final digits = [mm ~/ 10, mm % 10, ss ~/ 10, ss % 10];

    final on = danger ? const Color(0xFFFF2A1A) : const Color(0xFFFF3B2A);
    final off = const Color(0xFF3A0D0A);
    final glow = Paint()
      ..color = on.withValues(alpha: danger ? 0.9 : 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, danger ? 0.009 : 0.006);
    final onPaint = Paint()..color = on;
    final offPaint = Paint()..color = off;

    const dw = 0.066; // 숫자 너비
    const dh = 0.11; // 숫자 높이
    const gap = 0.016;
    const colonW = 0.026;
    final totalW = dw * 4 + gap * 3 + colonW;
    var x = panel.center.dx - totalW / 2;
    final y = panel.center.dy - dh / 2;

    for (var i = 0; i < 4; i++) {
      _digit(canvas, Offset(x, y), dw, dh, digits[i], onPaint, offPaint, glow);
      x += dw + gap;
      if (i == 1) {
        final cx = x - gap / 2 + colonW / 2 - gap / 2;
        for (final cy in [y + dh * 0.32, y + dh * 0.68]) {
          final dot = Rect.fromCenter(center: Offset(cx, cy), width: 0.011, height: 0.011);
          if (colonOn) {
            canvas.drawRect(dot, glow);
            canvas.drawRect(dot, onPaint);
          } else {
            canvas.drawRect(dot, offPaint);
          }
        }
        x += colonW;
      }
    }
  }

  //  aaa
  // f   b
  //  ggg
  // e   c
  //  ddd
  static const _segs = <int, String>{
    0: 'abcdef',
    1: 'bc',
    2: 'abged',
    3: 'abgcd',
    4: 'fgbc',
    5: 'afgcd',
    6: 'afgedc',
    7: 'abc',
    8: 'abcdefg',
    9: 'abcdfg',
  };

  void _digit(Canvas canvas, Offset o, double w, double h, int n, Paint onP, Paint offP, Paint glow) {
    final t = w * 0.2; // 세그먼트 두께
    final half = h / 2;
    const slant = 0.008; // 살짝 기울임
    Path seg(Offset a, Offset b, bool horizontal) {
      final d = t / 2;
      final path = Path();
      if (horizontal) {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx + d, a.dy - d)
          ..lineTo(b.dx - d, b.dy - d)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx - d, b.dy + d)
          ..lineTo(a.dx + d, a.dy + d);
      } else {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx + d, a.dy + d)
          ..lineTo(b.dx + d, b.dy - d)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx - d, b.dy - d)
          ..lineTo(a.dx - d, a.dy + d);
      }
      return path..close();
    }

    Offset k(double x, double y) => Offset(o.dx + x + (1 - y / h) * slant, o.dy + y);
    final g = t * 0.12; // 세그먼트 사이 틈
    final paths = <String, Path>{
      'a': seg(k(t / 2 + g, 0), k(w - t / 2 - g, 0), true),
      'g': seg(k(t / 2 + g, half), k(w - t / 2 - g, half), true),
      'd': seg(k(t / 2 + g, h), k(w - t / 2 - g, h), true),
      'f': seg(k(t / 2, g), k(t / 2, half - g), false),
      'b': seg(k(w - t / 2, g), k(w - t / 2, half - g), false),
      'e': seg(k(t / 2, half + g), k(t / 2, h - g), false),
      'c': seg(k(w - t / 2, half + g), k(w - t / 2, h - g), false),
    };
    final lit = _segs[n]!;
    paths.forEach((name, p) {
      if (lit.contains(name)) {
        canvas.drawPath(p, glow);
        canvas.drawPath(p, onP);
      } else {
        canvas.drawPath(p, offP);
      }
    });
  }

  @override
  bool shouldRepaint(BombPainter old) =>
      old.remaining.inSeconds != remaining.inSeconds ||
      old.fuseFraction != fuseFraction ||
      old.lit != lit ||
      old.colonOn != colonOn ||
      old.flicker != flicker ||
      old.danger != danger;
}
