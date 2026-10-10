import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/rider_themes.dart';
import 'widgets.dart';

/// Mountain Rider PRO: Free-vs-Pro comparison, real purchase, restore,
/// and tip jar. All prices come from the store — never hardcoded.
class ProScreen extends StatefulWidget {
  final RiderAudio audio;
  final RiderSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  late final StoreService _store;
  bool _storeInit = false;

  RiderThemeDef get _t => RiderThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _store = StoreService();
    _store.lastThanks.addListener(_onThanks);
    _store.init().then((_) {
      if (mounted) setState(() => _storeInit = true);
    });
  }

  
  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
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
            title: TrailHeading('Mountain Rider PRO', theme: t),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                                    _TipsCard(
                    theme: t,
                    store: _store,
                    audio: widget.audio,
                    storeInit: _storeInit,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Free vs Pro comparison table.
class _TipsCard extends StatelessWidget {
  final RiderThemeDef theme;
  final StoreService store;
  final RiderAudio audio;
  final bool storeInit;
  const _TipsCard({
    required this.theme,
    required this.store,
    required this.audio,
    required this.storeInit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.muted.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          TrailHeading('Tip Jar ☕', theme: t, size: 16),
          const SizedBox(height: 6),
          Text(
            'Love the ride? A coffee or chocolate keeps the trails groomed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (!storeInit)
            const CircularProgressIndicator()
          else if (!store.storeReady)
            Text(
              'Tips will appear here once the store is set up.',
              style: TextStyle(color: t.muted, fontSize: 13),
            )
          else
            ValueListenableBuilder<bool>(
              valueListenable: store.purchaseInProgress,
              builder: (_, inProgress, _) => Row(
                children: [
                  Expanded(
                      child: _tipButton(t, store.coffeeProduct, '☕ Coffee',
                          inProgress)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tipButton(t, store.chocolateProduct,
                          '🍫 Chocolate', inProgress)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tipButton(
      RiderThemeDef t, ProductDetails? product, String label, bool busy) {
    return GestureDetector(
      onTap: busy || product == null
          ? null
          : () {
              audio.click();
              store.buyTip(product);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent, width: 2),
        ),
        child: Center(
          child: Text(
            product == null ? label : '$label\n${product.price}',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.text, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}