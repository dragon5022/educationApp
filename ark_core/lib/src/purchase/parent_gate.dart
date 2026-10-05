import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'purchase_theme.dart';

/// Kinds of adult-level questions used by the parent gate.
enum ParentGateChallenge {
  /// A 5-digit number written in kanji with 万, e.g. 四万七千八十二 → 47082.
  kanjiNumber,

  /// Two-digit × two-digit multiplication, e.g. 23 × 17 → 391.
  multiplication,
}

/// One gate question and its expected digits.
@immutable
class ParentGateQuestion {
  const ParentGateQuestion({
    required this.instruction,
    required this.prompt,
    required this.answer,
  });

  /// Adult-facing instruction (kanji OK).
  final String instruction;

  /// The big text to solve.
  final String prompt;

  /// Expected answer as digits.
  final String answer;

  static ParentGateQuestion generate(
    Random random, [
    Set<ParentGateChallenge> kinds = const {
      ParentGateChallenge.kanjiNumber,
      ParentGateChallenge.multiplication,
    },
  ]) {
    final list = kinds.isEmpty
        ? ParentGateChallenge.values
        : kinds.toList(growable: false);
    switch (list[random.nextInt(list.length)]) {
      case ParentGateChallenge.kanjiNumber:
        final digits = [
          1 + random.nextInt(9),
          for (var i = 0; i < 4; i++)
            random.nextInt(10) < 3 ? 0 : 1 + random.nextInt(9),
        ];
        final n = int.parse(digits.join());
        return ParentGateQuestion(
          instruction: '次の数を、算用数字（0〜9）で入力してください。',
          prompt: toKanjiNumber(n),
          answer: '$n',
        );
      case ParentGateChallenge.multiplication:
        int pick(int lo, int hi) {
          while (true) {
            final v = lo + random.nextInt(hi - lo + 1);
            if (v % 10 != 0 && v % 11 != 0) return v;
          }
        }
        final a = pick(13, 49);
        final b = pick(12, 29);
        return ParentGateQuestion(
          instruction: '次の計算の答えを入力してください。',
          prompt: '$a × $b = ?',
          answer: '${a * b}',
        );
    }
  }

  /// 0 < n < 100000000 → 漢数字 (1 is omitted before 十/百/千, kept before 万).
  static String toKanjiNumber(int n) {
    assert(n > 0 && n < 100000000);
    const d = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    String under10k(int v) {
      final sb = StringBuffer();
      const units = [(1000, '千'), (100, '百'), (10, '十')];
      for (final (u, k) in units) {
        final q = (v ~/ u) % 10;
        if (q == 0) continue;
        if (q > 1) sb.write(d[q]);
        sb.write(k);
      }
      final ones = v % 10;
      if (ones > 0) sb.write(d[ones]);
      return sb.toString();
    }

    final man = n ~/ 10000;
    final rest = n % 10000;
    final sb = StringBuffer();
    if (man > 0) {
      sb.write(man == 1 ? '一' : under10k(man));
      sb.write('万');
    }
    sb.write(under10k(rest));
    return sb.toString();
  }
}

/// Text for the gate. The kid-facing lead is hiragana; the question itself
/// is written for adults.
@immutable
class ParentGateStrings {
  const ParentGateStrings({
    this.title = 'おうちの方へ',
    this.kidLead = 'ここから さきは おうちの ひとに わたしてね。',
    this.adultLead = 'この先は保護者の方の確認が必要です（購入・外部サイトへの移動など）。',
    this.ok = 'OK',
    this.cancel = 'やめる',
    this.wrong = 'ちがいます。新しい問題に答えてください。',
    this.locked = '回答を続けて間違えたため、しばらくお待ちください（あと {s} 秒）。',
  });

  final String title;
  final String kidLead;
  final String adultLead;
  final String ok;
  final String cancel;
  final String wrong;

  /// `{s}` → remaining seconds.
  final String locked;
}

DateTime? _gateLockedUntil;
int _gateFailures = 0;

/// Resets the cross-dialog lockout (tests only).
@visibleForTesting
void debugResetParentGate() {
  _gateLockedUntil = null;
  _gateFailures = 0;
}

/// Shows the parent gate. Resolves `true` only when the adult answered
/// correctly; `false` on cancel.
///
/// Design: no "remember me", a new random question each try, a shuffled
/// on-screen keypad (no muscle memory / no system keyboard), and a lockout
/// after [maxAttempts] wrong answers that survives closing and reopening
/// the dialog (kept for the app session).
Future<bool> showParentGate(
  BuildContext context, {
  PurchaseTheme theme = PurchaseTheme.kids,
  ParentGateStrings strings = const ParentGateStrings(),
  Set<ParentGateChallenge> challenges = const {
    ParentGateChallenge.kanjiNumber,
    ParentGateChallenge.multiplication,
  },
  int maxAttempts = 3,
  Duration lockout = const Duration(seconds: 30),
  Random? random,
  @visibleForTesting ParentGateQuestion Function()? questionFactory,
}) async {
  final r = await showPurchaseDialog<bool>(
    context: context,
    theme: theme,
    builder: (_) => ParentGateDialog(
      theme: theme,
      strings: strings,
      challenges: challenges,
      maxAttempts: maxAttempts,
      lockout: lockout,
      random: random,
      questionFactory: questionFactory,
    ),
  );
  return r ?? false;
}

