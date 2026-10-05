import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/stage_pack.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../services/teen_store.dart';
import '../../widgets/common.dart';
import 'result_view.dart';
import 'stage_fx.dart';
import 'stage_widgets.dart';

Route<void> stageRoute(String packId, [RouteSettings? settings]) => PageRouteBuilder<void>(
      settings: settings ?? RouteSettings(name: '/$packId'),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, a, b) => StageScreen(packId: packId),
      transitionsBuilder: (context, a, b, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(c), child: child),
        );
      },
    );

/// Screenshot-test builds only (`--dart-define=TEEN_TEST_ANSWER_FIRST=true`):
/// the correct answer is always the top-left button. Off in real builds.
const _testAnswerFirst = bool.fromEnvironment('TEEN_TEST_ANSWER_FIRST');

enum Phase { loading, start, level, countdown, play, end }

/// One of the 21 stage pages. Gameplay mirrors the web engine exactly:
/// pick a level → 3-2-1-GO → up to 15 questions (5 s each, 3 lives).
/// Correct: 100 + ⌊(5000 − ms)/50⌋ + (combo ≥ 3 ? combo × 10 : 0), next
/// question after 1.4 s. Miss / timeout: −1 life, explosion, explanation
/// sheet, "つぎへ". Rank by score: S ≥ 1800, A ≥ 1400, B ≥ 900, C ≥ 500.
class StageScreen extends StatefulWidget {
  const StageScreen({super.key, required this.packId});
  final String packId;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> with TickerProviderStateMixin {
  final _rng = math.Random();
  final _timers = <Timer>[];

  StagePack? _pack;
  double _artAspect = 941 / 1672;
  Phase _phase = Phase.loading;

  // ---- web `state`
  int _score = 0, _lives = 3, _qIndex = 0, _combo = 0, _maxCombo = 0;
  int _total = 15;
  List<Problem> _queue = const [];
  bool _locked = true;
  String _level = 'Lv1';

  // ---- current question view
  String _question = '';
  List<String> _choices = const [];
  List<ChoiceMark> _marks = const [];
  bool _choicesEnabled = false;

  // ---- fx state
  late final Ticker _ticker = createTicker(_onTick);
  final _clock = Stopwatch();
  final _orbScale = ValueNotifier<double>(1);
  OrbState _orb = OrbState.normal;
  Mood _mood = Mood.normal;
  int _moodSerial = 0, _explodeSerial = 0, _comboSerial = 0;
  int _tickedAt = 0;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400), value: 1);

  // ---- overlays
  String _count = '3';
  bool _explain = false;
  Problem? _explainFor;
  bool _newBest = false;
  Map<String, String> _bestRanks = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pack = await StagePack.load(widget.packId);
    if (!mounted) return;
    final art = pack.images.artAsset;
    if (art != null) {
      _artAspect = await _aspectOf(art) ?? _artAspect;
    }
    if (!mounted) return;
    // Decode the art used during play up front (no pop-in on first use).
    for (final a in [
      ?art,
      ?pack.images.bossAsset,
      pack.images.charaAsset('normal'),
      pack.images.charaAsset('asette'),
      pack.images.charaAsset('dame'),
      ?pack.images.winAsset,
      ?pack.images.loseAsset,
    ]) {
      unawaited(precacheImage(AssetImage(a), context));
    }
    unawaited(AudioService.instance.preload());
    await _loadBest(pack);
    if (!mounted) return;
    setState(() {
      _pack = pack;
      _question = pack.label; // web placeholder: the stage kanji
      _phase = Phase.start;
    });
  }

  Future<void> _loadBest(StagePack pack) async {
    final m = <String, String>{};
    for (final lv in pack.levels.keys) {
      final r = await ProgressService.instance.bestRank(pack.id, lv);
      if (r != null) m[lv] = r;
    }
    _bestRanks = m;
  }

  static Future<double?> _aspectOf(String asset) {
    final done = Completer<double?>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (!done.isCompleted) done.complete(info.image.width / info.image.height);
      stream.removeListener(l);
    }, onError: (e, _) {
      if (!done.isCompleted) done.complete(null);
      stream.removeListener(l);
    });
    stream.addListener(l);
    return done.future;
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _ticker.dispose();
    _shake.dispose();
    _orbScale.dispose();
    super.dispose();
  }

  void _after(int ms, VoidCallback f) {
    late final Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (mounted) f();
    });
    _timers.add(t);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  // ================================================================ flow

  /// Web startGame(): start jingle, BGM, level select.
  void _startGame() {
    final a = AudioService.instance;
    a.playStart();
    a.startBgm();
    _cancelTimers();
    setState(() {
      _phase = Phase.level;
      _explain = false;
    });
  }

  /// Web chooseLevel(lv).
  void _chooseLevel(String lv) {
    final pack = _pack!;
    final active = pack.levels[lv] ?? const <Problem>[];
    _level = lv;
    _total = math.max(1, math.min(pack.maxQuestions, active.length));
    // resetState()
    _score = 0;
    _lives = 3;
    _qIndex = 0;
    _combo = 0;
    _maxCombo = 0;
    _queue = ([...active]..shuffle(_rng)).take(_total).toList();
    _locked = false;
    setState(() => _phase = Phase.countdown);
    _runCountdown(0);
  }

  /// Web runCountdown(): '3','2','1','GO!' every 500 ms with beeps.
  void _runCountdown(int i) {
    const seq = ['3', '2', '1', 'GO!'];
    if (i >= seq.length) {
      setState(() => _phase = Phase.play);
      _loadQuestion();
      return;
    }
    setState(() => _count = seq[i]);
    AudioService.instance.playBeep(seq[i] == 'GO!');
    _after(500, () => _runCountdown(i + 1));
  }

  /// Web loadQuestion().
  void _loadQuestion() {
    if (_qIndex >= _total || _lives <= 0) {
      _endGame();
      return;
    }
    final p = _queue[_qIndex];
    var choices = [...p.choices]..shuffle(_rng);
    if (_testAnswerFirst && choices.remove(p.a)) choices.insert(0, p.a);
    if (choices.length > 4) {
      // the web has 4 buttons; keep the answer among them.
      final four = choices.take(4).toList();
      if (!four.contains(p.a) && choices.contains(p.a)) {
        four[_rng.nextInt(4)] = p.a;
      }
      choices = four;
    }
    setState(() {
      _question = p.q;
      _choices = choices;
      _marks = List.filled(choices.length, ChoiceMark.none);
      _choicesEnabled = true;
      _locked = false;
      _mood = Mood.normal;
      _orb = OrbState.normal;
    });
    _orbScale.value = 1;
    _tickedAt = 0;
    _startTimer();
  }

  void _startTimer() {
    _ticker.stop();
    _clock
      ..reset()
      ..start();
    _ticker.start();
  }

  void _stopTimer() {
    _ticker.stop();
    _clock.stop();
  }

  /// Web tick(now) — runs every frame while a question is open.
  void _onTick(Duration _) {
    if (_locked) return;
    final limit = _pack!.timeLimitMs;
    final elapsed = _clock.elapsedMicroseconds / 1000;
    final remaining = (limit - elapsed) / 1000;
    final ratio = math.min(elapsed / limit, 1.0);
    _orbScale.value = 1 + ratio * .6;

    if (remaining <= 3 && remaining > 0) {
      final whole = remaining.ceil();
      if (whole != _tickedAt && whole <= 3) {
        AudioService.instance.playTick();
        _tickedAt = whole;
      }
    }
    var orb = _orb, mood = _mood;
    if (ratio > .65) orb = OrbState.danger;
    if (remaining <= 3 && remaining > 0) {
      mood = Mood.danger;
    } else if (remaining > 3) {
      mood = Mood.normal;
    }
    if (orb != _orb || mood != _mood) {
      setState(() {
        _orb = orb;
        _mood = mood;
      });
    }
    if (ratio >= 1) _timeout();
  }

  /// Web answer(val, btn).
  void _answer(int i) {
    if (_locked) return;
    _locked = true;
    final elapsed = _clock.elapsedMilliseconds;
    _stopTimer();
    final p = _queue[_qIndex];
    final a = AudioService.instance;
    final marks = [..._marks];
    final ok = _choices[i] == p.a;
    if (ok) {
      marks[i] = ChoiceMark.correct;
      a.playCorrect();
      HapticFeedback.lightImpact(); // app extra
      _combo++;
      _maxCombo = math.max(_maxCombo, _combo);
      final timeBonus = math.max(0, ((_pack!.timeLimitMs - elapsed) / 50).floor());
      final comboBonus = _combo >= 3 ? _combo * 10 : 0;
      _score += 100 + timeBonus + comboBonus;
      if (_combo >= 3) _comboSerial++;
      _setMood(Mood.happy);
    } else {
      marks[i] = ChoiceMark.wrong;
      a.playWrong();
      for (var k = 0; k < _choices.length; k++) {
        if (_choices[k] == p.a) marks[k] = ChoiceMark.correct;
      }
      _combo = 0;
      _lives--;
      _explode();
      _setMood(Mood.shocked);
    }
    setState(() {
      _marks = marks;
      _choicesEnabled = false;
    });
    if (ok) {
      _after(1400, _nextQuestion);
    } else {
      _showExplain(p);
    }
  }

  /// Web timeout().
  void _timeout() {
    if (_locked) return;
    _locked = true;
    _stopTimer();
    final p = _queue[_qIndex];
    final marks = [..._marks];
    for (var k = 0; k < _choices.length; k++) {
      if (_choices[k] == p.a) marks[k] = ChoiceMark.correct;
    }
    _combo = 0;
    _lives--;
    _explode();
    _setMood(Mood.shocked);
    setState(() {
      _marks = marks;
      _choicesEnabled = false;
    });
    _showExplain(p);
  }

  void _setMood(Mood m) {
    _mood = m;
    _moodSerial++;
  }

  /// Web explodeBalloon(): orb burst, BOOM!, screen shake.
  void _explode() {
    AudioService.instance.playBoom();
    HapticFeedback.heavyImpact(); // app extra: miss / timeout
    _orb = OrbState.exploded;
    _explodeSerial++;
    _shake.forward(from: 0);
  }

  void _showExplain(Problem p) {
    setState(() {
      _explainFor = p;
      _explain = true;
    });
  }

  /// Web nextQuestion().
  void _nextQuestion() {
    if (_phase != Phase.play) return;
    setState(() => _explain = false);
    _qIndex++;
    _loadQuestion();
  }

  /// Web endGame().
  Future<void> _endGame() async {
    _stopTimer();
    final a = AudioService.instance;
    if (_lives > 0) {
      a.playVictory();
    } else {
      a.playLose();
    }
    final (rank, _) = rankFor(_score);
    setState(() {
      _phase = Phase.end;
      _newBest = false;
    });
    final pack = _pack!;
    final isNew = await ProgressService.instance.recordGame(
      page: pack.id,
      level: _level,
      score: _score,
      rank: rank,
    );
    await _loadBest(pack);
    if (mounted) setState(() => _newBest = isNew);
  }

  void _back() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed('/');
    }
  }

  // ============================================================== build

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final size = MediaQuery.sizeOf(context);
    final metrics = StageMetrics(size.height <= 680);
    if (pack == null) {
      return const Scaffold(body: ArkBackground(child: SizedBox.expand()));
    }
    final imgs = pack.images;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ArkBackground(
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: _shake.isAnimating ? shakeOffset(_shake.value) : Offset.zero,
            child: child,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _game(pack, metrics, pad),
              Positioned.fill(
                child: ExplainSheet(
                  show: _explain && _phase == Phase.play,
                  answer: _explainFor?.a ?? '',
                  body: _explainFor?.e ?? '正解をかくにんしよう！',
                  onNext: _nextQuestion,
                ),
              ),
              // One backdrop for start / level / result so switching between
              // them never lets the game show through mid-fade.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _phase == Phase.start || _phase == Phase.level || _phase == Phase.end
                        ? 1
                        : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const OverlayPanel(child: SizedBox.expand()),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _overlay(pack, imgs, metrics, pad),
                ),
              ),
              if (_phase == Phase.countdown)
                Positioned.fill(
                  child: OverlayPanel(
                    blur: 10,
                    color: const Color(0xF00D1626),
                    child: Center(
                      child: CountdownNumber(text: _count, size: metrics.countdown),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(StagePack pack, StageImages imgs, StageMetrics metrics, EdgeInsets pad) {
    Widget withBack(Widget child) => Stack(
          children: [
            Positioned.fill(child: child),
            // App addition: a way back on screens where the web relies on
            // the browser's back button.
            Positioned(top: pad.top + 10, left: 14, child: BackPill(onTap: _back)),
          ],
        );
    switch (_phase) {
      case Phase.start:
        final art = imgs.artAsset;
        return KeyedSubtree(
          key: const ValueKey('start'),
          child: art != null
              ? withBack(Padding(
                  padding: EdgeInsets.fromLTRB(6, 6 + pad.top, 6, 6 + pad.bottom),
                  child: StartArt(art: art, aspect: _artAspect, onStart: _startGame),
                ))
              : StartPlain(
                  metrics: metrics,
                  title: pack.title,
                  label: pack.label,
                  boss: imgs.bossAsset,
                  fighter: imgs.charaAsset('normal'),
                  onStart: _startGame,
                  onBack: _back,
                ),
        );
      case Phase.level:
        return KeyedSubtree(
          key: const ValueKey('level'),
          child: withBack(ListenableBuilder(
            listenable: TeenStore.access,
            builder: (context, _) => LevelSelect(
              levels: {for (final e in pack.levels.entries) e.key: e.value.length},
              best: _bestRanks,
              onPick: _chooseLevel,
              isLocked: (i, level) => TeenStore.access.isLocked(pack.id, i, group: level),
              onLocked: () => TeenStore.openPaywall(context),
            ),
          )),
        );
      case Phase.end:
        return KeyedSubtree(
          key: const ValueKey('end'),
          child: ResultView(
            score: _score,
            maxCombo: _maxCombo,
            image: _lives > 0 ? imgs.winAsset : imgs.loseAsset,
            newBest: _newBest,
            onMenu: _back,
            onRetry: _startGame,
          ),
        );
      default:
        return const SizedBox.shrink(key: ValueKey('none'));
    }
  }

  Widget _game(StagePack pack, StageMetrics m, EdgeInsets pad) {
    final imgs = pack.images;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, pad.top, 16, pad.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // .hud (margin-top 30, padding 8 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 30 + 8, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: HudBox(label: 'SCORE', value: '$_score')),
                        const SizedBox(width: 8),
                        Hearts(lives: _lives),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HudBox(
                            label: '問題',
                            value: '${_phase == Phase.play || _phase == Phase.end ? _qIndex + 1 : 0}/$_total',
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // .stage — painted over the HUD when the orb grows
                  SizedBox(
                    height: m.stageH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: 5,
                          child: EnergyOrb(
                            scale: _orbScale,
                            state: _orb,
                            explodeSerial: _explodeSerial,
                            width: m.orb.width,
                            height: m.orb.height,
                          ),
                        ),
                        Positioned(top: m.stageH / 2, left: 0, right: 0, child: Center(child: Burst(serial: _explodeSerial))),
                        Positioned(
                          top: m.stageH * .4 - 37,
                          left: -100,
                          right: -100,
                          child: Center(child: BoomText(serial: _explodeSerial)),
                        ),
                        Positioned(
                          bottom: 5,
                          child: Transform.translate(
                            offset: const Offset(-.5, 0),
                            child: Fighter(
                              mood: _mood,
                              serial: _moodSerial,
                              normal: imgs.charaAsset('normal'),
                              danger: imgs.charaAsset('asette'),
                              shocked: imgs.charaAsset('dame'),
                              width: m.fighter.width,
                              height: m.fighter.height,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      // keep at least two rows of answer buttons visible
                      const minChoices = 2 * 62.0 + 10;
                      final maxQ = math.max(80.0, c.maxHeight - 14 - minChoices);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuestionArea(
                            text: _question,
                            combo: _combo,
                            comboSerial: _comboSerial,
                            maxHeight: maxQ,
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: _choiceGrid()),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            Positioned(top: pad.top, left: 14, child: BackPill(onTap: _back)),
          ],
        ),
      ),
    );
  }

  Widget _choiceGrid() {
    Widget cell(int i) => Expanded(
          child: i < _choices.length
              ? ChoiceButton(
                  key: ValueKey('c$i'),
                  text: _choices[i],
                  mark: _marks[i],
                  enabled: _choicesEnabled && !_locked,
                  onTap: () => _answer(i),
                )
              : ChoiceButton(
                  key: ValueKey('c$i'),
                  text: '',
                  mark: ChoiceMark.none,
                  enabled: false,
                  onTap: () {},
                ),
        );
    return Column(
      children: [
        Expanded(child: Row(children: [cell(0), const SizedBox(width: 10), cell(1)])),
        const SizedBox(height: 10),
        Expanded(child: Row(children: [cell(2), const SizedBox(width: 10), cell(3)])),
      ],
    );
  }
}
