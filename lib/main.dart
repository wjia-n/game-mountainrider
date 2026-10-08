import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const MountainRiderApp());

class MountainRiderApp extends StatelessWidget {
  const MountainRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.aquaDepth,
      title: 'Mountain Rider',
      tagline: 'Full throttle. Zero fear. Mind the flips.',
      emoji: '🚙',
      slug: 'mountainrider',
      howToPlay:
          '• Hold RIGHT to throttle, LEFT to brake.\n• In the air, throttle tips you back, brake tips you forward — land flat!\n• Grab coins and fuel cans. Running dry ends the ride.\n• Don\'t land on your roof. 🏔️',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => MountainRiderScreen(players: players, callbacks: cb),
    );
  }
}