/// The gate's content; pops `true`/`false`. Usually shown via
/// [showParentGate].
class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({
    super.key,
    this.theme = PurchaseTheme.kids,
    this.strings = const ParentGateStrings(),
    this.challenges = const {
      ParentGateChallenge.kanjiNumber,
      ParentGateChallenge.multiplication,
    },
    this.maxAttempts = 3,
    this.lockout = const Duration(seconds: 30),
    this.random,
    this.questionFactory,
  });

  final PurchaseTheme theme;
  final ParentGateStrings strings;
  final Set<ParentGateChallenge> challenges;
  final int maxAttempts;
  final Duration lockout;
  final Random? random;
  final ParentGateQuestion Function()? questionFactory;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  late final Random _rng = widget.random ?? Random.secure();
  late ParentGateQuestion _q;
  late List<int> _keys;
  String _input = '';
  bool _wrong = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _next();
    _startTickerIfLocked();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _next() {
    _q =
        widget.questionFactory?.call() ??
        ParentGateQuestion.generate(_rng, widget.challenges);
    _keys = List.generate(10, (i) => i)..shuffle(_rng);
    _input = '';
  }

  int get _lockSeconds {
    final until = _gateLockedUntil;
    if (until == null) return 0;
    final s = until.difference(DateTime.now()).inMilliseconds;
    return s <= 0 ? 0 : (s / 1000).ceil();
  }

  void _startTickerIfLocked() {
    if (_lockSeconds <= 0) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) return;
      if (_lockSeconds <= 0) {
        t.cancel();
        _gateLockedUntil = null;
      }
      setState(() {});
    });
  }

  void _tapDigit(int d) {
    if (_lockSeconds > 0 || _input.length >= 6) return;
    setState(() {
      _input += '$d';
      _wrong = false;
    });
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_lockSeconds > 0 || _input.isEmpty) return;
    if (_input == _q.answer) {
      _gateFailures = 0;
      Navigator.of(context).pop(true);
      return;
    }
    HapticFeedback.heavyImpact();
    _gateFailures++;
    setState(() {
      _wrong = true;
      if (_gateFailures >= widget.maxAttempts) {
        _gateFailures = 0;
        _gateLockedUntil = DateTime.now().add(widget.lockout);
        _startTickerIfLocked();
      }
      _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.strings;
    final locked = _lockSeconds;
    return PurchaseSheet(
      theme: t,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🔒 ${s.title}',
            textAlign: TextAlign.center,
            style: t.text(size: 20, color: t.accentDeep),
          ),
          const SizedBox(height: 6),
          Text(
            s.kidLead,
            textAlign: TextAlign.center,
            style: t.text(size: 14, color: t.ink, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            s.adultLead,
            textAlign: TextAlign.center,
            style: t.text(
              size: 11.5,
              weight: FontWeight.w600,
              color: t.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: t.panelColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _q.instruction,
                  textAlign: TextAlign.center,
                  style: t.text(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: t.muted,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _q.prompt,
                    key: const ValueKey('parent-gate-prompt'),
                    style: t.text(size: 28, weight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _wrong ? t.errorColor : t.borderColor,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _input.isEmpty ? '—' : _input,
                    key: const ValueKey('parent-gate-input'),
                    style: t.text(
                      size: 24,
                      weight: FontWeight.w900,
                      color: _input.isEmpty ? t.muted : t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_wrong || locked > 0) ...[
            const SizedBox(height: 8),
            Text(
              locked > 0 ? s.locked.replaceAll('{s}', '$locked') : s.wrong,
              key: const ValueKey('parent-gate-message'),
              textAlign: TextAlign.center,
              style: t.text(
                size: 12.5,
                weight: FontWeight.w700,
                color: t.errorColor,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _keypad(t, s, enabled: locked == 0),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PurchaseButton(
                  key: const ValueKey('parent-gate-cancel'),
                  label: s.cancel,
                  theme: t,
                  color: t.secondaryButton,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PurchaseButton(
                  key: const ValueKey('parent-gate-ok'),
                  label: s.ok,
                  theme: t,
                  onTap: locked == 0 && _input.isNotEmpty ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keypad(
    PurchaseTheme t,
    ParentGateStrings s, {
    required bool enabled,
  }) {
    Widget key(String label, VoidCallback onTap, {Key? k}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: t.panelColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: k,
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onTap : null,
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    label,
                    style: t.text(size: 20, weight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final rows = <Widget>[];
    for (var r = 0; r < 3; r++) {
      rows.add(
        Row(
          children: [
            for (var c = 0; c < 3; c++)
              key(
                '${_keys[r * 3 + c]}',
                () => _tapDigit(_keys[r * 3 + c]),
                k: ValueKey('parent-gate-digit-${_keys[r * 3 + c]}'),
              ),
          ],
        ),
      );
    }
    rows.add(
      Row(
        children: [
          const Expanded(child: SizedBox()),
          key(
            '${_keys[9]}',
            () => _tapDigit(_keys[9]),
            k: ValueKey('parent-gate-digit-${_keys[9]}'),
          ),
          key('⌫', _backspace, k: const ValueKey('parent-gate-backspace')),
        ],
      ),
    );
    return Column(children: rows);
  }
}
