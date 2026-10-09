import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/rider_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  final settings = RiderSettings();
  await settings.load();
  final audio = RiderAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(MountainRiderApp(settings: settings, audio: audio));
}

class MountainRiderApp extends StatefulWidget {
  final RiderSettings settings;
  final RiderAudio audio;
  const MountainRiderApp(
      {super.key, required this.settings, required this.audio});

  @override
  State<MountainRiderApp> createState() => _MountainRiderAppState();
}

class _MountainRiderAppState extends State<MountainRiderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Mountain Rider',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: RiderThemes.byId(
              widget.settings.themeId,
              custom: widget.settings.customTheme,
            ).accent,
          ),
        ),
        home: SplashScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }
}
