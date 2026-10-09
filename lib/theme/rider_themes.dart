import 'package:flutter/material.dart';

/// Art direction: rugged outdoors. Real physical materials — dirt trails,
/// pine forests, rock faces, big skies. Earthy, never neon.
///
/// 12 trail themes (4 free, 8 PRO) + a PRO custom-theme creator, and
/// 10 rider/bike styles (4 free, 6 PRO).

class RiderThemeDef {
  final String id;
  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color sun;
  final Color farHill;
  final Color nearHill;
  final Color trail;
  final Color trailEdge;
  final Color trailLine;
  final Color rock;
  final Color tree;
  final Color treeDark;
  final Color cloud;
  final Color accent;
  final Color accentDark;
  final Color text;
  final Color muted;
  final Color panel;

  const RiderThemeDef({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.farHill,
    required this.nearHill,
    required this.trail,
    required this.trailEdge,
    required this.trailLine,
    required this.rock,
    required this.tree,
    required this.treeDark,
    required this.cloud,
    required this.accent,
    required this.accentDark,
    required this.text,
    required this.muted,
    required this.panel,
  });
}

class RiderThemes {
  static const List<String> freeThemeIds = [
    'alpine',
    'canyon',
    'autumn',
    'coast',
  ];

  static const List<RiderThemeDef> all = [
    RiderThemeDef(
      id: 'alpine',
      name: 'Alpine Meadow',
      skyTop: Color(0xFF7FB6D9),
      skyBottom: Color(0xFFDDEBDC),
      sun: Color(0xFFFFE9A8),
      farHill: Color(0xFF9AA9B5),
      nearHill: Color(0xFF6E8B5E),
      trail: Color(0xFF9A6B3F),
      trailEdge: Color(0xFF6E4A2A),
      trailLine: Color(0xFFB98A56),
      rock: Color(0xFF8B8B8B),
      tree: Color(0xFF2F6B3A),
      treeDark: Color(0xFF1E4A27),
      cloud: Color(0xFFF4F7F2),
      accent: Color(0xFFD96C2C),
      accentDark: Color(0xFF9A4A1C),
      text: Color(0xFF2B2018),
      muted: Color(0xFF6E5F52),
      panel: Color(0xFFF3EAD9),
    ),
    RiderThemeDef(
      id: 'canyon',
      name: 'Desert Canyon',
      skyTop: Color(0xFF6FB3CE),
      skyBottom: Color(0xFFF6D9A8),
      sun: Color(0xFFFFD98A),
      farHill: Color(0xFFC08552),
      nearHill: Color(0xFFA8622F),
      trail: Color(0xFFB0713A),
      trailEdge: Color(0xFF7E4C22),
      trailLine: Color(0xFFD1945A),
      rock: Color(0xFF9C6B4A),
      tree: Color(0xFF5A7A3A),
      treeDark: Color(0xFF3E5626),
      cloud: Color(0xFFFBEFD8),
      accent: Color(0xFFC2512F),
      accentDark: Color(0xFF8A3618),
      text: Color(0xFF331F14),
      muted: Color(0xFF7A5C44),
      panel: Color(0xFFF6E7CE),
    ),
    RiderThemeDef(
      id: 'autumn',
      name: 'Autumn Forest',
      skyTop: Color(0xFF8FA8C4),
      skyBottom: Color(0xFFF0D9AE),
      sun: Color(0xFFFFE4A0),
      farHill: Color(0xFF8A7A5E),
      nearHill: Color(0xFF6E5A3A),
      trail: Color(0xFF8A5A30),
      trailEdge: Color(0xFF5E3B1D),
      trailLine: Color(0xFFAE7A48),
      rock: Color(0xFF7E7E7E),
      tree: Color(0xFFB45A1E),
      treeDark: Color(0xFF7E3C10),
      cloud: Color(0xFFF3E8D4),
      accent: Color(0xFFC26A1E),
      accentDark: Color(0xFF874509),
      text: Color(0xFF2E2114),
      muted: Color(0xFF6E5A44),
      panel: Color(0xFFF1E4CC),
    ),
    RiderThemeDef(
      id: 'coast',
      name: 'Coastal Cliffs',
      skyTop: Color(0xFF5FA8D3),
      skyBottom: Color(0xFFD8ECEC),
      sun: Color(0xFFFFF3B0),
      farHill: Color(0xFF8AA5A0),
      nearHill: Color(0xFF5E7A5E),
      trail: Color(0xFF9A7A4A),
      trailEdge: Color(0xFF6B5230),
      trailLine: Color(0xFFBC9A66),
      rock: Color(0xFF7A7E80),
      tree: Color(0xFF3A7A4A),
      treeDark: Color(0xFF26522F),
      cloud: Color(0xFFF6FAFA),
      accent: Color(0xFF2E7A9A),
      accentDark: Color(0xFF1C5468),
      text: Color(0xFF1E2A30),
      muted: Color(0xFF5A6E74),
      panel: Color(0xFFEBF3EC),
    ),
    // ---------------- PRO themes ----------------
    RiderThemeDef(
      id: 'snowy',
      name: 'Snowy Peaks',
      skyTop: Color(0xFF6E93B8),
      skyBottom: Color(0xFFE8EFF4),
      sun: Color(0xFFFFFFFF),
      farHill: Color(0xFFB9C8D4),
      nearHill: Color(0xFF8AA0AE),
      trail: Color(0xFFB8A88A),
      trailEdge: Color(0xFF857A62),
      trailLine: Color(0xFFD4C8AE),
      rock: Color(0xFF9AA2A8),
      tree: Color(0xFF2A5A44),
      treeDark: Color(0xFF1A3C2E),
      cloud: Color(0xFFFFFFFF),
      accent: Color(0xFF3E7AB8),
      accentDark: Color(0xFF2A5480),
      text: Color(0xFF22303A),
      muted: Color(0xFF667A88),
      panel: Color(0xFFEDF2F4),
    ),
    RiderThemeDef(
      id: 'redwood',
      name: 'Redwood Grove',
      skyTop: Color(0xFF5E8A6E),
      skyBottom: Color(0xFFD8CFA8),
      sun: Color(0xFFFFE9A0),
      farHill: Color(0xFF6E7A5A),
      nearHill: Color(0xFF4E5A3E),
      trail: Color(0xFF7A4E2A),
      trailEdge: Color(0xFF52301A),
      trailLine: Color(0xFF9E6E40),
      rock: Color(0xFF6E6A62),
      tree: Color(0xFF7A2E1A),
      treeDark: Color(0xFF4E1C0E),
      cloud: Color(0xFFF0EAD4),
      accent: Color(0xFF8A3E1E),
      accentDark: Color(0xFF5E2810),
      text: Color(0xFF2A1C12),
      muted: Color(0xFF6A584A),
      panel: Color(0xFFEFE2C8),
    ),
    RiderThemeDef(
      id: 'volcano',
      name: 'Volcano Ash',
      skyTop: Color(0xFF5A4A52),
      skyBottom: Color(0xFFD8A87A),
      sun: Color(0xFFFFB85E),
      farHill: Color(0xFF7A5A5A),
      nearHill: Color(0xFF5A3E3E),
      trail: Color(0xFF6E5A4E),
      trailEdge: Color(0xFF46362E),
      trailLine: Color(0xFF8E7A6A),
      rock: Color(0xFF4E4442),
      tree: Color(0xFF3E4E2E),
      treeDark: Color(0xFF28321C),
      cloud: Color(0xFFE8D4BE),
      accent: Color(0xFFD84E1E),
      accentDark: Color(0xFF96320E),
      text: Color(0xFF2E2220),
      muted: Color(0xFF6E5E56),
      panel: Color(0xFFEDE0CE),
    ),
    RiderThemeDef(
      id: 'jungle',
      name: 'Jungle Trail',
      skyTop: Color(0xFF4E9A6E),
      skyBottom: Color(0xFFD8E8B0),
      sun: Color(0xFFFFF0A0),
      farHill: Color(0xFF4E7A4E),
      nearHill: Color(0xFF365A34),
      trail: Color(0xFF8A6A3A),
      trailEdge: Color(0xFF5E4622),
      trailLine: Color(0xFFAE8A54),
      rock: Color(0xFF7A7E6A),
      tree: Color(0xFF1E6E34),
      treeDark: Color(0xFF124A22),
      cloud: Color(0xFFF2F6DC),
      accent: Color(0xFF4E9A2E),
      accentDark: Color(0xFF326A1C),
      text: Color(0xFF1E2E1A),
      muted: Color(0xFF5A6E52),
      panel: Color(0xFFEDF3D8),
    ),
    RiderThemeDef(
      id: 'dusk',
      name: 'Canyon Dusk',
      skyTop: Color(0xFF6E5A8A),
      skyBottom: Color(0xFFF0A87A),
      sun: Color(0xFFFF9A4E),
      farHill: Color(0xFF8A5A6E),
      nearHill: Color(0xFF5E3E4E),
      trail: Color(0xFF7A4E3A),
      trailEdge: Color(0xFF52301E),
      trailLine: Color(0xFF9E6E54),
      rock: Color(0xFF6E5252),
      tree: Color(0xFF4E3E52),
      treeDark: Color(0xFF322636),
      cloud: Color(0xFFF6D4B4),
      accent: Color(0xFFD87A3E),
      accentDark: Color(0xFF96521E),
      text: Color(0xFF2E2426),
      muted: Color(0xFF6E5A5E),
      panel: Color(0xFFF3DFC8),
    ),
    RiderThemeDef(
      id: 'misty',
      name: 'Misty Valley',
      skyTop: Color(0xFF8AA0A8),
      skyBottom: Color(0xFFE4EAE4),
      sun: Color(0xFFF4F4E8),
      farHill: Color(0xFF9AA8A0),
      nearHill: Color(0xFF6E7E72),
      trail: Color(0xFF8E7658),
      trailEdge: Color(0xFF62543E),
      trailLine: Color(0xFFAE9878),
      rock: Color(0xFF8A8E8A),
      tree: Color(0xFF3E5E4E),
      treeDark: Color(0xFF283E32),
      cloud: Color(0xFFF6F8F4),
      accent: Color(0xFF5E8A7A),
      accentDark: Color(0xFF3E5E52),
      text: Color(0xFF26302C),
      muted: Color(0xFF66726C),
      panel: Color(0xFFEDEEE8),
    ),
    RiderThemeDef(
      id: 'badlands',
      name: 'Badlands',
      skyTop: Color(0xFF9A8A6E),
      skyBottom: Color(0xFFF0D8A8),
      sun: Color(0xFFFFD88A),
      farHill: Color(0xFFB08A5E),
      nearHill: Color(0xFF8A653E),
      trail: Color(0xFFA86A3A),
      trailEdge: Color(0xFF74431E),
      trailLine: Color(0xFFCC8E56),
      rock: Color(0xFF8A6E52),
      tree: Color(0xFF6E5E2E),
      treeDark: Color(0xFF4A3E1C),
      cloud: Color(0xFFF8ECD4),
      accent: Color(0xFFB05E1E),
      accentDark: Color(0xFF7A3E0E),
      text: Color(0xFF33241A),
      muted: Color(0xFF7A6248),
      panel: Color(0xFFF4E6CC),
    ),
    RiderThemeDef(
      id: 'highland',
      name: 'Highland Moor',
      skyTop: Color(0xFF6E8A9A),
      skyBottom: Color(0xFFD8E0D4),
      sun: Color(0xFFF0E8C0),
      farHill: Color(0xFF8A9A82),
      nearHill: Color(0xFF64745C),
      trail: Color(0xFF8A6E46),
      trailEdge: Color(0xFF5E4A2A),
      trailLine: Color(0xFFAE8E62),
      rock: Color(0xFF7E7A72),
      tree: Color(0xFF4E6E3E),
      treeDark: Color(0xFF324A26),
      cloud: Color(0xFFF0F2E8),
      accent: Color(0xFF6E8A3E),
      accentDark: Color(0xFF4A5E26),
      text: Color(0xFF242E22),
      muted: Color(0xFF5E6A58),
      panel: Color(0xFFE9EBDE),
    ),
  ];

