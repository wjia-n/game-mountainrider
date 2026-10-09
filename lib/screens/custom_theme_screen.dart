import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/rider_themes.dart';
import 'widgets.dart';

/// PRO custom theme creator: pick real trail colors and preview the result
/// live. All outdoorsy swatches — no neon.
class CustomThemeScreen extends StatefulWidget {
  final RiderAudio audio;
  final RiderSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  String _selKey = 'skyTop';

  RiderSettings get _s => widget.settings;

  /// Curated outdoorsy palette per key.
  static const Map<String, List<int>> palettes = {
    'skyTop': [
      0xFF7FB6D9, 0xFF5FA8D3, 0xFF6E93B8, 0xFF8FA8C4,
      0xFF6E5A8A, 0xFF5A4A52, 0xFF4E9A6E, 0xFF9A8A6E,
    ],
    'skyBottom': [
      0xFFDDEBDC, 0xFFF6D9A8, 0xFFF0D9AE, 0xFFD8ECEC,
      0xFFF0A87A, 0xFFD8A87A, 0xFFD8E8B0, 0xFFF0D8A8,
    ],
    'trail': [
      0xFF9A6B3F, 0xFFB0713A, 0xFF8A5A30, 0xFF9A7A4A,
      0xFFB8A88A, 0xFF7A4E2A, 0xFF6E5A4E, 0xFF8A6A3A,
    ],
    'tree': [
      0xFF2F6B3A, 0xFF5A7A3A, 0xFFB45A1E, 0xFF3A7A4A,
      0xFF2A5A44, 0xFF7A2E1A, 0xFF1E6E34, 0xFF4E6E3E,
    ],
    'rock': [
      0xFF8B8B8B, 0xFF9C6B4A, 0xFF7E7E7E, 0xFF7A7E80,
      0xFF9AA2A8, 0xFF6E6A62, 0xFF4E4442, 0xFF7E7A72,
    ],
    'accent': [
      0xFFD96C2C, 0xFFC2512F, 0xFFC26A1E, 0xFF2E7A9A,
      0xFF3E7AB8, 0xFF8A3E1E, 0xFF4E9A2E, 0xFF6E8A3E,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final preview = _s.customTheme;
    return ListenableBuilder(
      listenable: _s,
      builder: (_, _) => TrailBackdrop(
        theme: preview,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: preview.text),
              onPressed: () {
                widget.audio.click();
                Navigator.of(context).pop();
              },
            ),
            title: TrailHeading('My Trail', theme: preview),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  _s.resetCustomColors();
                },
                child: Text('RESET',
                    style: TextStyle(
                        color: preview.accentDark,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // live preview strip
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: preview.accent, width: 3),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        preview.skyTop,
                        preview.skyBottom,
                        preview.trail,
                      ],
                      stops: const [0.0, 0.55, 0.56],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 30,
                        bottom: 18,
                        child: _miniTree(preview.tree),
                      ),
                      Positioned(
                        left: 70,
                        bottom: 22,
                        child: _miniTree(preview.tree),
                      ),
                      Positioned(
                        right: 40,
                        bottom: 16,
                        child: Container(
                          width: 34,
                          height: 24,
                          decoration: BoxDecoration(
                            color: preview.rock,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: preview.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LIVE PREVIEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in CustomThemeKeys.keys)
                      ChoiceChip(
                        label: Text(CustomThemeKeys.labels[k]!),
                        selected: _selKey == k,
                        selectedColor: preview.accent,
                        labelStyle: TextStyle(
                          color: _selKey == k
                              ? Colors.white
                              : preview.text,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          widget.audio.click();
                          setState(() => _selKey = k);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final argb in palettes[_selKey]!)
                      GestureDetector(
                        onTap: () {
                          widget.audio.click();
                          _s.setCustomColor(_selKey, argb);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(argb),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _s.customColors[_selKey] == argb
                                  ? Colors.white
                                  : Colors.black26,
                              width: _s.customColors[_selKey] == argb
                                  ? 4
                                  : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.25),
                                offset: const Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: TrailButton(
                    label: 'USE MY TRAIL',
                    icon: Icons.check,
                    theme: preview,
                    primary: true,
                    onPressed: () {
                      widget.audio.click();
                      _s.setTheme('custom');
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTree(Color c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 0,
          height: 0,
          decoration: BoxDecoration(
            border: Border(
              left: const BorderSide(width: 14, color: Colors.transparent),
              right: const BorderSide(width: 14, color: Colors.transparent),
              bottom: BorderSide(width: 26, color: c),
            ),
          ),
        ),
        Container(width: 6, height: 10, color: const Color(0xFF5E3E22)),
      ],
    );
  }
}
