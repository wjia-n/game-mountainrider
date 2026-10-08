import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class _Pickup {
  double x; // world x
  double yOff;
  bool taken = false;
  final bool fuel;
  _Pickup(this.x, this.yOff, this.fuel);
}

class MountainRiderScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const MountainRiderScreen({super.key, required this.players, required this.callbacks});

  @override
  State<MountainRiderScreen> createState() => _MountainRiderScreenState();
}

class _MountainRiderScreenState extends State<MountainRiderScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _x = 0; // world distance travelled
  double _v = 0; // forward speed
  double _y = 0; // height above terrain (0 = grounded)
  double _vy = 0;
  double _angle = 0; // jeep tilt radians
  double _fuel = 100;
  int _coins = 0;
  bool _throttle = false;
  bool _brake = false;
  bool _over = false;
  bool _started = false;
  double _wheelSpin = 0;
  double? _best;
  final _pickups = <_Pickup>[];
  double _nextPickupX = 500;
  final _rand = math.Random();

  double _terrain(double wx) {
    final grow = math.min(2.2, 1 + wx / 9000);
    return (math.sin(wx * 0.004) * 90 +
            math.sin(wx * 0.011 + 1.7) * 46 +
            math.sin(wx * 0.023 + 0.5) * 22) *
        grow;
  }

  double _slope(double wx) => (_terrain(wx + 8) - _terrain(wx - 8)) / 16;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _loadBest();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = p.getDouble('rider_best'));
  }

  void _tick(Duration _) {
    if (_over || !_started) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    const dt = 1 / 60;
    setState(() {
      // drive
      if (_throttle && _fuel > 0) {
        _v = math.min(430, _v + 170 * dt);
        _fuel = math.max(0, _fuel - 3.2 * dt);
      }
      if (_brake) _v = math.max(0, _v - 260 * dt);
      _v = math.max(0, _v - 14 * dt); // rolling drag
      _x += _v * dt;
      _wheelSpin += _v * dt * 0.05;

      final ty = _terrain(_x);
      final grounded = _y <= 0.5;

      if (grounded) {
        _y = 0;
        _vy = 0;
        // leaving the ground off a crest?
        final ahead = _terrain(_x + _v * dt * 2);
        if (ahead < ty - 6 && _v > 200) {
          _vy = (_v * _slope(_x)).clamp(-260, 60);
          _y = 1;
        }
        // jeep follows slope
        final want = math.atan(_slope(_x)) * 0.9;
        _angle += (want - _angle) * math.min(1, 10 * dt);
        if (_v < 4 && _fuel <= 0) {
          _gameOver('Out of fuel!');
          return;
        }
      } else {
        // airborne
        _vy -= 900 * dt;
        _y += _vy * dt;
        if (_throttle) _angle -= 1.6 * dt; // tip back
        if (_brake) _angle += 1.9 * dt; // tip forward
        if (_y <= 0 && _vy < 0) {
          _y = 0;
          // landing check
          final norm = _angle % (math.pi * 2);
          final deg = (norm > math.pi ? norm - 2 * math.pi : norm).abs();
          if (deg > 1.25) {
            _gameOver('Landed on your roof! 🤕');
            return;
          }
          if (_vy < -560) {
            _gameOver('What a landing… not. 💥');
            return;
          }
          _vy = 0;
          Sfx.tap();
        }
      }

      // pickups spawn ahead
      while (_nextPickupX < _x + 1600) {
        final fuel = _rand.nextDouble() < 0.3;
        _pickups.add(_Pickup(_nextPickupX, fuel ? 70 : 46, fuel));
        _nextPickupX += 380 + _rand.nextDouble() * 520;
      }
      for (final pk in _pickups) {
        if (!pk.taken && (pk.x - _x).abs() < 34 && _y < 120) {
          pk.taken = true;
          if (pk.fuel) {
            _fuel = math.min(100, _fuel + 32);
            Sfx.click();
          } else {
            _coins++;
            Sfx.tap();
          }
        }
      }
      _pickups.removeWhere((p) => p.taken || p.x < _x - 300);
    });
  }

  Future<void> _gameOver(String reason) async {
    _over = true;
    _ticker.stop();
    Sfx.lose();
    final dist = _x / 50;
    final p = await SharedPreferences.getInstance();
    final prev = p.getDouble('rider_best') ?? 0;
    final isBest = dist > prev;
    if (isBest) await p.setDouble('rider_best', dist);
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'You rode ${dist.toStringAsFixed(0)} m! $reason',
      subline: '🪙 $_coins coins'
          '${isBest ? ' · NEW BEST! 🏆' : ' · Best: ${prev.toStringAsFixed(0)} m'}',
    );
  }

  void _setPedal(Offset at, Size s, bool down) {
    setState(() {
      _started = true;
      if (at.dx < s.width / 2) {
        _brake = down;
      } else {
        _throttle = down;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📏 ${(_x / 50).toStringAsFixed(0)} m',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              Text('🪙 $_coins',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              if (_best != null && _best! > 0)
                Text('🏆 ${_best!.toStringAsFixed(0)} m',
                    style: TextStyle(color: theme.muted)),
              SizedBox(
                width: 110,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_fuel / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: theme.muted.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(
                        _fuel > 25 ? theme.accent : const Color(0xFFE4572E)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final s = Size(c.maxWidth, c.maxHeight);
              return Listener(
                onPointerDown: (e) => _setPedal(e.localPosition, s, true),
                onPointerMove: (e) => _setPedal(e.localPosition, s, true),
                onPointerUp: (e) {
                  setState(() {
                    _brake = false;
                    _throttle = false;
                  });
                },
                onPointerCancel: (e) {
                  setState(() {
                    _brake = false;
                    _throttle = false;
                  });
                },
                child: CustomPaint(
                  size: s,
                  painter: _RiderPainter(
                    x: _x,
                    y: _y,
                    angle: _angle,
                    wheelSpin: _wheelSpin,
                    pickups: _pickups,
                    terrain: _terrain,
                    throttle: _throttle,
                    brake: _brake,
                    started: _started,
                    theme: theme,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pedal(theme, '🛑 BRAKE', _brake),
              _pedal(theme, '🚀 GAS', _throttle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pedal(GameTheme theme, String label, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        color: on ? theme.primary : theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primary, width: 2),
      ),
      child: Text(label,
          style: TextStyle(
              color: on ? theme.text : theme.primary, fontWeight: FontWeight.bold)),
    );
  }
}

class _RiderPainter extends CustomPainter {
  final double x, y, angle, wheelSpin;
  final List<_Pickup> pickups;
  final double Function(double) terrain;
  final bool throttle, brake, started;
  final GameTheme theme;

  _RiderPainter({
    required this.x,
    required this.y,
    required this.angle,
    required this.wheelSpin,
    required this.pickups,
    required this.terrain,
    required this.throttle,
    required this.brake,
    required this.started,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // sky
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        sky,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.background, theme.surface],
          ).createShader(sky));
    // sun
    canvas.drawCircle(Offset(size.width - 70, 70), 30,
        Paint()..color = theme.accent.withValues(alpha: 0.85));
    // parallax far hills
    _hills(canvas, size, 0.3, theme.muted.withValues(alpha: 0.25), 130);
    _hills(canvas, size, 0.55, theme.muted.withValues(alpha: 0.35), 170);

    final baseY = size.height * 0.62;
    final jeepX = size.width * 0.35;

    // terrain path
    final path = Path()..moveTo(-10, size.height + 10);
    for (var sx = -10.0; sx <= size.width + 10; sx += 8) {
      final wx = x + (sx - jeepX);
      path.lineTo(sx, baseY - terrain(wx) * 0.5);
    }
    path.lineTo(size.width + 10, size.height + 10);
    path.close();
    canvas.drawPath(path, Paint()..color = theme.primary.withValues(alpha: 0.55));
    canvas.drawPath(
        _ridge(size, baseY, jeepX),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = theme.primary);

    // pickups
    for (final pk in pickups) {
      final sx = jeepX + (pk.x - x);
      if (sx < -30 || sx > size.width + 30) continue;
      final sy = baseY - terrain(pk.x) * 0.5 - pk.yOff;
      if (pk.fuel) {
        _emoji(canvas, '🛢️', Offset(sx, sy), 26);
      } else {
        canvas.drawCircle(Offset(sx, sy), 11, Paint()..color = const Color(0xFFFFC93C));
        canvas.drawCircle(Offset(sx - 3, sy - 3), 3.5, Paint()..color = const Color(0xFFFFF3C4));
      }
    }

    // jeep
    final jy = baseY - terrain(x) * 0.5 - y * 0.5;
    canvas.save();
    canvas.translate(jeepX, jy);
    canvas.rotate(angle);
    final body = Paint()..color = const Color(0xFFE4572E);
    // chassis
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-34, -30, 68, 20), const Radius.circular(6)),
        body);
    // cabin
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -46, 30, 20), const Radius.circular(5)),
        Paint()..color = theme.secondary);
    // wheels
    for (final wx in [-22.0, 22.0]) {
      canvas.drawCircle(Offset(wx, -6), 13, Paint()..color = const Color(0xFF222222));
      canvas.save();
      canvas.translate(wx, -6);
      canvas.rotate(wheelSpin);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(Offset.zero,
            Offset(9 * math.cos(i * 2.09), 9 * math.sin(i * 2.09)),
            Paint()
              ..strokeWidth = 3
              ..color = theme.muted);
      }
      canvas.restore();
      canvas.drawCircle(Offset(wx, -6), 4, Paint()..color = theme.text);
    }
    // exhaust flame when throttling
    if (throttle) {
      canvas.drawCircle(const Offset(-40, -18), 7 + 3 * math.sin(wheelSpin * 3),
          Paint()..color = theme.accent.withValues(alpha: 0.8));
    }
    canvas.restore();

    if (!started) {
      _emoji(canvas, '👆', Offset(size.width / 2, size.height * 0.3), 40);
    }
  }

  void _hills(Canvas canvas, Size size, double par, Color col, double h) {
    final p = Path()..moveTo(-10, size.height);
    for (var sx = -10.0; sx <= size.width + 10; sx += 20) {
      final wx = x * par + sx;
      p.lineTo(sx, size.height * 0.62 - (math.sin(wx * 0.003) * h * 0.5 + h * 0.5));
    }
    p.lineTo(size.width + 10, size.height);
    p.close();
    canvas.drawPath(p, Paint()..color = col);
  }

  Path _ridge(Size size, double baseY, double jeepX) {
    final p = Path();
    var first = true;
    for (var sx = -10.0; sx <= size.width + 10; sx += 8) {
      final wx = x + (sx - jeepX);
      final sy = baseY - terrain(wx) * 0.5;
      if (first) {
        p.moveTo(sx, sy);
        first = false;
      } else {
        p.lineTo(sx, sy);
      }
    }
    return p;
  }

  void _emoji(Canvas canvas, String e, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(text: e, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RiderPainter old) => true;
}
