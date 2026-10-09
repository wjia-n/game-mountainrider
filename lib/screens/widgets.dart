import 'package:flutter/material.dart';
import '../theme/rider_themes.dart';

/// The real Play Store URL for this game (used by share + review flows).
const storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.mountainrider';

/// Shared physical-material UI: carved trail-sign panels, stitched-leather
/// buttons, embossed text. Outdoorsy, never neon, never generic dashboard.

class TrailBackdrop extends StatelessWidget {
  final RiderThemeDef theme;
  final Widget child;
  const TrailBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.skyTop,
            theme.skyBottom,
            Color.lerp(theme.skyBottom, theme.trail, 0.35)!,
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A chunky trail-sign button with carved-wood depth.
class TrailButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final RiderThemeDef theme;
  final bool primary;
  final bool small;

  const TrailButton({
    super.key,
    required this.label,
    required this.theme,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? theme.accent : theme.panel;
    final fg = primary ? Colors.white : theme.text;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 22,
          vertical: small ? 9 : 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(bg, Colors.white, 0.18)!,
              bg,
              Color.lerp(bg, Colors.black, 0.12)!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? theme.accentDark : theme.muted.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              offset: const Offset(0, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: small ? 17 : 21),
              SizedBox(width: small ? 6 : 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: small ? 14 : 17,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Embossed section heading.
class TrailHeading extends StatelessWidget {
  final String text;
  final RiderThemeDef theme;
  final double size;
  const TrailHeading(this.text, {super.key, required this.theme, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        color: theme.text,
        shadows: [
          Shadow(
            offset: const Offset(0, 2),
            blurRadius: 0,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

/// Locked pill shown on Pro-only options.
class ProLock extends StatelessWidget {
  final RiderThemeDef theme;
  const ProLock({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accentDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 11, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
