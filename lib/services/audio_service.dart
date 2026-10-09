import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Mountain Rider — all sounds synthesized in code as
/// WAV bytes. No asset files. Outdoorsy, physical, trail-appropriate sounds.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class RiderAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  RiderAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  /// Plucked-string-ish tone: fast decay, bright attack.
  List<double> _pluck(double freq, double secs, {double bright = 0.4}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final ph = 2 * pi * freq * t;
      final decay = exp(-t * 7);
      out[i] = _env(i, n, attack: 0.004) *
          decay *
          (sin(ph) + bright * sin(2 * ph) + bright * 0.4 * sin(3 * ph));
    }
    return out;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _thud() {
    // Crash thud: low boom + gravel scrape.
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.9 * sin(2 * pi * 90 * t) * exp(-t * 12) +
              0.4 * sin(2 * pi * 55 * t) * exp(-t * 8) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 25));
    }
    return out;
  }

  List<double> _coinDing() {
    final n = (_rate * 0.3).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.7 * sin(2 * pi * 2093 * t) * exp(-t * 18) +
              0.5 * sin(2 * pi * 2637 * t) * exp(-t * 22));
    }
    return out;
  }

  List<double> _whoosh() {
    final n = (_rate * 0.45).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final swell = sin(pi * (i / n));
      out[i] = 0.35 * swell * (_rand.nextDouble() * 2 - 1) *
          (0.6 + 0.4 * sin(2 * pi * 300 * t));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {bool pluck = false}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(pluck ? _pluck(f, noteSecs) : _tone(f, noteSecs));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Gentle campfire fingerpicking: G – Em – C – D plucks, 14s loop.
        const seq = [
          [196.0, 246.94, 293.66, 392.0], // G
          [164.81, 196.0, 246.94, 329.63], // Em
          [130.81, 196.0, 261.63, 329.63], // C
          [146.83, 220.0, 293.66, 369.99], // D
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord([chord[0] / 2], 3.5));
          for (final f in chord) {
            out.addAll(_pluck(f, 0.55));
          }
          out.addAll(List<double>.filled((_rate * 0.4).round(), 0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Driving trail rhythm: bass pulse + strummed chords, 10s loop.
        const chords = [
          [196.0, 246.94, 293.66], // G
          [196.0, 246.94, 293.66], // G
          [174.61, 220.0, 261.63], // F
          [146.83, 220.0, 293.66], // D
        ];
        final n = (_rate * 10).round();
        final out = List<double>.filled(n, 0);
        // Bass pulse on eighths.
        for (int k = 0; k < 20; k++) {
          final start = (n * k / 20).round();
          final tone = _pluck(chords[k ~/ 5][0] / 2, 0.32);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.5;
          }
        }
        // Strummed chords on quarters.
        for (int k = 0; k < 10; k++) {
          final start = (n * k / 10).round();
          for (int s = 0; s < 3; s++) {
            final tone = _pluck(chords[k ~/ 3 % 4][s], 0.3);
            final off = start + (s * _rate * 0.015).round();
            for (int i = 0; i < tone.length && off + i < n; i++) {
              out[off + i] += tone[i] * 0.22;
            }
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));

  /// Chain tick when pedaling.
  Future<void> pedal() => _play(_clip('pedal', () {
        final n = (_rate * 0.09).round();
        final out = List<double>.filled(n, 0);
        for (int i = 0; i < n; i++) {
          final t = i / _rate;
          out[i] = _env(i, n, attack: 0.004) *
              (0.6 * sin(2 * pi * 700 * t) * exp(-t * 60) +
                  0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90));
        }
        return out;
      }));

  Future<void> coin() => _play(_clip('coin', _coinDing));

  /// Water bottle glug.
  Future<void> water() => _play(_clip('water', () {
        final out = <double>[];
        for (int g = 0; g < 3; g++) {
          out.addAll(_tone(300 + g * 90, 0.09, freqEnd: 180 + g * 90));
          out.addAll(List<double>.filled((_rate * 0.02).round(), 0));
        }
        return out;
      }));

  Future<void> crash() => _play(_clip('crash', _thud));

  /// Launch off a crest.
  Future<void> jump() => _play(_clip('jump', _whoosh));

  /// Wheel thump on landing.
  Future<void> land() =>
      _play(_clip('land', () => _tone(120, 0.14, harmonics: 0.4)));

  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));

  Future<void> countBeep() => _play(_clip('count', () => _tone(660, 0.12)));

  Future<void> go() => _play(_clip('go', () => _tone(880, 0.28)));

  Future<void> bigAir() => _play(_clip(
      'bigair', () => _arp([523.25, 659.25, 783.99], 0.12, 0.02, pluck: true)));

  Future<void> win() => _play(_clip('win',
      () => _arp([392.0, 523.25, 659.25, 783.99, 1046.5], 0.16, 0.03, pluck: true)));

  Future<void> lose() => _play(
      _clip('lose', () => _arp([329.63, 293.66, 246.94, 196.0], 0.24, 0.05)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
