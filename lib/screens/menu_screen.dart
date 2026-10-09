import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/rider_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/rider_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Main menu: mode + tier select, bests, and navigation to every screen.
class MenuScreen extends StatefulWidget {
  final RiderAudio audio;
  final RiderSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  RideTier _tier = RideTier.trail;
  PlayMode _mode = PlayMode.endless;

  RiderSettings get _s => widget.settings;
  RiderThemeDef get _t => RiderThemes.byId(
        _s.themeId,
        custom: _s.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic(); // music starts reliably on menu entry
  }

  String get _bestKey => '${_tier.name}_${_mode.name}';

  String _tierLabel(RideTier t) => switch (t) {
        RideTier.training => 'Training',
        RideTier.trail => 'Trail',
        RideTier.enduro => 'Enduro',
      };

  String _tierHint(RideTier t) => switch (t) {
        RideTier.training => 'Gentle slopes, no rocks',
        RideTier.trail => 'Real trails, some rocks',
        RideTier.enduro => 'Steep, rocky, wild',
      };

  void _play() {
    widget.audio.click();
    if (_tier == RideTier.enduro && !_s.isPro) {
      _goPro();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: _s,
          tier: _tier,
          mode: _mode,
        ),
      ),
    );
  }

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(audio: widget.audio, settings: _s),
      ),
    );
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(audio: widget.audio, settings: _s),
      ),
    );
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(ShareParams(
      text:
          'I\'m riding the trails in Mountain Rider! Think you can beat my distance? $storeUrl',
      subject: 'Mountain Rider',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListenableBuilder(
      listenable: _s,
      builder: (_, _) => TrailBackdrop(
        theme: t,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final landscape =
                    orientation == Orientation.landscape ||
                        MediaQuery.of(context).size.width > 700;
                return landscape ? _landscape(t) : _portrait(t);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _portrait(RiderThemeDef t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _brand(t),
          const SizedBox(height: 14),
          _selectors(t),
          const SizedBox(height: 16),
          _playButton(t),
          const SizedBox(height: 14),
          _navRow(t),
        ],
      ),
    );
  }

  Widget _landscape(RiderThemeDef t) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _brand(t),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _selectors(t),
                const SizedBox(height: 16),
                _playButton(t),
                const SizedBox(height: 14),
                _navRow(t),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _brand(RiderThemeDef t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/mountainrider_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Text(
          'MOUNTAIN RIDER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: t.text,
            shadows: [
              Shadow(
                offset: const Offset(0, 3),
                blurRadius: 0,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: t.text.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _s.riderName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectors(RiderThemeDef t) {
    return Column(
      children: [
        TrailHeading('Mode', theme: t, size: 16),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _modeCard(t, PlayMode.endless, '🏔️', 'Endless', 'Ride till you crash')),
            const SizedBox(width: 10),
            Expanded(child: _modeCard(t, PlayMode.scoreAttack, '⏱️', 'Score Attack', '60 seconds, max score')),
          ],
        ),
        const SizedBox(height: 14),
        TrailHeading('Trail Tier', theme: t, size: 16),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final tier in RideTier.values) ...[
              Expanded(child: _tierCard(t, tier)),
              if (tier != RideTier.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _bestLine(t),
      ],
    );
  }

  Widget _modeCard(
      RiderThemeDef t, PlayMode m, String emoji, String title, String hint) {
    final sel = _mode == m;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        setState(() => _mode = m);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? t.accent : t.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? t.accentDark : t.muted.withValues(alpha: 0.4),
            width: sel ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: sel ? Colors.white : t.text,
              ),
            ),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: (sel ? Colors.white : t.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierCard(RiderThemeDef t, RideTier tier) {
    final sel = _tier == tier;
    final locked = tier == RideTier.enduro && !_s.isPro;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        setState(() => _tier = tier);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? t.accent : t.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? t.accentDark : t.muted.withValues(alpha: 0.4),
            width: sel ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            if (locked) ProLock(theme: t) else const SizedBox(height: 18),
            const SizedBox(height: 4),
            Text(
              _tierLabel(tier),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: sel ? Colors.white : t.text,
              ),
            ),
            Text(
              _tierHint(tier),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: sel ? Colors.white : t.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bestLine(RiderThemeDef t) {
    final best = _s.best[_bestKey] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: t.text.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        best > 0
            ? '🏆 Best ${_mode == PlayMode.endless ? 'distance' : 'score'}: ${_fmtBest(best)}'
            : '🏆 No best yet — go set one!',
        style: TextStyle(
          color: t.text,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _fmtBest(double v) => _mode == PlayMode.endless
      ? '${v.toStringAsFixed(0)} m'
      : v.toStringAsFixed(0);

  Widget _playButton(RiderThemeDef t) {
    return SizedBox(
      width: double.infinity,
      child: TrailButton(
        label: 'RIDE  ▶',
        icon: Icons.directions_bike,
        theme: t,
        primary: true,
        onPressed: _play,
      ),
    );
  }

  Widget _navRow(RiderThemeDef t) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        TrailButton(
          label: 'Settings',
          icon: Icons.settings,
          theme: t,
          small: true,
          onPressed: _openSettings,
        ),
        TrailButton(
          label: _s.isPro ? 'PRO ✓' : 'Get PRO',
          icon: Icons.star,
          theme: t,
          small: true,
          onPressed: _goPro,
        ),
        TrailButton(
          label: 'Share',
          icon: Icons.share,
          theme: t,
          small: true,
          onPressed: _share,
        ),
      ],
    );
  }
}
