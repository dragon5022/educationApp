import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/content/game_packs.dart';
import '../../core/progress/progress_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/content_repository.dart';
import '../../services/progress_service.dart';
import '../../widgets/page_background.dart';

class SentenceHomeScreen extends StatefulWidget {
  const SentenceHomeScreen({super.key});

  @override
  State<SentenceHomeScreen> createState() => _SentenceHomeScreenState();
}

class _SentenceHomeScreenState extends State<SentenceHomeScreen> {
  SentencePack? _pack;
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
      final pack = ContentRepository.instance.sentence ??
          await ContentRepository.instance.loadSentence();
      if (mounted) setState(() => _pack = pack);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _start({required bool endless}) {
    final pack = _pack;
    if (pack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SentenceBattleScreen(
          pack: pack,
          grade: _grade,
          endless: endless,
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
              _bar(context, 'センテンスバスター'),
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
                            selectedColor: AppColors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _pack == null ? null : () => _start(endless: false),
                      child: const Text('10問コース', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _pack == null ? null : () => _start(endless: true),
                      child: const Text('エンドレス', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class SentenceBattleScreen extends StatefulWidget {
  const SentenceBattleScreen({
    super.key,
    required this.pack,
    required this.grade,
    required this.endless,
  });

  final SentencePack pack;
  final String grade;
  final bool endless;

  @override
  State<SentenceBattleScreen> createState() => _SentenceBattleScreenState();
}

class _SentenceBattleScreenState extends State<SentenceBattleScreen> {
  late List<SentenceItem> _queue;
  late int _lives;
  late final int _timeLimit;
  int _qi = 0;
  int _cleared = 0;
  int _score = 0;
  int _step = 0;
  int _left = 0;
  Timer? _timer;
  bool _locked = false;
  List<_Chip> _chips = [];

  SentenceItem get _cur => _queue[_qi % _queue.length];

  @override
  void initState() {
    super.initState();
    final pool = List<SentenceItem>.from(widget.pack.grades[widget.grade] ?? [])
      ..shuffle(Random());
    if (widget.endless) {
      _queue = pool;
      _lives = 1;
    } else {
      _queue = pool.take(widget.pack.qn).toList();
      _lives = 3;
    }
    _timeLimit = widget.pack.timeByGrade[widget.grade] ?? 8;
    AudioService.instance.playBattleBgm();
    AudioService.instance.playSfx('ready-go');
    WidgetsBinding.instance.addPostFrameCallback((_) => _prep());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _prep() {
    if (!widget.endless && _qi >= _queue.length) {
      _finish(survived: true);
      return;
    }
    if (_queue.isEmpty) {
      _finish(survived: false);
      return;
    }
    if (widget.endless && _qi > 0 && _qi % _queue.length == 0) {
      _queue.shuffle(Random());
    }
    final item = _cur;
    final words = item.answer.map((a) => a.w).toList();
    final shuffled = List<String>.from(words)..shuffle(Random());
    // avoid identical order
    if (shuffled.join(' ') == words.join(' ') && shuffled.length > 1) {
      shuffled.shuffle(Random());
    }
    setState(() {
      _chips = [for (var i = 0; i < shuffled.length; i++) _Chip(shuffled[i], i)];
      _step = 0;
      _locked = false;
      _left = _timeLimit;
    });
    AudioService.instance.playVoiceAsset(item.voice);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _locked) return;
      if (_left <= 1) {
        _fail(timeout: true);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _tap(_Chip chip) async {
    if (_locked || chip.used) return;
    final expected = _cur.answer[_step].w;
    if (chip.word != expected) {
      await _fail();
      return;
    }
    setState(() {
      chip.used = true;
      _step++;
      _score += 10;
    });
    final part = widget.pack.gramParts[chip.word];
    if (part != null) {
      await AudioService.instance.playVoiceAsset('audio/voice/gramparts/$part.mp3');
    }
    if (_step >= _cur.answer.length) {
      _timer?.cancel();
      setState(() {
        _locked = true;
        _cleared++;
        _score += 20;
      });
      await AudioService.instance.playSfx('correct');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _qi++);
      _prep();
    }
  }

  Future<void> _fail({bool timeout = false}) async {
    if (_locked) return;
    _timer?.cancel();
    setState(() {
      _locked = true;
      _lives--;
    });
    await AudioService.instance.playSfx('gameover');
    if (!mounted) return;
    final ans = _cur.answer.map((a) => a.w).join(' ');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(timeout ? 'じかんぎれ' : 'ざんねん'),
        content: Text('$ans\n\n${_cur.tip}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (!mounted) return;
    if (_lives <= 0 || widget.endless) {
      _finish(survived: false);
      return;
    }
    setState(() => _qi++);
    _prep();
  }

  Future<void> _finish({required bool survived}) async {
    _timer?.cancel();
    final rank = widget.endless
        ? rankFromEndless(_cleared)
        : rankFromRatio(_cleared, _queue.length);
    final win = !widget.endless && survived;
    await ProgressService.instance.setBestIfHigher(
      ProgressKeys.bestSentence,
      _score,
    );
    if (win) {
      await ProgressService.instance.befriend('gramon');
      if (rank == 'S') await ProgressService.instance.addSRank('gramon');
    } else if (widget.endless && rank == 'S') {
      await ProgressService.instance.addSRank('gramon');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _SenResult(
          score: _score,
          cleared: _cleared,
          total: widget.endless ? _cleared : _queue.length,
          win: win,
          rank: rank,
          endless: widget.endless,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return const Scaffold(body: Center(child: Text('No data')));
    }
    final item = _cur;
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      widget.endless ? '$_cleared continuous' : '${_qi + 1}/${_queue.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text('♥' * _lives, style: const TextStyle(color: Colors.redAccent, fontSize: 18)),
                    const SizedBox(width: 12),
                    Text('${_left}s', style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    Text('$_score', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in item.ja)
                      Text(
                        p.t,
                        style: TextStyle(
                          color: p.pick ? AppColors.gold : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                item.answer.take(_step).map((a) => a.w).join(' '),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in _chips)
                    ElevatedButton(
                      onPressed: c.used || _locked ? null : () => _tap(c),
                      child: Text(c.word, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip {
  _Chip(this.word, this.id);
  final String word;
  final int id;
  bool used = false;
}

class _SenResult extends StatelessWidget {
  const _SenResult({
    required this.score,
    required this.cleared,
    required this.total,
    required this.win,
    required this.rank,
    required this.endless,
  });

  final int score;
  final int cleared;
  final int total;
  final bool win;
  final String rank;
  final bool endless;

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
                const Text('センテンス けっか',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text(rank, style: const TextStyle(color: AppColors.gold, fontSize: 64, fontWeight: FontWeight.w900)),
                Text(
                  endless ? 'れんぞく $cleared' : '$cleared / $total',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  win ? 'クリア！グラモンとなかまに' : (endless ? 'エンドレス終了' : 'もういちど！'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/monsters/gramon/gramon-friend.png',
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
