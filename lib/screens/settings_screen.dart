import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/rider_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';
import 'widgets.dart';

/// Settings: rider name, theme picker (12 + custom), rider/bike styles,
/// audio toggles + volume, Pro link.
class SettingsScreen extends StatefulWidget {
  final RiderAudio audio;
  final RiderSettings settings;
  const SettingsScreen({super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtl;
  late final FocusNode _nameFocus;

  RiderSettings get _s => widget.settings;
  RiderThemeDef get _t => RiderThemes.byId(
        _s.themeId,
        custom: _s.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: _s.riderName);
    _nameFocus = FocusNode();
    // Commit the name when the field loses focus (keyboard dismissed,
    // tap elsewhere) — alongside per-keystroke saves below.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && mounted) {
        _s.setRiderName(_nameCtl.text);
        setState(() => _nameCtl.text = _s.riderName);
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(audio: widget.audio, settings: _s),
      ),
    );
  }

  void _openCustomTheme() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomThemeScreen(
          audio: widget.audio,
          settings: _s,
        ),
      ),
    );
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.text),
              onPressed: () {
                widget.audio.click();
                Navigator.of(context).pop();
              },
            ),
            title: TrailHeading('Settings', theme: t),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  t,
                  'Rider',
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtl,
                          focusNode: _nameFocus,
                          maxLength: 20,
                          // Save on EVERY keystroke (not just keyboard-done)
                          // into the single order-preserving profile JSON.
                          onChanged: (v) => _s.setRiderName(v),
                          style: TextStyle(color: t.text, fontSize: 17),
                          decoration: InputDecoration(
                            labelText: 'Rider name',
                            labelStyle: TextStyle(color: t.muted),
                            counterText: '',
                            enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: t.accent, width: 2),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: t.accentDark, width: 2),
                            ),
                          ),
                          onSubmitted: (v) {
                            widget.audio.click();
                            _s.setRiderName(v);
                            setState(
                                () => _nameCtl.text = _s.riderName);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      TrailButton(
                        label: 'Save',
                        theme: t,
                        small: true,
                        primary: true,
                        onPressed: () {
                          widget.audio.click();
                          _s.setRiderName(_nameCtl.text);
                          setState(() => _nameCtl.text = _s.riderName);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Rider name saved!',
                                  style: TextStyle(color: t.text)),
                              backgroundColor: t.panel,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TrailHeading('Trail Theme', theme: t, size: 16),
                const SizedBox(height: 8),
                _themeGrid(t),
                if (!_s.isPro)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TrailButton(
                      label: 'Unlock all 12 themes with PRO',
                      icon: Icons.star,
                      theme: t,
                      small: true,
                      onPressed: _openPro,
                    ),
                  ),
                const SizedBox(height: 16),
                TrailHeading('Rider & Bike', theme: t, size: 16),
                const SizedBox(height: 8),
                _styleGrid(t),
                const SizedBox(height: 16),
                _card(
                  t,
                  'Sound',
                  Column(
                    children: [
                      _toggle(
                        t,
                        'Music',
                        Icons.music_note,
                        _s.musicOn,
                        (v) {
                          widget.audio.click();
                          _s.setMusic(v);
                          widget.audio.configure(
                            musicOn: v,
                            sfxOn: _s.sfxOn,
                            volume: _s.volume,
                          );
                          if (v) widget.audio.startMenuMusic();
                        },
                      ),
                      _toggle(
                        t,
                        'Sound effects',
                        Icons.volume_up,
                        _s.sfxOn,
                        (v) {
                          _s.setSfx(v);
                          widget.audio.configure(
                            musicOn: _s.musicOn,
                            sfxOn: v,
                            volume: _s.volume,
                          );
                          widget.audio.click();
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.volume_down, color: t.muted),
                          Expanded(
                            child: Slider(
                              value: _s.volume,
                              activeColor: t.accent,
                              inactiveColor:
                                  t.muted.withValues(alpha: 0.3),
                              onChanged: (v) {
                                _s.setVolume(v);
                                widget.audio.configure(
                                  musicOn: _s.musicOn,
                                  sfxOn: _s.sfxOn,
                                  volume: v,
                                );
                              },
                              onChangeEnd: (_) => widget.audio.click(),
                            ),
                          ),
                          Icon(Icons.volume_up, color: t.muted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(RiderThemeDef t, String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: t.muted.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrailHeading(title, theme: t, size: 15),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _toggle(RiderThemeDef t, String label, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: t.accentDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ),
        Switch(
          value: value,
          activeThumbColor: t.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _themeGrid(RiderThemeDef t) {
    final items = <Widget>[];
    for (final theme in RiderThemes.all) {
      final locked = RiderThemes.isProTheme(theme.id) && !_s.isPro;
      items.add(_swatch(
        t,
        theme.name,
        [theme.skyTop, theme.trail, theme.tree, theme.accent],
        selected: _s.themeId == theme.id,
        locked: locked,
        onTap: () {
          widget.audio.click();
          if (locked) {
            _openPro();
            return;
          }
          _s.setTheme(theme.id);
        },
      ));
    }
    // custom theme creator slot
    items.add(_swatch(
      t,
      'My Trail',
      _s.isPro
          ? [
              _s.customTheme.skyTop,
              _s.customTheme.trail,
              _s.customTheme.tree,
              _s.customTheme.accent
            ]
          : [t.muted, t.muted, t.muted, t.muted],
      selected: _s.themeId == 'custom',
      locked: !_s.isPro,
      onTap: () {
        widget.audio.click();
        if (!_s.isPro) {
          _openPro();
          return;
        }
        _s.setTheme('custom');
        _openCustomTheme();
      },
    ));
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: items,
    );
  }

  Widget _swatch(
    RiderThemeDef t,
    String name,
    List<Color> colors, {
    required bool selected,
    required bool locked,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.panel.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.accent : t.muted.withValues(alpha: 0.4),
            width: selected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in colors)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            if (locked) ...[
              const SizedBox(height: 2),
              ProLock(theme: t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _styleGrid(RiderThemeDef t) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final s in RiderStyles.all)
          GestureDetector(
            onTap: () {
              widget.audio.click();
              if (s.pro && !_s.isPro) {
                _openPro();
                return;
              }
              _s.setStyle(s.id);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.panel.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _s.styleId == s.id
                      ? t.accent
                      : t.muted.withValues(alpha: 0.4),
                  width: _s.styleId == s.id ? 3 : 2,
                ),
              ),
              child: Row(
                children: [
                  // mini rider preview: helmet + kit + frame dots
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                              color: s.helmet,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26))),
                      const SizedBox(height: 2),
                      Container(
                          width: 22,
                          height: 14,
                          decoration: BoxDecoration(
                              color: s.kit,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.black26))),
                      const SizedBox(height: 2),
                      Container(
                          width: 26,
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.frame,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black26))),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: TextStyle(
                                color: t.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                        if (s.pro && !_s.isPro) ProLock(theme: t),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
