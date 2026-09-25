import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/content/game_packs.dart';
import '../../core/progress/progress_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/content_repository.dart';
import '../../services/progress_service.dart';
import '../../widgets/page_background.dart';

/// Talk modes: 2=imitate, 1=quiz (4-choice). Mic mode maps to imitate self-check on mobile.
class TalkHomeScreen extends StatefulWidget {
  const TalkHomeScreen({super.key});

  @override
  State<TalkHomeScreen> createState() => _TalkHomeScreenState();
}

class _TalkHomeScreenState extends State<TalkHomeScreen> {
  TalkPack? _pack;
  String _grade = 'g5';
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
          ContentRepository.instance.talk ?? await ContentRepository.instance.loadTalk();
      if (mounted) setState(() => _pack = pack);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _start(int mode) {
    final pack = _pack;
    if (pack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TalkBattleScreen(pack: pack, grade: _grade, mode: mode),
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
              _bar(context, 'トークバスター'),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final g in ['g5', 'g4', 'g3'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('${g.substring(1)}級'),
                            selected: _grade == g,
                            onSelected: (_) => setState(() => _grade = g),
                            selectedColor: AppColors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _modeBtn('STEP1 きいてマネ', () => _start(2)),
                    _modeBtn('STEP2 いえた！（じこチェック）', () => _start(3)),
                    _modeBtn('STEP3 テスト（4択）', () => _start(1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
        ),
        onPressed: _pack == null ? null : onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

Widget _bar(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

class TalkBattleScreen extends StatefulWidget {
  const TalkBattleScreen({
    super.key,
    required this.pack,
    required this.grade,
    required this.mode,
  });

  final TalkPack pack;
  final String grade;
  final int mode; // 1 quiz, 2/3 imitate

  @override
  State<TalkBattleScreen> createState() => _TalkBattleScreenState();
}

class _TalkBattleScreenState extends State<TalkBattleScreen> {
  late final List<TalkItem> _queue;
  int _qi = 0;
  int _cleared = 0;
  int _score = 0;
  bool _showAnswer = false;
  List<String> _choices = [];

  TalkItem get _cur => _queue[_qi];
  bool get _isQuiz => widget.mode == 1;

  @override
  void initState() {
    super.initState();
    final pool = List<TalkItem>.from(widget.pack.grades[widget.grade] ?? []);
    pool.shuffle(Random());
    while (pool.length < widget.pack.qn && pool.isNotEmpty) {
      pool.addAll(List<TalkItem>.from(widget.pack.grades[widget.grade]!));
    }
    _queue = pool.take(widget.pack.qn).toList();
    AudioService.instance.playBattleBgm();
    AudioService.instance.playSfx('ready-go');
    WidgetsBinding.instance.addPostFrameCallback((_) => _prep());
  }

  void _prep() {
    if (_qi >= _queue.length) {
      _finish();
      return;
    }
    final item = _cur;
    if (_isQuiz) {
      final distractors = (widget.pack.grades[widget.grade] ?? [])
          .where((e) => e.en != item.en)
          .map((e) => e.en)
          .toList()
        ..shuffle(Random());
      final opts = [item.en, ...distractors.take(3)]..shuffle(Random());
      setState(() {
        _choices = opts;
        _showAnswer = false;
      });
    } else {
      setState(() => _showAnswer = false);
    }
    AudioService.instance.playVoiceAsset(item.voice);
  }

  Future<void> _correct() async {
    setState(() {
      _cleared++;
      _score += 100;
    });
    await AudioService.instance.playSfx('correct');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _qi++);
    _prep();
  }

  Future<void> _wrong() async {
    setState(() => _showAnswer = true);
    await AudioService.instance.playSfx('gameover');
  }

  void _nextAfterWrong() {
    setState(() => _qi++);
    _prep();
  }

  Future<void> _finish() async {
    final total = _queue.length;
    final win = _cleared >= (total * widget.pack.winRatio).ceil();
    await ProgressService.instance.setBestIfHigher(ProgressKeys.bestTalk, _score);
    if (win) {
      await ProgressService.instance.befriend('talkmon');
      if (_cleared >= total) await ProgressService.instance.addSRank('talkmon');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _TalkResult(
          score: _score,
          cleared: _cleared,
          total: total,
          win: win,
          rank: rankFromRatio(_cleared, total),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_qi >= _queue.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final item = _cur;
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${_qi + 1}/${_queue.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('$_score', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(item.ja,
                    style: const TextStyle(color: AppColors.cream, fontSize: 22, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                if (!_isQuiz || _showAnswer) ...[
                  const SizedBox(height: 12),
                  Text(item.en,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center),
                ],
                IconButton(
                  onPressed: () => AudioService.instance.playVoiceAsset(item.voice),
                  icon: const Icon(Icons.volume_up, color: Colors.white, size: 40),
                ),
                const Spacer(),
                if (_isQuiz && !_showAnswer)
                  ..._choices.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => c == item.en ? _correct() : _wrong(),
                        child: Text(c, textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else if (!_isQuiz && !_showAnswer) ...[
                  ElevatedButton(
                    onPressed: () => AudioService.instance.playVoiceAsset(item.voice),
                    child: const Text('もういちど'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _correct,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
                    child: const Text('いえた！'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _nextAfterWrong,
                    child: const Text('つぎへ'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TalkResult extends StatelessWidget {
  const _TalkResult({
    required this.score,
    required this.cleared,
    required this.total,
    required this.win,
    required this.rank,
  });

  final int score;
  final int cleared;
  final int total;
  final bool win;
  final String rank;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('トーク けっか',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text(rank, style: const TextStyle(color: AppColors.gold, fontSize: 64, fontWeight: FontWeight.w900)),
                Text('$cleared / $total', style: const TextStyle(color: Colors.white, fontSize: 20)),
                Text(win ? 'クリア！トークモンとなかまに' : 'もういちど！',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/monsters/talkmon/talkmon-friend.png',
                  height: 120,
                  errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 80, color: Colors.white),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    AudioService.instance.playHubBgm();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('ホームへ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
