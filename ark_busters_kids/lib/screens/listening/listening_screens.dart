import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/content/game_packs.dart';
import '../../core/progress/progress_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/char_voice.dart';
import '../../services/kids_store.dart';
import '../../services/content_repository.dart';
import '../../services/progress_service.dart';
import '../../widgets/page_background.dart';

class ListeningHomeScreen extends StatefulWidget {
  const ListeningHomeScreen({super.key});

  @override
  State<ListeningHomeScreen> createState() => _ListeningHomeScreenState();
}

class _ListeningHomeScreenState extends State<ListeningHomeScreen> {
  ListeningPack? _pack;
  String _grade = 'g5';
  String? _error;

  static const _levelNames = {
    0: 'ちょうやさしい',
    1: 'ぶんをきく',
    2: 'おへんじ',
    3: 'かいわ',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ContentRepository.instance.init();
      final pack = ContentRepository.instance.listening ??
          await ContentRepository.instance.loadListening();
      if (!mounted) return;
      setState(() => _pack = pack);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _start(int level) {
    final pack = _pack;
    if (pack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListeningBattleScreen(
          pack: pack,
          grade: _grade,
          level: level,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levels = {
      for (final e in (_pack?.grades[_grade] ?? {}).entries)
        e.key: KidsStore.allowed<ListeningItem>(e.value, (i) => i.free).toList(),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context, 'リスニングバスター'),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
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
                            selectedColor: AppColors.yellow,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final lv in [0, 1, 2, 3])
                      if (levels.containsKey(lv))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                              minimumSize: const Size.fromHeight(56),
                            ),
                            onPressed: () => _start(lv),
                            child: Text(
                              'Lv$lv  ${_levelNames[lv]}  (${levels[lv]!.length}もん)',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
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

Widget _topBar(BuildContext context, String title) {
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

class ListeningBattleScreen extends StatefulWidget {
  const ListeningBattleScreen({
    super.key,
    required this.pack,
    required this.grade,
    required this.level,
  });

  final ListeningPack pack;
  final String grade;
  final int level;

  @override
  State<ListeningBattleScreen> createState() => _ListeningBattleScreenState();
}

class _ListeningBattleScreenState extends State<ListeningBattleScreen> {
  late final List<ListeningItem> _queue;
  late int _lives;
  late final int _timeLimit;
  int _qi = 0;
  int _correct = 0;
  int _combo = 0;
  int _score = 0;
  int _left = 0;
  Timer? _timer;
  bool _locked = false;
  List<String> _choices = [];

  ListeningItem get _cur => _queue[_qi];

  @override
  void initState() {
    super.initState();
    final pool = KidsStore.allowed<ListeningItem>(
      widget.pack.grades[widget.grade]?[widget.level] ?? const [],
      (i) => i.free,
    ).toList()..shuffle(Random());
    _queue = pool.take(widget.pack.qn).toList();
    _lives = widget.pack.livesByLevel[widget.level] ?? 3;
    _timeLimit = widget.pack.timeByLevel[widget.level] ?? 0;
    AudioService.instance.playBattleBgm();
    AudioService.instance.playSfx('ready-go');
    CharVoice.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepQ());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _prepQ() {
    if (_qi >= _queue.length) {
      _finish(true);
      return;
    }
    final item = _cur;
    final opts = [...item.opts, item.ans]..shuffle(Random());
    setState(() {
      _choices = opts;
      _locked = false;
      _left = _timeLimit;
    });
    AudioService.instance.playVoiceAsset(item.voice, fallbackText: item.en);
    _timer?.cancel();
    if (_timeLimit > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _locked) return;
        if (_left <= 1) {
          _onWrong(timeout: true);
        } else {
          setState(() => _left--);
        }
      });
    }
  }

  Future<void> _onPick(String pick) async {
    if (_locked) return;
    if (pick == _cur.ans) {
      _timer?.cancel();
      setState(() {
        _locked = true;
        _correct++;
        _combo++;
        _score += 10 + (_combo >= 2 ? (_combo - 1) * 5 : 0);
      });
      await AudioService.instance.playSfx('correct');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _qi++);
      _prepQ();
    } else {
      _onWrong();
    }
  }

  Future<void> _onWrong({bool timeout = false}) async {
    if (_locked) return;
    _timer?.cancel();
    setState(() {
      _locked = true;
      _combo = 0;
      _lives--;
    });
    await AudioService.instance.playSfx('gameover');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(timeout ? 'じかんぎれ' : 'ざんねん'),
        content: Text('${_cur.en}\n${_cur.ja}\n\n${_cur.tip}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('つぎへ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (_lives <= 0) {
      _finish(false);
      return;
    }
    setState(() => _qi++);
    _prepQ();
  }

  Future<void> _finish(bool survived) async {
    _timer?.cancel();
    final total = _queue.length;
    final win = _correct >= (total * widget.pack.winRatio).ceil();
    await ProgressService.instance.setBestIfHigher(
      ProgressKeys.bestListening,
      _score,
    );
    if (win) {
      await ProgressService.instance.befriend('lismon');
      if (_correct >= total) {
        await ProgressService.instance.addSRank('lismon');
      }
    }
    if (!mounted) return;
    CharVoice.result(win);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _ModeResultScreen(
          title: 'リスニング けっか',
          monster: 'lismon',
          score: _score,
          cleared: _correct,
          total: total,
          win: win,
          rank: rankFromRatio(_correct, total),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      '${_qi + 1}/${_queue.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '♥' * _lives,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('$_score', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                    if (_timeLimit > 0) ...[
                      const SizedBox(width: 12),
                      Text('${_left}s', style: const TextStyle(color: Colors.white)),
                    ],
                  ],
                ),
              ),
              if (item.q != null)
                Text(item.q!, style: const TextStyle(color: AppColors.cream, fontSize: 18)),
              IconButton(
                onPressed: () => AudioService.instance.playVoiceAsset(item.voice, fallbackText: item.en),
                icon: const Icon(Icons.volume_up, color: Colors.white, size: 40),
              ),
              const Text('きいて えらぼう', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: item.t == 'pic' ? 3 : 1,
                  padding: const EdgeInsets.all(16),
                  childAspectRatio: item.t == 'pic' ? 1.2 : 4,
                  children: [
                    for (final c in _choices)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: ElevatedButton(
                          onPressed: _locked ? null : () => _onPick(c),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: item.t == 'pic' ? 32 : 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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

class _ModeResultScreen extends StatelessWidget {
  const _ModeResultScreen({
    required this.title,
    required this.monster,
    required this.score,
    required this.cleared,
    required this.total,
    required this.win,
    required this.rank,
  });

  final String title;
  final String monster;
  final int score;
  final int cleared;
  final int total;
  final bool win;
  final String rank;

  @override
  Widget build(BuildContext context) {
    final friendAsset = 'assets/images/monsters/$monster/$monster-friend.png';
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(rank, style: const TextStyle(color: AppColors.gold, fontSize: 64, fontWeight: FontWeight.w900)),
                Text('$cleared / $total', style: const TextStyle(color: Colors.white, fontSize: 20)),
                Text('スコア $score', style: const TextStyle(color: AppColors.cream)),
                const SizedBox(height: 12),
                Text(
                  win ? 'クリア！なかまになったよ' : 'もういちど チャレンジ！',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Image.asset(
                  friendAsset,
                  height: 120,
                  errorBuilder: (_, _, _) => const Icon(Icons.pets, size: 80, color: Colors.white),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    AudioService.instance.playHubBgm();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('ホームへ'),
                ),
                TextButton(
                  onPressed: () {
                    CharVoice.retry();
                    AudioService.instance.playHubBgm();
                    Navigator.pop(context);
                  },
                  child: const Text('もういちど'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
