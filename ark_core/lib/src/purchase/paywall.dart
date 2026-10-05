import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'parent_gate.dart';
import 'purchase_service.dart';
import 'purchase_strings.dart';
import 'purchase_theme.dart';
import 'store_gateway.dart';

/// Opens an external URL (e.g. `url_launcher`'s `launchUrl`). Return false
/// if it could not be opened — the paywall then copies the URL instead.
typedef PurchaseUrlOpener = Future<bool> Function(Uri uri);

/// One line of "what you get" on the paywall.
@immutable
class PaywallFeature {
  const PaywallFeature(this.emoji, this.text);
  final String emoji;
  final String text;
}

/// Japanese message for a purchase/restore outcome.
String purchaseMessage(PurchaseResult r, PurchaseStrings s) {
  switch (r.kind) {
    case PurchaseResultKind.success:
    case PurchaseResultKind.alreadyOwned:
      return s.purchased;
    case PurchaseResultKind.restored:
      return s.restored;
    case PurchaseResultKind.pending:
      return s.pending;
    case PurchaseResultKind.canceled:
      return s.canceled;
    case PurchaseResultKind.nothingToRestore:
      return s.nothingToRestore;
    case PurchaseResultKind.timeout:
      return s.timeout;
    case PurchaseResultKind.error:
      switch (r.error) {
        case PurchaseErrorKind.storeUnavailable:
          return s.storeUnavailable;
        case PurchaseErrorKind.productNotFound:
          return s.productNotFound;
        case PurchaseErrorKind.network:
          return s.network;
        case PurchaseErrorKind.notAllowed:
          return s.notAllowed;
        case PurchaseErrorKind.unknown:
        case null:
          return s.genericError;
      }
  }
}

/// Shows the purchase sheet. Resolves to whether the app is unlocked when
/// the sheet closes.
///
/// KIDS: pass `requireParentGate: true` — the gate is shown first and
/// covers everything inside (purchase, restore, code, external links).
Future<bool> showPaywall(
  BuildContext context, {
  PurchaseService? service,
  List<PaywallFeature> features = const [],
  Widget? hero,
  String? productId,
  Uri? termsUrl,
  Uri? privacyUrl,
  PurchaseUrlOpener? openUrl,
  bool requireParentGate = false,
  bool showRedeem = true,
  PurchaseTheme theme = PurchaseTheme.kids,
  PurchaseStrings strings = const PurchaseStrings(),
  ParentGateStrings gateStrings = const ParentGateStrings(),
}) async {
  final svc = service ?? PurchaseService.instance;
  if (requireParentGate) {
    final ok = await showParentGate(
      context,
      theme: theme,
      strings: gateStrings,
    );
    if (!ok) return svc.isUnlocked.value;
    if (!context.mounted) return svc.isUnlocked.value;
  }
  await showPurchaseDialog<void>(
    context: context,
    theme: theme,
    builder: (ctx) => Paywall(
      service: svc,
      features: features,
      hero: hero,
      productId: productId,
      termsUrl: termsUrl,
      privacyUrl: privacyUrl,
      openUrl: openUrl,
      showRedeem: showRedeem,
      theme: theme,
      strings: strings,
      onClose: () => Navigator.of(ctx).pop(),
    ),
  );
  return svc.isUnlocked.value;
}

/// The purchase sheet body. Use [showPaywall], or embed it in a page.
class Paywall extends StatefulWidget {
  const Paywall({
    super.key,
    required this.service,
    this.features = const [],
    this.hero,
    this.productId,
    this.termsUrl,
    this.privacyUrl,
    this.openUrl,
    this.showRedeem = true,
    this.theme = PurchaseTheme.kids,
    this.strings = const PurchaseStrings(),
    this.onClose,
  });

  final PurchaseService service;
  final List<PaywallFeature> features;
  final Widget? hero;
  final String? productId;
  final Uri? termsUrl;
  final Uri? privacyUrl;
  final PurchaseUrlOpener? openUrl;
  final bool showRedeem;
  final PurchaseTheme theme;
  final PurchaseStrings strings;
  final VoidCallback? onClose;

