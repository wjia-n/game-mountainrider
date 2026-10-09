import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/rider_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/rider_themes.dart';
import 'widgets.dart';

/// Engine-driven ride screen. The [RiderEngine] owns ALL phase state; this
/// widget observes it, forwards pedal input, and turns fx events into
/// sounds, particles and banners.
class GameScreen extends StatefulWidget {
  final RiderAudio audio;
  final RiderSettings settings;
  final RideTier tier;
  final PlayMode mode;
  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.tier,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _Particle {
  double x, y, vx, vy, life, size;
  Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color);
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late RiderEngine _engine;
  StreamSubscription<RiderFx>? _fxSub;
  final List<_Particle> _particles = [];
  final List<String> _banners = [];
  Timer? _bannerTimer;
  int _countdownNum = 0;
  bool _dialogShown = false;
  bool _pauseDialogOpen = false;
  final _rand = math.Random();

  RiderThemeDef get _t => RiderThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );
  RiderStyleDef get _style => RiderStyles.byId(widget.settings.styleId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = RiderEngine(vsync: this, tier: widget.tier, mode: widget.mode);
    _fxSub = _engine.fx.listen(_onFx);
    _engine.addListener(_onEngine);
    widget.audio.startGameMusic();
    _engine.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine when the app is interrupted — never lose the ride.
    // On return, offer the pause dialog so the ride can always be resumed:
    // a paused engine with no dialog would be a stuck state.
    if (state == AppLifecycleState.paused) {
      _engine.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_engine.phase == RidePhase.paused &&
          !_pauseDialogOpen &&
          !_dialogShown &&
          mounted) {
        _showPause(_t);
      }
    }
  }

  void _onEngine() {
    if (!mounted) return;
    if (_engine.phase == RidePhase.finished && !_dialogShown) {
      _dialogShown = true;
      _onFinished();
    }
    setState(() {}); // repaint: engine state changed
  }

  void _onFx(RiderFx fx) {
    final a = widget.audio;
    switch (fx.kind) {
      case RiderFxKind.count:
        _countdownNum = fx.value.toInt();
        a.countBeep();
        setState(() {});
      case RiderFxKind.go:
        _countdownNum = 0;
        a.go();
        _banner('GO! 🚵');
      case RiderFxKind.coin:
        a.coin();
        _burst(8, const Color(0xFFFFC93C));
      case RiderFxKind.water:
        a.water();
        _banner(fx.text);
      case RiderFxKind.jump:
        a.jump();
      case RiderFxKind.landSoft:
        a.land();
        _burst(10, const Color(0xFFB98A56));
      case RiderFxKind.landWobbly:
        a.land();
        _banner(fx.text);
        _burst(12, const Color(0xFFB98A56));
      case RiderFxKind.bigAir:
        a.bigAir();
        _banner(fx.text);
      case RiderFxKind.crash:
        a.crash();
        _burst(24, const Color(0xFF8B8B8B));
      case RiderFxKind.pedal:
        a.pedal();
      case RiderFxKind.finish:
        break; // handled by phase listener
    }
  }

  void _burst(int n, Color color) {
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(
        0.35, // relative to rider x (painter offsets by rider pos)
        0,
        (_rand.nextDouble() - 0.5) * 320,
        -_rand.nextDouble() * 260 - 40,
        0.7 + _rand.nextDouble() * 0.4,
        3 + _rand.nextDouble() * 4,
        color,
      ));
    }
  }

  void _banner(String text) {
    if (text.isEmpty) return;
    _banners.add(text);
    if (_banners.length > 3) _banners.removeAt(0);
    setState(() {});
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        if (_banners.isNotEmpty) _banners.removeAt(0);
      });
    });
  }

  Future<void> _onFinished() async {
    final e = _engine;
    final dist = e.distanceM();
    final score = e.score().toDouble();
    final isBest = await widget.settings.recordRide(
      tier: widget.tier.name,
      mode: widget.mode.name,
      score: widget.mode == PlayMode.endless ? dist : score,
      coins: e.coins,
    );
    if (isBest) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    widget.audio.startMenuMusic();
    if (!mounted) return;
    _maybeReview(isBest);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FinishDialog(
        theme: _t,
        audio: widget.audio,
        settings: widget.settings,
        reason: e.finishReason,
        distanceM: dist,
        coins: e.coins,
        score: e.score(),
        isBest: isBest,
        mode: widget.mode,
        onRetry: () {
          Navigator.of(context).pop();
          setState(() {
            _dialogShown = false;
            _particles.clear();
            _banners.clear();
          });
          widget.audio.startGameMusic();
          _engine.restart();
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Ask for a Play review at a sensible moment: a new best, a few rides in,
  /// at most once a week. Graceful when not installed from Play.
  Future<void> _maybeReview(bool isBest) async {
    if (!isBest) return;
    final s = widget.settings;
    if (s.rides < 3) return;
    final week = 7 * 24 * 3600 * 1000;
    if (DateTime.now().millisecondsSinceEpoch - s.lastReviewPrompt < week) {
      return;
    }
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await s.markReviewPrompted();
        await review.requestReview();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _fxSub?.cancel();
    _engine.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  void _setPedals(Offset at, Size s, bool down) {
    final pedal = at.dx >= s.width / 2;
    if (down) {
      // first touch starts the ride feel immediately
      _engine.setPedals(pedal: pedal, brake: !pedal);
      setState(() {});
    } else {
      _engine.setPedals(pedal: false, brake: false);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _engine;
    return Scaffold(
      backgroundColor: t.skyTop,
      body: SafeArea(
        child: Column(
          children: [
            _hud(t, e),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final s = Size(c.maxWidth, c.maxHeight);
                  return Listener(
                    onPointerDown: (ev) => _setPedals(ev.localPosition, s, true),
                    onPointerMove: (ev) {
                      if (ev.buttons != 0) {
                        _setPedals(ev.localPosition, s, true);
                      }
                    },
                    onPointerUp: (ev) => _setPedals(ev.localPosition, s, false),
                    onPointerCancel: (ev) =>
                        _setPedals(ev.localPosition, s, false),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: s,
                          painter: _RidePainter(
                            engine: e,
                            theme: t,
                            style: _style,
                            particles: _particles,
                            randSeed: 42,
                          ),
                        ),
                        if (_countdownNum > 0)
                          Center(
                            child: Text(
                              '$_countdownNum',
                              style: TextStyle(
                                fontSize: 110,
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withValues(alpha: 0.95),
                                shadows: const [
                                  Shadow(
                                      offset: Offset(0, 6),
                                      blurRadius: 12,
                                      color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                        if (_banners.isNotEmpty)
                          Positioned(
                            top: 14,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                for (final b in _banners)
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: t.text.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: t.accent, width: 2),
                                    ),
                                    child: Text(
                                      b,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _pedals(t, e),
          ],
        ),
      ),
    );
  }

  Widget _hud(RiderThemeDef t, RiderEngine e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.panel.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: t.accent, width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.pause, color: t.text),
            tooltip: 'Pause',
            onPressed: () {
              widget.audio.click();
              e.pause();
              _showPause(t);
            },
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _hudStat(t, '📏', '${e.distanceM().toStringAsFixed(0)} m'),
                _hudStat(t, '🪙', '${e.coins}'),
                _hudStat(t, '⚡', '${e.score()}'),
                if (widget.mode == PlayMode.scoreAttack)
                  _hudStat(t, '⏱️', '${e.timeLeft.ceil()}s'),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STAMINA',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: t.muted,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (e.stamina / 100).clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: t.muted.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(
                        e.stamina > 25 ? t.accent : const Color(0xFFE4572E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudStat(RiderThemeDef t, String emoji, String value) {
    return Text(
      '$emoji $value',
      style: TextStyle(
          color: t.text, fontWeight: FontWeight.w800, fontSize: 15),
    );
  }

  Widget _pedals(RiderThemeDef t, RiderEngine e) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: t.panel.withValues(alpha: 0.92),
      child: Row(
        children: [
          Expanded(
            child: _pedalBtn(t, '🛑 BRAKE', e.brakeDown, false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _pedalBtn(t, '🚴 PEDAL', e.pedalDown, true),
          ),
        ],
      ),
    );
  }

  Widget _pedalBtn(RiderThemeDef t, String label, bool on, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: on
              ? [t.accent, t.accentDark]
              : [
                  Color.lerp(t.panel, Colors.white, 0.3)!,
                  t.panel,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: on ? t.accentDark : t.muted.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : t.text,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _showPause(RiderThemeDef t) {
    if (_pauseDialogOpen || _engine.phase != RidePhase.paused) return;
    _pauseDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: t.accent, width: 3),
        ),
        title: Text('Paused ⏸️',
            style: TextStyle(color: t.text, fontWeight: FontWeight.w900)),
        content: Text(
          'Catch your breath, ${_engine.distanceM().toStringAsFixed(0)} m in.',
          style: TextStyle(color: t.muted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
              _engine.resume();
            },
            child: Text('RESUME',
                style:
                    TextStyle(color: t.accent, fontWeight: FontWeight.w900)),
          ),
          TextButton(
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
              setState(() {
                _dialogShown = false;
                _particles.clear();
                _banners.clear();
              });
              widget.audio.startGameMusic();
              _engine.restart();
            },
            child:
                Text('RESTART', style: TextStyle(color: t.muted)),
          ),
          TextButton(
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('QUIT', style: TextStyle(color: t.muted)),
          ),
        ],
      ),
    ).then((_) {
      _pauseDialogOpen = false;
    });
  }
}

class _FinishDialog extends StatelessWidget {
  final RiderThemeDef theme;
  final RiderAudio audio;
  final RiderSettings settings;
  final String reason;
  final double distanceM;
  final int coins;
  final int score;
  final bool isBest;
  final PlayMode mode;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const _FinishDialog({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.reason,
    required this.distanceM,
    required this.coins,
    required this.score,
    required this.isBest,
    required this.mode,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return AlertDialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: t.accent, width: 3),
      ),
      title: Column(
        children: [
          Text('🏁 Ride over!',
              style: TextStyle(color: t.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(reason,
              style: TextStyle(color: t.muted, fontSize: 15),
              textAlign: TextAlign.center),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBest)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [t.accent, t.accentDark]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '🏆 NEW BEST!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
            ),
          _row('📏 Distance', '${distanceM.toStringAsFixed(0)} m'),
          _row('🪙 Coins', '$coins'),
          _row('⚡ Score', mode == PlayMode.endless ? '$score' : '$score pts'),
          _row('🚴 Rider', settings.riderName),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TrailButton(
                label: 'RIDE AGAIN',
                icon: Icons.refresh,
                theme: t,
                primary: true,
                small: true,
                onPressed: () {
                  audio.click();
                  onRetry();
                }),
            TrailButton(
                label: 'SHARE',
                icon: Icons.share,
                theme: t,
                small: true,
                onPressed: () {
                  audio.click();
                  SharePlus.instance.share(ShareParams(
                    text:
                        'I just rode ${distanceM.toStringAsFixed(0)} m in Mountain Rider! Beat me: $storeUrl',
                    subject: 'Mountain Rider',
                  ));
                }),
            TrailButton(
                label: 'MENU',
                icon: Icons.home,
                theme: t,
                small: true,
                onPressed: () {
                  audio.click();
                  onMenu();
                }),
          ],
        ),
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: theme.muted, fontSize: 15)),
          Text(v,
              style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: parallax mountains, pines, dirt trail, rocks, pickups, the bike
// and rider. Pseudo-3D physical materials, earthy palette.
// ---------------------------------------------------------------------------

class _RidePainter extends CustomPainter {
  final RiderEngine engine;
  final RiderThemeDef theme;
  final RiderStyleDef style;
  final List<_Particle> particles;
  final int randSeed;

  _RidePainter({
    required this.engine,
    required this.theme,
    required this.style,
    required this.particles,
    required this.randSeed,
  });

  int _h(int k) {
    var h = (k * 2654435761 + randSeed * 97) & 0x7fffffff;
    h ^= h >> 13;
    h = (h * 1274126177) & 0x7fffffff;
    h ^= h >> 16;
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final x = engine.x;
    final t = theme;

    // sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.skyTop, t.skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // sun
    canvas.drawCircle(Offset(size.width - 70, 64), 30,
        Paint()..color = t.sun.withValues(alpha: 0.9));
    canvas.drawCircle(Offset(size.width - 70, 64), 44,
        Paint()..color = t.sun.withValues(alpha: 0.25));
    // clouds
    _clouds(canvas, size, x, 0.12);
    // parallax hills
    _hills(canvas, size, x, 0.25, t.farHill, 120);
    _hills(canvas, size, x, 0.5, t.nearHill, 90);
    // pines on the near hills
    _pines(canvas, size, x, 0.55);

    final baseY = size.height * 0.62;
    final riderX = size.width * 0.35;

    // trail body
    final path = Path()..moveTo(-10, size.height + 10);
    for (var sx = -10.0; sx <= size.width + 10; sx += 8) {
      path.lineTo(sx, baseY - engine.terrain(x + (sx - riderX)) * 0.5);
    }
    path.lineTo(size.width + 10, size.height + 10);
    path.close();
    canvas.drawPath(path, Paint()..color = t.trail);
    // trail surface texture strokes
    canvas.save();
    canvas.clipPath(path);
    final strokePaint = Paint()
      ..color = t.trailLine.withValues(alpha: 0.5)
      ..strokeWidth = 3;
    for (var sx = -20.0; sx <= size.width + 20; sx += 46) {
      final wx = x + (sx - riderX);
      final sy = baseY - engine.terrain(wx) * 0.5 + 18 + (_h(wx ~/ 46) % 26);
      canvas.drawLine(Offset(sx, sy), Offset(sx + 22, sy + 4), strokePaint);
    }
    canvas.restore();
    // trail edge (the ride line)
    final ridge = Path();
    var first = true;
    for (var sx = -10.0; sx <= size.width + 10; sx += 8) {
      final sy = baseY - engine.terrain(x + (sx - riderX)) * 0.5;
      if (first) {
        ridge.moveTo(sx, sy);
        first = false;
      } else {
        ridge.lineTo(sx, sy);
      }
    }
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = t.trailEdge,
    );

    // rocks
    final rockK = (x / 300).floor();
    for (int k = rockK - 3; k <= rockK + 6; k++) {
      final rock = rockAt(k, engine.p.rockDensity);
      if (rock == null) continue;
      final sx = riderX + (rock.x - x);
      if (sx < -40 || sx > size.width + 40) continue;
      final sy = baseY - engine.terrain(rock.x) * 0.5;
      canvas.drawCircle(Offset(sx, sy - rock.radius * 0.6), rock.radius,
          Paint()..color = t.rock);
      canvas.drawCircle(
          Offset(sx - rock.radius * 0.3, sy - rock.radius * 0.9),
          rock.radius * 0.4,
          Paint()..color = Color.lerp(t.rock, Colors.white, 0.25)!);
    }

    // pickups
    final seg = (x / 460).floor();
    for (int s = seg - 1; s <= seg + 4; s++) {
      if (engine.takenSegments.contains(s)) continue;
      for (final pk in pickupsIn(s, engine.p.amp)) {
        final sx = riderX + (pk.x - x);
        if (sx < -30 || sx > size.width + 30) continue;
        final sy = baseY - engine.terrain(pk.x) * 0.5 - 56;
        final bob = math.sin(x * 0.02 + pk.x) * 5;
        if (pk.kind == PickupKind.coin) {
          final spin = (math.sin(x * 0.03 + pk.x) * 0.5 + 0.5);
          final w = 4 + 8 * spin;
          canvas.drawOval(
              Rect.fromCenter(center: Offset(sx, sy + bob), width: w, height: 22),
              Paint()..color = const Color(0xFFFFC93C));
          canvas.drawOval(
              Rect.fromCenter(center: Offset(sx, sy + bob), width: w * 0.55, height: 13),
              Paint()..color = const Color(0xFFFFF3C4));
        } else {
          _bottle(canvas, Offset(sx, sy + bob));
        }
      }
    }

    // speed lines
    if (engine.v > 300) {
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2.5;
      for (int i = 0; i < 8; i++) {
        final yy = (_h(i + (x ~/ 60)) % size.height.toInt()).toDouble();
        final xx = (_h(i * 7 + (x ~/ 90)) % size.width.toInt()).toDouble();
        canvas.drawLine(Offset(xx, yy), Offset(xx + 40 + engine.v * 0.06, yy), sp);
      }
    }

    // particles (relative to rider)
    final ry = baseY - engine.terrain(x) * 0.5;
    for (final pt in particles) {
      pt.life -= 1 / 60;
      pt.x += pt.vx / 60;
      pt.y += pt.vy / 60;
      pt.vy += 500 / 60;
      if (pt.life > 0) {
        canvas.drawCircle(
          Offset(riderX + pt.x, ry - 20 + pt.y),
          pt.size * pt.life,
          Paint()..color = pt.color.withValues(alpha: pt.life.clamp(0.0, 1.0)),
        );
      }
    }
    particles.removeWhere((p) => p.life <= 0);

    // the bike + rider
    _bike(canvas, Offset(riderX, ry - engine.y * 0.5), engine.angle,
        engine.wheelSpin, engine.pedalDown);

    // dust while pedaling hard on the ground
    if (engine.pedalDown && engine.y <= 0.5 && engine.v > 120) {
      canvas.drawCircle(
          Offset(riderX - 30, ry - 6),
          8 + 3 * math.sin(engine.wheelSpin * 2),
          Paint()..color = t.trailLine.withValues(alpha: 0.6));
    }
  }

  void _bottle(Canvas canvas, Offset at) {
    final body = Paint()..color = const Color(0xFF4E9AD8);
    final cap = Paint()..color = const Color(0xFFD8D4C8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: at, width: 14, height: 24),
            const Radius.circular(5)),
        body);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(at.dx, at.dy - 14), width: 8, height: 6),
        cap);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(at.dx - 3, at.dy - 2), width: 3, height: 14),
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _clouds(Canvas canvas, Size size, double x, double par) {
    final paint = Paint()..color = theme.cloud.withValues(alpha: 0.85);
    for (int i = 0; i < 6; i++) {
      final wx = x * par + i * 640;
      final cx = ((wx % (size.width + 500)) - 250);
      final cy = 40.0 + (_h(i * 3 + 1) % 90);
      final s = 0.7 + (_h(i * 5 + 2) % 60) / 100;
      canvas.drawCircle(Offset(cx, cy), 26 * s, paint);
      canvas.drawCircle(Offset(cx + 26 * s, cy + 6 * s), 20 * s, paint);
      canvas.drawCircle(Offset(cx - 26 * s, cy + 8 * s), 18 * s, paint);
    }
  }

  void _hills(Canvas canvas, Size size, double x, double par, Color col, double h) {
    final p = Path()..moveTo(-10, size.height * 0.62);
    for (var sx = -10.0; sx <= size.width + 10; sx += 20) {
      final wx = x * par + sx;
      p.lineTo(
          sx,
          size.height * 0.62 -
              (math.sin(wx * 0.003 + par * 9) * h * 0.5 + h * 0.5));
    }
    p.lineTo(size.width + 10, size.height * 0.62);
    p.close();
    canvas.drawPath(p, Paint()..color = col);
  }

  void _pines(Canvas canvas, Size size, double x, double par) {
    for (int k = ((x * par - 100) ~/ 420); k < ((x * par + size.width + 100) ~/ 420); k++) {
      if ((_h(k * 17) % 100) < 35) continue;
      final sx = k * 420 + (_h(k * 29) % 260) - x * par;
      final sy = size.height * 0.62 - 40 - (_h(k * 41) % 60);
      final s = 0.8 + (_h(k * 53) % 50) / 100;
      final trunk = Paint()..color = const Color(0xFF5E3E22);
      final leaf = Paint()..color = theme.tree;
      final leafD = Paint()..color = theme.treeDark;
      canvas.drawRect(Rect.fromLTWH(sx - 3 * s, sy - 10 * s, 6 * s, 16 * s), trunk);
      for (int ti = 0; ti < 3; ti++) {
        final w = (34 - ti * 9) * s;
        final yy = sy - (14 + ti * 20) * s;
        final tri = Path()
          ..moveTo(sx - w / 2, yy)
          ..lineTo(sx + w / 2, yy)
          ..lineTo(sx, yy - 26 * s)
          ..close();
        canvas.drawPath(tri, ti.isEven ? leaf : leafD);
      }
    }
  }

  void _bike(Canvas canvas, Offset at, double angle, double spin, bool pedaling) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final frame = Paint()
      ..color = style.frame
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final frameD = Paint()
      ..color = style.frameDark
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // wheels
    for (final wx in [-26.0, 26.0]) {
      canvas.drawCircle(Offset(wx, 0), 15, Paint()..color = const Color(0xFF242424));
      canvas.save();
      canvas.translate(wx, 0);
      canvas.rotate(spin);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset.zero,
          Offset(10 * math.cos(i * 2.09), 10 * math.sin(i * 2.09)),
          Paint()
            ..strokeWidth = 3
            ..color = const Color(0xFF8A8A8A),
        );
      }
      canvas.restore();
      canvas.drawCircle(Offset(wx, 0), 4, Paint()..color = const Color(0xFFD8D8D8));
    }
    // frame: rear hub -> seat -> head tube -> front hub
    canvas.drawLine(const Offset(-26, 0), const Offset(-4, -26), frame);
    canvas.drawLine(const Offset(-4, -26), const Offset(16, -30), frameD);
    canvas.drawLine(const Offset(16, -30), const Offset(26, 0), frame);
    canvas.drawLine(const Offset(-26, 0), const Offset(16, -30), frameD);
    // seat + handlebar
    canvas.drawLine(const Offset(-8, -30), const Offset(0, -30),
        Paint()..color = const Color(0xFF242424)..strokeWidth = 5);
    canvas.drawLine(const Offset(16, -30), const Offset(20, -38),
        Paint()..color = const Color(0xFF242424)..strokeWidth = 5);
    // rider: legs pedaling, torso leaning forward, arms to bars, helmet head
    final kit = Paint()
      ..color = style.kit
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final kitD = Paint()
      ..color = style.kitDark
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final pedalPhase = pedaling ? spin * 2 : 0.4;
    final legSwing = math.sin(pedalPhase) * 8;
    // legs
    canvas.drawLine(const Offset(-2, -34), Offset(-14, -8 + legSwing), kitD);
    canvas.drawLine(const Offset(-2, -34), Offset(8, -8 - legSwing), kitD);
    // torso
    canvas.drawLine(const Offset(-2, -34), const Offset(16, -52), kit);
    // arms
    canvas.drawLine(const Offset(16, -52), const Offset(20, -40), kit);
    // head + helmet
    canvas.drawCircle(const Offset(22, -60), 9,
        Paint()..color = const Color(0xFFC89878));
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(22, -60), radius: 10.5),
      math.pi,
      math.pi,
      true,
      Paint()..color = style.helmet,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RidePainter old) => true;
}
