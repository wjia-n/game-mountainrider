import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Ride phases. The engine owns ALL phase transitions — the UI only observes
/// and forwards input. No phase can be entered without a live timer.
enum RidePhase { idle, countdown, riding, paused, finished }

/// Difficulty tiers with clear progression.
enum RideTier { training, trail, enduro }

/// Game modes.
enum PlayMode { endless, scoreAttack }

/// Physical constants per tier. Speed and complexity scale with tier.
class TierParams {
  final double amp; // terrain amplitude
  final double maxSpeed;
  final double pedalAccel;
  final double brakePower;
  final double gravity;
  final double rockDensity; // 0..1 chance of a rock per segment
  final double staminaDrain;
  final double hardLanding; // vy threshold for crash landing

  const TierParams({
    required this.amp,
    required this.maxSpeed,
    required this.pedalAccel,
    required this.brakePower,
    required this.gravity,
    required this.rockDensity,
    required this.staminaDrain,
    required this.hardLanding,
  });
}

const Map<RideTier, TierParams> tierParams = {
  RideTier.training: TierParams(
    amp: 62,
    maxSpeed: 320,
    pedalAccel: 150,
    brakePower: 260,
    gravity: 900,
    rockDensity: 0,
    staminaDrain: 5.5,
    hardLanding: -700,
  ),
  RideTier.trail: TierParams(
    amp: 105,
    maxSpeed: 430,
    pedalAccel: 170,
    brakePower: 260,
    gravity: 950,
    rockDensity: 0.32,
    staminaDrain: 7.0,
    hardLanding: -640,
  ),
  RideTier.enduro: TierParams(
    amp: 148,
    maxSpeed: 520,
    pedalAccel: 185,
    brakePower: 280,
    gravity: 1000,
    rockDensity: 0.55,
    staminaDrain: 8.5,
    hardLanding: -580,
  ),
};

/// Juicy feedback events the UI turns into sounds/particles/banners.
enum RiderFxKind {
  count, // countdown number shown
  go,
  coin,
  water,
  jump,
  landSoft,
  landWobbly,
  bigAir,
  crash,
  pedal, // chain tick while pedaling
  finish,
}

class RiderFx {
  final RiderFxKind kind;
  final double value; // e.g. countdown number, airtime seconds
  final String text; // banner text
  const RiderFx(this.kind, {this.value = 0, this.text = ''});
}

// ---------------------------------------------------------------------------
// Deterministic world: terrain, rocks and pickups are pure functions of
// world-x, so every frame renders the same world for the same distance.
// ---------------------------------------------------------------------------

/// Integer hash for deterministic per-segment features.
int _hash(int k) {
  var h = k * 2654435761;
  h ^= h >> 13;
  h = h * 1274126177;
  h ^= h >> 16;
  return h.abs();
}

class RockInfo {
  final double x;
  final double radius;
  const RockInfo(this.x, this.radius);
}

/// Rock in segment [k] (300px wide), or null when none. Deterministic.
RockInfo? rockAt(int k, double density) {
  if (density <= 0) return null;
  if ((_hash(k) % 100) >= (density * 100).round()) return null;
  final x = k * 300.0 + 60 + (_hash(k + 7919) % 180);
  final r = 16 + (_hash(k + 104729) % 14);
  return RockInfo(x, r.toDouble());
}

enum PickupKind { coin, water }

class PickupInfo {
  final double x;
  final PickupKind kind;
  const PickupInfo(this.x, this.kind);
}