  @override
  State<Paywall> createState() => _PaywallState();
}

enum _Busy { none, buy, restore, redeem }

class _PaywallState extends State<Paywall> {
  _Busy _busy = _Busy.none;
  String? _message;
  bool _messageIsError = false;
  bool _canRetry = false;
  AppLifecycleListener? _lifecycle;

  PurchaseService get _svc => widget.service;
  PurchaseStrings get _s => widget.strings;
  PurchaseTheme get _t => widget.theme;

  @override
  void initState() {
    super.initState();
    // After a Play promo-code redemption (or Ask to Buy approval) the user
    // comes back to the app: re-check what the store says we own.
    _lifecycle = AppLifecycleListener(onResume: () => _svc.refresh());
    if (_svc.products.value.isEmpty) {
      scheduleMicrotask(() async {
        await _svc.refresh();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _show(String msg, {bool error = false, bool retry = false}) {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _messageIsError = error;
      _canRetry = retry;
    });
  }

  Future<void> _run(_Busy kind, Future<void> Function() body) async {
    if (_busy != _Busy.none) return;
    setState(() {
      _busy = kind;
      _message = null;
    });
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _buy() => _run(_Busy.buy, () async {
    final r = await _svc.buy(widget.productId);
    _show(
      purchaseMessage(r, _s),
      error: r.kind == PurchaseResultKind.error,
      retry: r.kind == PurchaseResultKind.error,
    );
  });

  Future<void> _restore() => _run(_Busy.restore, () async {
    final r = await _svc.restore();
    _show(
      purchaseMessage(r, _s),
      error: r.kind == PurchaseResultKind.error,
      retry: r.kind == PurchaseResultKind.error,
    );
  });

  Future<void> _redeem() => _run(_Busy.redeem, () async {
    final o = await _svc.redeemCode();
    switch (o) {
      case RedeemOutcome.sheetPresented:
        break; // unlock arrives through the purchase stream
      case RedeemOutcome.simulated:
        _show(_s.purchased);
      case RedeemOutcome.openPlayStore:
        if (mounted) await _androidRedeemDialog();
      case RedeemOutcome.unsupported:
        _show(_s.redeemUnsupported, error: true);
    }
  });

  Future<void> _open(Uri uri) async {
    var ok = false;
    final opener = widget.openUrl;
    if (opener != null) {
      try {
        ok = await opener(uri);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      _show('${_s.urlCopied}\n$uri');
    }
  }

  Future<void> _androidRedeemDialog() async {
    final controller = TextEditingController();
    await showPurchaseDialog<void>(
      context: context,
      theme: _t,
      dismissible: true,
      builder: (ctx) => PurchaseSheet(
        theme: _t,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _s.redeemTitle,
              textAlign: TextAlign.center,
              style: _t.text(size: 19, color: _t.accentDeep),
            ),
            const SizedBox(height: 8),
            Text(
              _s.redeemAndroidHelp,
              style: _t.text(size: 13, weight: FontWeight.w600, height: 1.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: _t.text(size: 18),
              decoration: InputDecoration(
                hintText: _s.redeemCodeHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PurchaseButton(
              label: _s.redeemOpenPlay,
              theme: _t,
              onTap: () async {
                final uri = _svc.playRedeemUri(controller.text);
                Navigator.of(ctx).pop();
                await _open(uri);
              },
            ),
            const SizedBox(height: 10),
            Text(
              _s.redeemAndroidManual,
              style: _t.text(
                size: 11.5,
                weight: FontWeight.w600,
                color: _t.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_s.close, style: _t.text(color: _t.muted)),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _svc.isUnlocked,
        _svc.products,
        _svc.phase,
        _svc.storeAvailable,
      ]),
      builder: (context, _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final t = _t;
    final s = _s;
    final unlocked = _svc.isUnlocked.value;
    final pending = _svc.phase.value == PurchasePhase.pending;
    final price = _svc.priceOf(widget.productId);
    final simulating = _svc.isSimulating;
    final showRedeem =
        widget.showRedeem && (simulating || _svc.storeKind != StoreKind.none);

    return PurchaseSheet(
      theme: t,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (simulating && !kReleaseMode) ...[
            Container(
              key: const ValueKey('paywall-debug-banner'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.errorColor, width: 1.5),
              ),
              child: Text(
                s.debugBanner,
                textAlign: TextAlign.center,
                style: t.text(size: 11, color: t.errorColor),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.hero != null) ...[
            widget.hero!,
            const SizedBox(height: 10),
          ],
          Text(
            unlocked ? s.alreadyUnlocked : s.paywallTitle,
            textAlign: TextAlign.center,
            style: t.text(
              size: 20,
              weight: FontWeight.w900,
              color: t.accentDeep,
            ),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 6),
            Text(
              s.paywallLead,
              textAlign: TextAlign.center,
              style: t.text(size: 14, height: 1.5),
            ),
          ],
          if (widget.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.panelColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in widget.features)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              f.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              f.text,
                              style: t.text(size: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (unlocked)
            PurchaseButton(
              key: const ValueKey('paywall-close-unlocked'),
              label: s.close,
              theme: t,
              big: true,
              color: t.successColor,
              onTap: widget.onClose,
            )
          else ...[
            PurchaseButton(
              key: const ValueKey('paywall-buy'),
              label: price == null
                  ? (_svc.storeAvailable.value || simulating
                        ? s.loadingPrice
                        : s.buy)
                  : s.buyWithPrice.replaceAll('{price}', price),
              theme: t,
              big: true,
              busy: _busy == _Busy.buy || pending,
              onTap: _busy == _Busy.none && !pending ? _buy : null,
            ),
            const SizedBox(height: 6),
            Text(
              s.oneTimeNote,
              textAlign: TextAlign.center,
              style: t.text(size: 11, weight: FontWeight.w700, color: t.muted),
            ),
          ],
          if (_message != null || pending) ...[
            const SizedBox(height: 10),
            Text(
              _message ?? s.pending,
              key: const ValueKey('paywall-message'),
              textAlign: TextAlign.center,
              style: t.text(
                size: 13,
                weight: FontWeight.w700,
                height: 1.5,
                color: _messageIsError ? t.errorColor : t.ink,
              ),
            ),
            if (_canRetry && !unlocked)
              Align(
                child: TextButton(
                  onPressed: _busy == _Busy.none
                      ? () async {
                          await _svc.refresh();
                          await _buy();
                        }
                      : null,
                  child: Text(s.retry, style: t.text(color: t.accent)),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PurchaseButton(
                  key: const ValueKey('paywall-restore'),
                  label: s.restore,
                  theme: t,
                  color: t.panelColor,
                  textColor: t.accentDeep,
                  busy: _busy == _Busy.restore,
                  onTap: _busy == _Busy.none ? _restore : null,
                ),
              ),
              if (showRedeem && !unlocked) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PurchaseButton(
                    key: const ValueKey('paywall-redeem'),
                    label: s.redeem,
                    theme: t,
                    color: t.panelColor,
                    textColor: t.accentDeep,
                    busy: _busy == _Busy.redeem,
                    onTap: _busy == _Busy.none ? _redeem : null,
                  ),
                ),
              ],
            ],
          ),
          if (widget.termsUrl != null || widget.privacyUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (widget.termsUrl != null)
                  TextButton(
                    onPressed: () => _open(widget.termsUrl!),
                    child: Text(
                      s.terms,
                      style: t
                          .text(size: 12, color: t.muted)
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                if (widget.privacyUrl != null)
                  TextButton(
                    onPressed: () => _open(widget.privacyUrl!),
                    child: Text(
                      s.privacy,
                      style: t
                          .text(size: 12, color: t.muted)
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
              ],
            ),
          ],
          if (!unlocked && widget.onClose != null)
            Align(
              child: TextButton(
                key: const ValueKey('paywall-close'),
                onPressed: widget.onClose,
                child: Text(s.close, style: t.text(color: t.muted)),
              ),
            ),
        ],
      ),
    );
  }
}