  static RiderThemeDef byId(String id, {RiderThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      id != 'custom' && !freeThemeIds.contains(id);

  static int get freeCount => freeThemeIds.length;
}

/// Rider + bike style: kit, helmet and frame colors.
class RiderStyleDef {
  final String id;
  final String name;
  final Color kit;
  final Color kitDark;
  final Color helmet;
  final Color frame;
  final Color frameDark;
  final bool pro;

  const RiderStyleDef({
    required this.id,
    required this.name,
    required this.kit,
    required this.kitDark,
    required this.helmet,
    required this.frame,
    required this.frameDark,
    this.pro = false,
  });
}

class RiderStyles {
  static const List<RiderStyleDef> all = [
    RiderStyleDef(
      id: 'trailblazer',
      name: 'Trailblazer',
      kit: Color(0xFFD96C2C),
      kitDark: Color(0xFF9A4A1C),
      helmet: Color(0xFFC2512F),
      frame: Color(0xFF3E5E52),
      frameDark: Color(0xFF283E34),
    ),
    RiderStyleDef(
      id: 'forestfox',
      name: 'Forest Fox',
      kit: Color(0xFF4E9A2E),
      kitDark: Color(0xFF326A1C),
      helmet: Color(0xFF2E7A9A),
      frame: Color(0xFF8A3E1E),
      frameDark: Color(0xFF5E2810),
    ),
    RiderStyleDef(
      id: 'stoneguard',
      name: 'Stone Guard',
      kit: Color(0xFF5E6E7A),
      kitDark: Color(0xFF3E4A52),
      helmet: Color(0xFF2E3A42),
      frame: Color(0xFF8A2E1E),
      frameDark: Color(0xFF5E1C0E),
    ),
    RiderStyleDef(
      id: 'sunrider',
      name: 'Sun Rider',
      kit: Color(0xFFD8A82E),
      kitDark: Color(0xFF96700E),
      helmet: Color(0xFFD87A3E),
      frame: Color(0xFF2E4E6E),
      frameDark: Color(0xFF1C324A),
    ),
    // ---------------- PRO styles ----------------
    RiderStyleDef(
      id: 'nightowl',
      name: 'Night Owl',
      kit: Color(0xFF3E3E5A),
      kitDark: Color(0xFF26263A),
      helmet: Color(0xFFD8D4C8),
      frame: Color(0xFF1E1E2E),
      frameDark: Color(0xFF0E0E18),
      pro: true,
    ),
    RiderStyleDef(
      id: 'crimson',
      name: 'Crimson Peak',
      kit: Color(0xFFB02E2E),
      kitDark: Color(0xFF7A1C1C),
      helmet: Color(0xFF1E1E1E),
      frame: Color(0xFFD8D4C8),
      frameDark: Color(0xFF9A968A),
      pro: true,
    ),
    RiderStyleDef(
      id: 'glacier',
      name: 'Glacier',
      kit: Color(0xFF7AB8D8),
      kitDark: Color(0xFF4E829A),
      helmet: Color(0xFFF0F4F6),
      frame: Color(0xFF2E5A7A),
      frameDark: Color(0xFF1C3A52),
      pro: true,
    ),
    RiderStyleDef(
      id: 'ember',
      name: 'Ember',
      kit: Color(0xFFD84E1E),
      kitDark: Color(0xFF96320E),
      helmet: Color(0xFFD8A82E),
      frame: Color(0xFF4E2E1E),
      frameDark: Color(0xFF2E1A0E),
      pro: true,
    ),
    RiderStyleDef(
      id: 'mossback',
      name: 'Mossback',
      kit: Color(0xFF6E8A3E),
      kitDark: Color(0xFF4A5E26),
      helmet: Color(0xFF5E3E1E),
      frame: Color(0xFF3E3E3E),
      frameDark: Color(0xFF242424),
      pro: true,
    ),
    RiderStyleDef(
      id: 'stormchaser',
      name: 'Storm Chaser',
      kit: Color(0xFF5E5E8A),
      kitDark: Color(0xFF3E3E5E),
      helmet: Color(0xFFD8B82E),
      frame: Color(0xFF8A1E1E),
      frameDark: Color(0xFF5E0E0E),
      pro: true,
    ),
  ];

  static RiderStyleDef byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }

  static bool isPro(String id) => byId(id).pro;
}

/// Editable keys for the custom theme creator (subset of theme colors).
class CustomThemeKeys {
  static const List<String> keys = [
    'skyTop',
    'skyBottom',
    'trail',
    'tree',
    'rock',
    'accent',
  ];
  static const Map<String, String> labels = {
    'skyTop': 'Sky',
    'skyBottom': 'Horizon',
    'trail': 'Trail',
    'tree': 'Trees',
    'rock': 'Rocks',
    'accent': 'Accent',
  };

  /// Build a full theme from the stored custom colors, falling back to the
  /// Alpine base for everything else.
  static RiderThemeDef build(Map<String, int> colors) {
    final base = RiderThemes.all.first;
    Color c(String k) => Color(colors[k] ?? 0xFF000000);
    return RiderThemeDef(
      id: 'custom',
      name: 'My Trail',
      skyTop: c('skyTop'),
      skyBottom: c('skyBottom'),
      sun: base.sun,
      farHill: base.farHill,
      nearHill: base.nearHill,
      trail: c('trail'),
      trailEdge: base.trailEdge,
      trailLine: base.trailLine,
      rock: c('rock'),
      tree: c('tree'),
      treeDark: base.treeDark,
      cloud: base.cloud,
      accent: c('accent'),
      accentDark: base.accentDark,
      text: base.text,
      muted: base.muted,
      panel: base.panel,
    );
  }
}
