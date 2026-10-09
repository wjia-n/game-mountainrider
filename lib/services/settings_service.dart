import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/rider_themes.dart';

/// Persisted settings + rider profile for Mountain Rider.
///
/// The rider profile (display name, theme, style, custom colors, best
/// distances, lifetime stats, Pro flag) is stored as ONE JSON string.
/// Android's SharedPreferences stores StringLists as an unordered StringSet,
/// so ordered data must never use setStringList — a single JSON string keeps
/// order and structure intact. Legacy keys are migrated once on load and then
/// deleted.
class RiderSettings extends ChangeNotifier {
  /// The single order-safe profile key. Everything profile-shaped lives here
  /// as ONE JSON string via setString (never setStringList — Android backs
  /// StringList with an unordered StringSet, scrambling slot order).
  static const _kProfile = 'mountainrider_player_names_json';

  // Legacy keys from older builds — migrated once, then removed.
  static const _kLegacyProfileJson = 'mountainrider_profile_json';
  static const _kLegacyBest = 'rider_best'; // double: best Trail endless metres
  static const _kLegacyNames = 'mountainrider_names'; // legacy StringList
  static const _kLegacyTheme = 'mountainrider_theme';
  static const _kLegacyStyle = 'mountainrider_style';
  static const _kLegacyPro = 'mountainrider_is_pro';

  // Plain audio keys (not profile data).
  static const _kMusic = 'mountainrider_music_on';
  static const _kSfx = 'mountainrider_sfx_on';
  static const _kVolume = 'mountainrider_volume';

  static const defaultName = 'Rider';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // ---- profile (persisted as one JSON string) ----
  String riderName = defaultName;
  String themeId = 'alpine';
  String styleId = 'trailblazer';
  Map<String, int> customColors = Map.of(_defaultCustomColors);
  Map<String, double> best = {}; // '<tier>_<mode>' -> metres/score
  int rides = 0;
  int totalCoins = 0;
  bool isPro = false;
  int lastReviewPrompt = 0; // epoch ms

  static const Map<String, int> _defaultCustomColors = {
    'skyTop': 0xFF7FB6D9,
    'skyBottom': 0xFFDDEBDC,
    'trail': 0xFF9A6B3F,
    'tree': 0xFF2F6B3A,
    'rock': 0xFF8B8B8B,
    'accent': 0xFFD96C2C,
  };

  /// Encode the whole profile as one JSON string (order-preserving).
  String encodeProfile() => jsonEncode({
        'name': riderName,
        'themeId': themeId,
        'styleId': styleId,
        'customColors': customColors,
        'best': best,
        'rides': rides,
        'totalCoins': totalCoins,
        'isPro': isPro,
        'lastReviewPrompt': lastReviewPrompt,
      });

  /// Decode a persisted profile; falls back to defaults on missing/corrupt.
  static Map<String, dynamic> decodeProfile(String? raw) {
    if (raw == null) return {};
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return {};
  }

  RiderThemeDef get customTheme => CustomThemeKeys.build(customColors);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;

    var profile = decodeProfile(p.getString(_kProfile));
    // One-time migration from the pre-release profile key name.
    if (profile.isEmpty) {
      final legacyRaw = p.getString(_kLegacyProfileJson);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        // Copy the legacy JSON verbatim under the new key, then delete it.
        await p.setString(_kProfile, legacyRaw);
        await p.remove(_kLegacyProfileJson);
        profile = decodeProfile(legacyRaw);
      }
    }
    riderName = _cleanName(profile['name']);
    themeId = (profile['themeId'] as String?) ?? 'alpine';
    styleId = (profile['styleId'] as String?) ?? 'trailblazer';
    final cc = profile['customColors'];
    if (cc is Map) {
      for (final k in _defaultCustomColors.keys) {
        final v = cc[k];
        if (v is int) customColors[k] = v;
      }
    }
    final b = profile['best'];
    if (b is Map) {
      b.forEach((k, v) {
        if (k is String && v is num) best[k] = v.toDouble();
      });
    }
    rides = (profile['rides'] as num?)?.toInt() ?? 0;
    totalCoins = (profile['totalCoins'] as num?)?.toInt() ?? 0;
    isPro = (profile['isPro'] as bool?) ?? false;
    lastReviewPrompt = (profile['lastReviewPrompt'] as num?)?.toInt() ?? 0;

    // ---- one-time migration of legacy keys ----
    var migrated = false;
    if (profile.isEmpty) {
      final legacyBest = p.getDouble(_kLegacyBest);
      if (legacyBest != null && legacyBest > 0) {
        best['trail_endless'] = legacyBest;
        migrated = true;
      }
      final legacyNames = p.getStringList(_kLegacyNames);
      if (legacyNames != null && legacyNames.isNotEmpty) {
        final n = legacyNames.first.trim();
        if (n.isNotEmpty) {
          riderName = n.length > 20 ? n.substring(0, 20) : n;
          migrated = true;
        }
      }
      final legacyTheme = p.getString(_kLegacyTheme);
      if (legacyTheme != null && legacyTheme.isNotEmpty) {
        themeId = legacyTheme;
        migrated = true;
      }
      final legacyStyle = p.getString(_kLegacyStyle);
      if (legacyStyle != null && legacyStyle.isNotEmpty) {
        styleId = legacyStyle;
        migrated = true;
      }
      final legacyPro = p.getBool(_kLegacyPro);
      if (legacyPro == true) {
        isPro = true;
        migrated = true;
      }
    }
    await p.remove(_kLegacyBest);
    await p.remove(_kLegacyProfileJson);
    await p.remove(_kLegacyNames);
    await p.remove(_kLegacyTheme);
    await p.remove(_kLegacyStyle);
    await p.remove(_kLegacyPro);

    _enforceFreeLimits(silent: true);
    if (migrated) await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfile, encodeProfile());
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || RiderThemes.isProTheme(themeId)) {
      themeId = 'alpine';
      changed = true;
    }
    if (RiderStyles.isPro(styleId)) {
      styleId = 'trailblazer';
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  static String _cleanName(Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultName : s;
  }

  // ---------------- audio ----------------
  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  // ---------------- profile ----------------
  Future<void> setRiderName(String name) async {
    riderName = _cleanName(name);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || RiderThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setStyle(String id) async {
    if (!isPro && RiderStyles.isPro(id)) return;
    styleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  /// Record a finished ride. Returns true if it set a new best.
  Future<bool> recordRide({
    required String tier,
    required String mode,
    required double score,
    required int coins,
  }) async {
    final key = '${tier}_$mode';
    final prev = best[key] ?? 0;
    final isBest = score > prev;
    if (isBest) best[key] = score;
    rides++;
    totalCoins += coins;
    notifyListeners();
    await _save();
    return isBest;
  }

  Future<void> markReviewPrompted() async {
    lastReviewPrompt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _save();
  }
}
