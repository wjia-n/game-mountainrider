import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountainrider/engine/rider_engine.dart';

class _Vsync extends TickerProvider {
  const _Vsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  // Real tickers need the scheduler binding; step() is driven manually.
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pedaling accelerates the bike and moves it through the world', () {
    final e = RiderEngine(vsync: const _Vsync(), tier: RideTier.trail, mode: PlayMode.endless);
    e.start(countdownSecs: 0.01);
    for (var i = 0; i < 5; i++) { e.step(1 / 60); } // finish countdown
    expect(e.phase, RidePhase.riding);

    e.setPedals(pedal: true, brake: false);
    final x0 = e.x;
    for (var i = 0; i < 120; i++) { e.step(1 / 60); } // 2 s of pedaling
    expect(e.v, greaterThan(100), reason: 'pedaling must build speed');
    expect(e.x, greaterThan(x0 + 100), reason: 'bike must move forward');
    expect(e.pedalAngle, greaterThan(0), reason: 'legs must pedal');
    expect(e.stamina, lessThan(100), reason: 'pedaling drains stamina');

    final v0 = e.v;
    e.setPedals(pedal: false, brake: true);
    for (var i = 0; i < 120; i++) { e.step(1 / 60); } // 2 s of braking
    expect(e.v, lessThan(v0), reason: 'braking must slow the bike');

    e.dispose();
  });

  test('god mode prevents crashes and stamina drain', () {
    final e = RiderEngine(vsync: const _Vsync(), tier: RideTier.trail, mode: PlayMode.endless);
    e.start(countdownSecs: 0.01);
    for (var i = 0; i < 5; i++) { e.step(1 / 60); } // finish countdown
    e.godMode = true;
    e.setPedals(pedal: true, brake: false);
    for (var i = 0; i < 600; i++) {
      e.step(1 / 60);
      if (e.phase == RidePhase.finished) break;
    }
    expect(e.stamina, 100, reason: 'god mode: no stamina drain');
    expect(e.phase, isNot(RidePhase.finished),
        reason: 'god mode: rocks must not crash the ride');
    e.dispose();
  });
}