/// Pickups repeat every 460px; some segments have a coin trio, some water,
/// some nothing. Deterministic.
List<PickupInfo> pickupsIn(int seg, double amp) {
  final h = _hash(seg * 31 + 7) % 100;
  final base = seg * 460.0 + 120 + (_hash(seg + 13) % 200);
  if (h < 34) {
    return [PickupInfo(base, PickupKind.coin)];
  }
  if (h < 44) {
    return [PickupInfo(base, PickupKind.water)];
  }
  return const [];
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

/// Engine-owned ride state machine. The UI creates it with a TickerProvider,
/// calls [start], [setPedals], [pause], [resume], [restart], [dispose], and
/// listens to [fx] for feedback + [ChangeNotifier] for state.
///
/// Watchdog: a periodic timer verifies every phase still has a live driver —
/// riding needs an active ticker, countdown needs an advancing clock — and
/// repairs it. Stuck states are impossible by construction.
class RiderEngine extends ChangeNotifier {
  final TickerProvider vsync;
  final RideTier tier;
  final PlayMode mode;

  RiderEngine({
    required this.vsync,
    required this.tier,
    required this.mode,
  });

  TierParams get p => tierParams[tier]!;

  // ---- phase state ----
  RidePhase phase = RidePhase.idle;
  String finishReason = '';
  bool finishedByTime = false;

  // ---- ride state ----
  double x = 0; // world distance (px)
  double v = 0; // forward speed (px/s)
  double y = 0; // height above terrain (px)
  double vy = 0;
  double angle = 0; // bike tilt radians
  double stamina = 100;
  int coins = 0;
  double airtime = 0;
  double wheelSpin = 0;
  double timeLeft = 60; // score attack
  double elapsed = 0;

  bool pedalDown = false;
  bool brakeDown = false;

  // countdown
  double countdownT = 0;
  int _lastCount = -1;

  // fx
  final StreamController<RiderFx> _fx =
      StreamController<RiderFx>.broadcast(sync: true);
  Stream<RiderFx> get fx => _fx.stream;

  Ticker? _ticker;
  Timer? _watchdog;
  double _pedalSfxT = 0;
  final Set<int> _takenPickups = {};

  double distanceM() => x / 50;
  int score() => distanceM().round() + coins * 10;

  /// Segments whose pickups were taken (so the painter can hide them).
  Set<int> get takenSegments => _takenPickups;

  // ---------------- world ----------------
  double terrain(double wx) {
    final grow = math.min(2.2, 1 + wx / 9000);
    return (math.sin(wx * 0.004) * 0.9 +
            math.sin(wx * 0.011 + 1.7) * 0.45 +
            math.sin(wx * 0.023 + 0.5) * 0.22) *
        p.amp *
        grow;
  }

  double slopeAt(double wx) => (terrain(wx + 8) - terrain(wx - 8)) / 16;

  // ---------------- lifecycle ----------------
  /// Begin (or re-begin) the ride: countdown then riding.
  void start({double countdownSecs = 3.0}) {
    _reset();
    phase = RidePhase.countdown;
    countdownT = countdownSecs;
    _lastCount = -1;
    _ensureTicker();
    _ensureWatchdog();
    notifyListeners();
  }

  void _reset() {
    x = 0;
    v = 0;
    y = 0;
    vy = 0;
    angle = 0;
    stamina = 100;
    coins = 0;
    airtime = 0;
    wheelSpin = 0;
    timeLeft = 60;
    elapsed = 0;
    pedalDown = false;
    brakeDown = false;
    finishReason = '';
    finishedByTime = false;
    _resuming = false;
    _takenPickups.clear();
    _pedalSfxT = 0;
  }

  void setPedals({required bool pedal, required bool brake}) {
    if (phase != RidePhase.riding) return;
    pedalDown = pedal;
    brakeDown = brake;
  }

  // Pause bookkeeping: resume never resets the ride — it plays a short
  // "get ready" countdown, then continues exactly where the ride left off.
  RidePhase _resumePhase = RidePhase.riding;
  double _resumeCountdownT = 0;
  bool _resuming = false;

  void pause() {
    if (phase != RidePhase.riding && phase != RidePhase.countdown) return;
    _resumePhase = phase;
    _resumeCountdownT = countdownT;
    _resuming = false;
    phase = RidePhase.paused;
    _ticker?.stop();
    notifyListeners();
  }

  void resume() {
    if (phase != RidePhase.paused) return;
    phase = RidePhase.countdown;
    countdownT = 1.5;
    _lastCount = -1;
    _resuming = true;
    _ensureTicker();
    _ensureWatchdog();
    notifyListeners();
  }

  void restart() => start();

  /// The watchdog: every 500ms verify the current phase has a live driver
  /// and repair it. A phase can never be left without one.
  void _watchdogTick() {
    if (phase == RidePhase.riding || phase == RidePhase.countdown) {
      if (_ticker == null || !_ticker!.isActive) {
        _ensureTicker(); // ticker died (e.g. OS reclaimed it) — restart it
      }
    }
    if (phase == RidePhase.countdown && _ticker != null && !_ticker!.isActive) {
      _ensureTicker();
    }
  }

  void _ensureTicker() {
    _ticker ??= vsync.createTicker(_onTick);
    if (!_ticker!.isActive) _ticker!.start();
  }

  void _ensureWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_fx.isClosed) _watchdogTick();
    });
  }

  void _onTick(Duration _) => step(1 / 60);

  /// Advance the simulation by [dt] seconds. Public for tests.
  @visibleForTesting
  void step(double dt) {
    if (phase == RidePhase.countdown) {
      countdownT -= dt;
      final n = countdownT.ceil();
      if (n != _lastCount && n > 0) {
        _lastCount = n;
        _fx.add(RiderFx(RiderFxKind.count, value: n.toDouble()));
      }
      if (countdownT <= 0) {
        if (_resuming) {
          // End of the "get ready" countdown: continue the paused ride
          // exactly where it left off (fresh countdown if we paused during
          // the original countdown — RULES.md §12).
          _resuming = false;
          if (_resumePhase == RidePhase.countdown &&
              _resumeCountdownT > 0.01) {
            countdownT = _resumeCountdownT.clamp(0.0, 3.0);
            _lastCount = -1;
            notifyListeners();
            return;
          }
        }
        phase = RidePhase.riding;
        _fx.add(const RiderFx(RiderFxKind.go));
        notifyListeners();
      }
      return;
    }
    if (phase != RidePhase.riding) return;

    elapsed += dt;
    if (mode == PlayMode.scoreAttack) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        _finish('Time! 🏁', byTime: true);
        return;
      }
    }

    // drive
    if (pedalDown && stamina > 0) {
      v = math.min(p.maxSpeed, v + p.pedalAccel * dt);
      stamina = math.max(0, stamina - p.staminaDrain * dt);
      _pedalSfxT -= dt;
      if (_pedalSfxT <= 0) {
        _pedalSfxT = 0.28;
        _fx.add(const RiderFx(RiderFxKind.pedal));
      }
    } else {
      stamina = math.min(100, stamina + 4 * dt);
    }
    if (brakeDown) v = math.max(0, v - p.brakePower * dt);
    // gravity along the slope: downhill (slope<0) accelerates
    final slope = slopeAt(x);
    v += -slope * p.gravity * 0.35 * dt;
    v = math.max(0, v - 14 * dt); // rolling drag
    v = v.clamp(0.0, p.maxSpeed * 1.15);
    x += v * dt;
    wheelSpin += v * dt * 0.05;

    final grounded = y <= 0.5;
    if (grounded) {
      y = 0;
      vy = 0;
      airtime = 0;
      // crest launch
      final ahead = terrain(x + v * dt * 2);
      final ty = terrain(x);
      if (ahead < ty - 6 && v > 200) {
        vy = (v * slope).clamp(-260.0, 60.0);
        y = 1;
        _fx.add(const RiderFx(RiderFxKind.jump));
      }
      final want = math.atan(slope) * 0.9;
      angle += (want - angle) * math.min(1, 10 * dt);
      // exhausted with no speed and no downhill to save us
      if (v < 8 && stamina <= 0 && slope >= -0.05 && x > 100) {
        _finish('Out of steam! 🥵', byTime: false);
        return;
      }
      // rock collision
      final rock = _rockNear(x);
      if (rock != null && (x - rock.x).abs() < rock.radius + 12) {
        _finish('Hit a rock! 🪨', byTime: false);
        _fx.add(const RiderFx(RiderFxKind.crash, text: 'Hit a rock! 🪨'));
        return;
      }
    } else {
      // airborne
      airtime += dt;
      vy -= p.gravity * dt;
      y += vy * dt;
      if (pedalDown) angle -= 1.6 * dt;
      if (brakeDown) angle += 1.9 * dt;
      if (y <= 0 && vy < 0) {
        y = 0;
        final norm = angle % (math.pi * 2);
        final deg = (norm > math.pi ? norm - 2 * math.pi : norm).abs();
        if (deg > 1.25) {
          _finish('Landed on your roof! 🤕', byTime: false);
          _fx.add(const RiderFx(RiderFxKind.crash, text: 'Landed on your roof! 🤕'));
          return;
        }
        if (vy < p.hardLanding) {
          _finish('What a landing… not. 💥', byTime: false);
          _fx.add(const RiderFx(RiderFxKind.crash, text: 'What a landing… not. 💥'));
          return;
        }
        vy = 0;
        if (deg > 0.45) {
          v *= 0.75;
          _fx.add(const RiderFx(RiderFxKind.landWobbly, text: 'Wobbly!'));
        } else {
          _fx.add(const RiderFx(RiderFxKind.landSoft));
        }
        if (airtime > 1.2) {
          final bonus = (airtime * 2).round();
          coins += bonus;
          _fx.add(RiderFx(RiderFxKind.bigAir,
              value: airtime, text: 'BIG AIR! +$bonus 🪙'));
        }
        airtime = 0;
      }
    }

    // pickups
    final seg = (x / 460).floor();
    for (int s = seg - 1; s <= seg + 3; s++) {
      if (s < 0 || _takenPickups.contains(s)) continue;
      for (final pk in pickupsIn(s, p.amp)) {
        if ((pk.x - x).abs() < 34 && y < 120) {
          _takenPickups.add(s);
          if (pk.kind == PickupKind.water) {
            stamina = math.min(100, stamina + 32);
            _fx.add(const RiderFx(RiderFxKind.water, text: '+STAMINA 💧'));
          } else {
            coins++;
            _fx.add(const RiderFx(RiderFxKind.coin));
          }
        }
      }
    }

    notifyListeners();
  }

  RockInfo? _rockNear(double wx) {
    final k = (wx / 300).floor();
    for (int s = k - 1; s <= k + 1; s++) {
      if (s < 2) continue; // no rocks in the first 600px
      final r = rockAt(s, p.rockDensity);
      if (r != null && (r.x - wx).abs() < 60) return r;
    }
    return null;
  }

  void _finish(String reason, {required bool byTime}) {
    if (phase == RidePhase.finished) return;
    phase = RidePhase.finished;
    finishReason = reason;
    finishedByTime = byTime;
    _ticker?.stop();
    _fx.add(RiderFx(RiderFxKind.finish, text: reason));
    notifyListeners();
  }

  /// Test helper: force watchdog evaluation.
  @visibleForTesting
  void debugWatchdog() => _watchdogTick();

  @override
  void dispose() {
    _watchdog?.cancel();
    _ticker?.stop();
    _ticker?.dispose();
    _fx.close();
    super.dispose();
  }
}
