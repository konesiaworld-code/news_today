import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'alarm.dart';
import 'bomb_painter.dart';
import 'explosion.dart';

/// 타이머 길이: 1시간.
const kTotal = Duration(hours: 1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Alarm.init();
  runApp(const BombTimerApp());
}

class BombTimerApp extends StatelessWidget {
  const BombTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '때지의 스탑워치',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE8601A),
        useMaterial3: true,
      ),
      home: const BombTimerPage(),
    );
  }
}

enum Phase { idle, running, paused, exploded }

class BombTimerPage extends StatefulWidget {
  const BombTimerPage({super.key});

  @override
  State<BombTimerPage> createState() => _BombTimerPageState();
}

class _BombTimerPageState extends State<BombTimerPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  Phase _phase = Phase.idle;
  DateTime? _endAt; // 작동 중일 때 폭발 시각
  Duration _left = kTotal; // 멈춰 있을 때 남은 시간

  late final Ticker _ticker;
  late final AnimationController _boom;
  double _flicker = 0;
  int _lastSecond = -1;

  final _tick = AudioPlayer();
  final _boomSound = AudioPlayer();
  SharedPreferences? _prefs;

  Duration get _remaining {
    if (_phase == Phase.running && _endAt != null) {
      final d = _endAt!.difference(DateTime.now());
      return d.isNegative ? Duration.zero : d;
    }
    if (_phase == Phase.exploded) return Duration.zero;
    return _left;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _boom = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _tick.setPlayerMode(PlayerMode.lowLatency);
    _tick.setReleaseMode(ReleaseMode.stop);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _boom.dispose();
    _tick.dispose();
    _boomSound.dispose();
    super.dispose();
  }

  // ───────────── 저장/복원 (앱을 껐다 켜도 이어서) ─────────────
  Future<void> _restore() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final phase = p.getString('phase');
    if (phase == 'running') {
      final end = DateTime.fromMillisecondsSinceEpoch(p.getInt('endAt') ?? 0);
      if (end.isAfter(DateTime.now())) {
        _endAt = end;
        _setPhase(Phase.running, save: false);
      } else {
        // 앱이 꺼져 있는 동안 이미 터짐
        _setPhase(Phase.exploded, save: false);
        _boom.value = 1;
      }
    } else if (phase == 'paused') {
      _left = Duration(milliseconds: p.getInt('leftMs') ?? kTotal.inMilliseconds);
      _setPhase(Phase.paused, save: false);
    } else if (phase == 'exploded') {
      _boom.value = 1;
      _setPhase(Phase.exploded, save: false);
    }
    await Alarm.cancel();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('phase', _phase.name);
    if (_endAt != null) p.setInt('endAt', _endAt!.millisecondsSinceEpoch);
    p.setInt('leftMs', _left.inMilliseconds);
  }

  // ───────────── 상태 전환 ─────────────
  void _setPhase(Phase phase, {bool save = true}) {
    setState(() => _phase = phase);
    if (phase == Phase.running) {
      if (!_ticker.isActive) _ticker.start();
      WakelockPlus.enable();
    } else {
      if (_ticker.isActive) _ticker.stop();
      WakelockPlus.disable();
    }
    if (save) _save();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    Alarm.requestPermission();
    _endAt = DateTime.now().add(_left);
    _lastSecond = -1;
    _setPhase(Phase.running);
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _left = _remaining;
    _endAt = null;
    _setPhase(Phase.paused);
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _left = kTotal;
    _endAt = null;
    _boom.reset();
    _boomSound.stop();
    _setPhase(Phase.idle);
    Alarm.cancel();
  }

  void _toggle() {
    switch (_phase) {
      case Phase.running:
        _pause();
      case Phase.idle:
      case Phase.paused:
        _start();
      case Phase.exploded:
        _reset();
    }
  }

  Future<void> _explode() async {
    _endAt = null;
    _left = Duration.zero;
    _setPhase(Phase.exploded);
    _boom.forward(from: 0);
    _boomSound.play(AssetSource('sounds/boom.wav'));
    for (var i = 0; i < 6; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 120));
    }
    HapticFeedback.vibrate();
  }

  void _onTick(Duration elapsed) {
    final left = _remaining;
    if (left == Duration.zero) {
      _explode();
      return;
    }
    // 마지막 10초는 째깍 소리
    final sec = (left.inMilliseconds / 1000).ceil();
    if (sec != _lastSecond) {
      _lastSecond = sec;
      if (sec <= 10) {
        _tick.stop().then((_) => _tick.play(AssetSource('sounds/tick.wav')));
        HapticFeedback.selectionClick();
      }
    }
    setState(() => _flicker = (elapsed.inMilliseconds % 1000) / 1000);
  }

  // 앱이 뒤로 가면 시스템 알림을 예약, 다시 오면 취소
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_phase == Phase.running && _endAt != null) Alarm.schedule(_endAt!);
    } else if (state == AppLifecycleState.resumed) {
      Alarm.cancel();
      if (_phase == Phase.running && _remaining == Duration.zero) _explode();
    }
  }

  // ───────────── 화면 ─────────────
  @override
  Widget build(BuildContext context) {
    final left = _remaining;
    final danger = _phase == Phase.running && left.inSeconds < 10;
    final ms = left.inMilliseconds;
    // 콜론은 작동 중에 0.5초마다 깜빡
    final colonOn = _phase != Phase.running || (ms % 1000) >= 500;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _boom,
        builder: (context, _) {
          final shake = _shakeOffset(danger, _boom.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // 배경
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 1.1,
                    colors: danger
                        ? [Color.lerp(const Color(0xFF3A1A1A), const Color(0xFF6A1010), _flicker)!, const Color(0xFF100606)]
                        : const [Color(0xFF2C2F38), Color(0xFF0E0F13)],
                  ),
                ),
              ),
              SafeArea(
                child: Transform.translate(
                  offset: shake,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text('때지의 스탑워치',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: const Color(0xFFFFB347),
                              )),
                      const SizedBox(height: 4),
                      Text('1 HOUR', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), letterSpacing: 6)),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: GestureDetector(
                                onTap: _toggle,
                                child: _phase == Phase.exploded
                                    ? const SizedBox.shrink()
                                    : CustomPaint(
                                        painter: BombPainter(
                                          remaining: left,
                                          fuseFraction: ms / kTotal.inMilliseconds,
                                          lit: _phase == Phase.running,
                                          colonOn: colonOn,
                                          flicker: _flicker,
                                          danger: danger,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        switch (_phase) {
                          Phase.idle => '폭탄을 탭하거나 점화 버튼을 누르세요',
                          Phase.running => danger ? '피하세요!!' : '심지가 타들어가는 중…',
                          Phase.paused => '일시정지 — 불이 꺼졌어요',
                          Phase.exploded => '',
                        },
                        style: TextStyle(
                          color: danger ? const Color(0xFFFF5A3C) : Colors.white.withValues(alpha: 0.6),
                          fontWeight: danger ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _controls(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (_phase == Phase.exploded || _boom.value > 0)
                Explosion(progress: _boom.value, onRestart: _reset),
            ],
          );
        },
      ),
    );
  }

  Offset _shakeOffset(bool danger, double boom) {
    final rnd = math.Random();
    if (boom > 0 && boom < 0.35) {
      final a = 18 * (1 - boom / 0.35);
      return Offset((rnd.nextDouble() - 0.5) * a, (rnd.nextDouble() - 0.5) * a);
    }
    if (danger) return Offset((rnd.nextDouble() - 0.5) * 3, (rnd.nextDouble() - 0.5) * 3);
    return Offset.zero;
  }

  Widget _controls() {
    final running = _phase == Phase.running;
    final mainLabel = switch (_phase) {
      Phase.running => '일시정지',
      Phase.paused => '다시 점화',
      _ => '점화',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.replay_rounded,
          label: '리셋',
          size: 64,
          color: const Color(0xFF3A3D46),
          onTap: _phase == Phase.idle ? null : _reset,
        ),
        const SizedBox(width: 36),
        _RoundButton(
          icon: running ? Icons.pause_rounded : Icons.local_fire_department_rounded,
          label: mainLabel,
          size: 88,
          color: running ? const Color(0xFF5A5F6B) : const Color(0xFFE8501A),
          onTap: _phase == Phase.exploded ? null : _toggle,
        ),
        const SizedBox(width: 36 + 64),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            elevation: enabled ? 6 : 0,
            shadowColor: color,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: size * 0.48, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
        ],
      ),
    );
  }
}
