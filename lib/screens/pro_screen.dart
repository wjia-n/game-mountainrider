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
    _store.proPurchased.addListener(_onPro);
    _store.lastThanks.addListener(_onThanks);
    _store.init().then((_) {
      if (mounted) setState(() => _storeInit = true);
    });
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PRO unlocked — enjoy every trail!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _store.proPurchased.value = false;
    }
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
    _store.proPurchased.removeListener(_onPro);
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
                  _ComparisonCard(theme: t, isPro: s.isPro),
                  const SizedBox(height: 16),
                  _BuyCard(
                    theme: t,
                    settings: s,
                    store: _store,
                    audio: widget.audio,
                    storeInit: _storeInit,
                  ),
                  const SizedBox(height: 16),
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
class _ComparisonCard extends StatelessWidget {
  final RiderThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Full riding game', true, true),
      ('Training & Trail tiers', true, true),
      ('Endless mode', true, true),
      ('Renameable rider', true, true),
      ('Music & sound effects', true, true),
      ('Trail themes', '4', '12'),
      ('Rider & bike styles', '4', '10'),
      ('Custom theme creator', false, true),
      ('Enduro tier (steep & rocky)', false, true),
      ('Score Attack 60s', true, true),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              _colHead('FREE', theme, false),
              _colHead('PRO', theme, true),
            ],
          ),
          const Divider(),
          for (final r in rows) _row(theme, r.$1, r.$2, r.$3),
        ],
      ),
    );
  }

  Widget _colHead(String text, RiderThemeDef theme, bool pro) {
    return SizedBox(
      width: 76,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: pro ? theme.accentDark : theme.muted,
          ),
        ),
      ),
    );
  }

  Widget _row(RiderThemeDef theme, String label, Object free, Object pro) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: theme.text, fontSize: 14)),
          ),
          SizedBox(width: 76, child: Center(child: _cell(theme, free))),
          SizedBox(width: 76, child: Center(child: _cell(theme, pro))),
        ],
      ),
    );
  }

  Widget _cell(RiderThemeDef theme, Object v) {
    if (v is bool) {
      return v
          ? Icon(Icons.check_circle, color: theme.accentDark, size: 20)
          : Icon(Icons.remove_circle_outline,
              color: theme.muted.withValues(alpha: 0.5), size: 20);
    }
    return Text('$v',
        style: TextStyle(
            color: theme.text, fontWeight: FontWeight.w800, fontSize: 14));
  }
}

class _BuyCard extends StatelessWidget {
  final RiderThemeDef theme;
  final RiderSettings settings;
  final StoreService store;
  final RiderAudio audio;
  final bool storeInit;
  const _BuyCard({
    required this.theme,
    required this.settings,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accent, t.accentDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: store.purchaseInProgress,
        builder: (_, inProgress, _) => ValueListenableBuilder<String?>(
          valueListenable: store.purchaseError,
          builder: (_, err, _) => Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'GO PRO — one-time unlock',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Every theme, every rider style, the custom trail '
                'creator, and the wild Enduro tier. Yours forever.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (settings.isPro)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Text(
                    '✓ PRO ACTIVE — enjoy every trail!',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                )
              else if (!storeInit)
                const CircularProgressIndicator(color: Colors.white)
              else if (!store.storeReady)
                Text(
                  'Pro unlock will appear here once the store is '
                  'set up. (${store.error ?? 'coming soon'})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13),
                )
              else
                _proBuyButton(t, inProgress),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: inProgress
                    ? null
                    : () {
                        audio.click();
                        store.restore();
                      },
                child: const Text(
                  'Restore purchases',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proBuyButton(RiderThemeDef t, bool inProgress) {
    final product = store.proProduct;
    return GestureDetector(
      onTap: inProgress || product == null
          ? null
          : () {
              audio.click();
              store.buyPro();
            },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: inProgress
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Text(
                product == null
                    ? 'UNLOCK PRO'
                    : 'UNLOCK PRO — ${product.price}',
                style: TextStyle(
                  color: t.accentDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}

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
