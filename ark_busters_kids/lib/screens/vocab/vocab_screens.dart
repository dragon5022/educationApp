import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/content/vocab_pack.dart';
import '../../core/progress/progress_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/content_repository.dart';
import '../../services/progress_service.dart';
import '../../widgets/page_background.dart';

/// Vocabulary Busters — grade → level → battle → result (web parity).
class VocabHomeScreen extends StatefulWidget {
  const VocabHomeScreen({super.key});

  @override
  State<VocabHomeScreen> createState() => _VocabHomeScreenState();
}

class _VocabHomeScreenState extends State<VocabHomeScreen> {
  VocabPack? _pack;
  int _kyu = 5;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ContentRepository.instance.init();
      final pack =
          ContentRepository.instance.vocab ?? await ContentRepository.instance.loadVocab();
      if (!mounted) return;
      setState(() => _pack = pack);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _startLevel(int level) {
    final pack = _pack;
    if (pack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VocabBattleScreen(
          pack: pack,
          kyu: _kyu,
          level: level,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'ボキャブラリーバスター',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
                )
              else if (_pack == null)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
              else ...[
                const SizedBox(height: 8),
                Text(
                  '英検 ${_kyu}級',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [5, 4, 3].map((k) {
                    final on = _kyu == k;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        label: Text('$k級'),
                        selected: on,
                        onSelected: (_) => setState(() => _kyu = k),
                        selectedColor: AppColors.purple,
                        labelStyle: TextStyle(
                          color: on ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'レベルをえらんでね',
                  style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _LevelCard(
                        title: 'レベル1　絵を見て4択',
                        subtitle: '5びょう',
                        color: AppColors.purple,
                        onTap: () => _startLevel(1),
                      ),
                      _LevelCard(
                        title: 'レベル2　スペル3択',
                        subtitle: '7びょう',
                        color: AppColors.blue,
                        onTap: () => _startLevel(2),
                      ),
                      _LevelCard(
                        title: 'レベル3　もじをならべる',
                        subtitle: '10びょう',
                        color: AppColors.orange,
                        onTap: () => _startLevel(3),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(subtitle, style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: color, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VocabBattleScreen extends StatefulWidget {
  const VocabBattleScreen({
    super.key,
    required this.pack,
    required this.kyu,
    required this.level,
  });

  final VocabPack pack;
  final int kyu;
  final int level;

  @override
  State<VocabBattleScreen> createState() => _VocabBattleScreenState();
}

class _VocabBattleScreenState extends State<VocabBattleScreen> {
  final _rng = Random();
  late List<VocabItem> _questions;
  late int _timeLimit;
  int _qi = 0;
  int _score = 0;
  int _correct = 0;
  bool _locked = false;
  double _tleft = 0;
  Timer? _timer;
  List<String> _choices = [];
  List<String> _letterPool = [];
  final List<String> _built = [];

  VocabItem get _q => _questions[_qi];

  @override
  void initState() {
    super.initState();
    AudioService.instance.playBattleBgm();
    AudioService.instance.playSfx('start');
    _timeLimit = widget.pack.timeByLevel[widget.level] ?? 5;
    var pool = widget.pack.forGrade(widget.kyu);
    if (widget.level == 3) {
      pool = pool
          .where((e) => RegExp(r'^[a-zA-Z]+$').hasMatch(e.w) && e.w.length <= 8)
          .toList();
    }
    pool = List.of(pool)..shuffle(_rng);
    _questions = pool.take(widget.pack.qn).toList();
    if (_questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }
    _prepareQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    AudioService.instance.playHubBgm();
    super.dispose();
  }

  void _prepareQuestion() {
    _locked = false;
    _built.clear();
    final q = _q;
    if (widget.level == 1) {
      final others = widget.pack.items.where((e) => e.w != q.w).toList()..shuffle(_rng);
      _choices = [q.w, ...others.take(3).map((e) => e.w)]..shuffle(_rng);
    } else if (widget.level == 2) {
      _choices = [q.w, _misspell(q.w), _misspell(q.w)]..shuffle(_rng);
    } else {
      final letters = q.w.toLowerCase().split('');
      final extras = 'abcdefghijklmnopqrstuvwxyz'.split('')..shuffle(_rng);
      _letterPool = [...letters, ...extras.take(max(2, 10 - letters.length))]..shuffle(_rng);
    }
    AudioService.instance.playVoiceAsset(q.voice);
    _startTimer();
    setState(() {});
  }

  String _misspell(String w) {
    if (w.length < 2) return '${w}x';
    final chars = w.split('');
    final i = _rng.nextInt(chars.length - 1);
    final tmp = chars[i];
    chars[i] = chars[i + 1];
    chars[i + 1] = tmp;
    final out = chars.join();
    return out == w ? '${w}e' : out;
  }

  void _startTimer() {
    _timer?.cancel();
    _tleft = _timeLimit.toDouble();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      _tleft -= 0.1;
      if (_tleft <= 0) {
        t.cancel();
        _answer(false);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _answer(bool ok, {String? picked}) async {
    if (_locked) return;
    _locked = true;
    _timer?.cancel();
    if (ok) {
      _score += 100;
      _correct++;
      await AudioService.instance.playSfx('correct');
    } else {
      await AudioService.instance.playSfx('start', volume: 0.4);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? '⭕ せいかい！' : '❌ おしい…'),
        content: Text('${_q.w}\n${_q.ja}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AudioService.instance.playVoiceAsset(_q.voice);
            },
            child: const Text('きく'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('つぎへ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (_qi + 1 >= _questions.length) {
      await _finish();
    } else {
      _qi++;
      _prepareQuestion();
    }
  }

  Future<void> _finish() async {
    final win = _correct >= (_questions.length * widget.pack.winRatio).ceil();
    await AudioService.instance.playSfx(win ? 'clear' : 'gameover');
    await ProgressService.instance.setBestIfHigher(
      ProgressKeys.bestVocabulary,
      _score,
    );
    String rank;
    if (_correct >= 10) {
      rank = 'S';
    } else if (_correct >= 9) {
      rank = 'A';
    } else if (_correct >= 8) {
      rank = 'B';
    } else if (_correct >= 6) {
      rank = 'C';
    } else if (_correct >= 4) {
      rank = 'D';
    } else if (_correct >= 2) {
      rank = 'E';
    } else {
      rank = 'F';
    }
    if (win) await ProgressService.instance.befriend('vocamon');
    if (rank == 'S') await ProgressService.instance.addSRank('vocamon');

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VocabResultScreen(
          score: _score,
          correct: _correct,
          total: _questions.length,
          rank: rank,
          win: win,
        ),
      ),
    );
  }

  void _tapLetter(String ch, int index) {
    if (_locked) return;
    setState(() {
      _built.add(ch);
      _letterPool.removeAt(index);
    });
    if (_built.join() == _q.w.toLowerCase()) {
      _answer(true);
    } else if (_built.length >= _q.w.length) {
      _answer(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('もんだいがありません')));
    }
    final progress = (_tleft / _timeLimit).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1147),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        final leave = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('とちゅうでやめる？　いまのスコアはきえるよ'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('やめる'),
                              ),
                            ],
                          ),
                        );
                        if (leave == true && context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        '${_qi + 1} / ${_questions.length}　SCORE $_score',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => AudioService.instance.playVoiceAsset(_q.voice),
                      icon: const Icon(Icons.volume_up, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _q.ja,
                style: const TextStyle(color: AppColors.cream, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (widget.level == 1) ...[
                SizedBox(
                  height: 140,
                  child: _q.img != null
                      ? Image.asset(
                          'assets/${_q.img}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white54, size: 64),
                        )
                      : const Icon(Icons.image, color: Colors.white54, size: 64),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: _choices
                        .map(
                          (c) => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                            ),
                            onPressed: _locked ? null : () => _answer(c == _q.w, picked: c),
                            child: Text(c, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ] else if (widget.level == 2) ...[
                const Text('ただしいスペルは？', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ..._choices.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _locked ? null : () => _answer(c == _q.w, picked: c),
                        child: Text(c, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ] else ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(
                    _built.join(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 6,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (var i = 0; i < _letterPool.length; i++)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: ElevatedButton(
                            onPressed: _locked ? null : () => _tapLetter(_letterPool[i], i),
                            child: Text(
                              _letterPool[i].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              Image.asset(
                'assets/images/monsters/vocamon/vocamon-friend.png',
                height: 90,
                errorBuilder: (_, __, ___) => const SizedBox(height: 90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VocabResultScreen extends StatelessWidget {
  const VocabResultScreen({
    super.key,
    required this.score,
    required this.correct,
    required this.total,
    required this.rank,
    required this.win,
  });

  final int score;
  final int correct;
  final int total;
  final String rank;
  final bool win;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    win ? 'クリア！' : 'ざんねん…',
                    style: const TextStyle(color: AppColors.gold, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RANK $rank',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SCORE $score　（$correct/$total）',
                    style: const TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    win
                        ? 'assets/images/monsters/vocamon/vocamon-happy.png'
                        : 'assets/images/monsters/vocamon/vocamon-sad.png',
                    height: 140,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 140),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('ハブにもどる', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
