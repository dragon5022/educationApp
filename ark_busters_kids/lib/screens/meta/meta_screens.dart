import 'package:flutter/material.dart';

import '../../core/progress/progress_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../services/content_repository.dart';
import '../../services/progress_service.dart';
import '../../widgets/page_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _se = true;
  bool _voice = true;
  bool _syncing = false;
  String _syncMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final se = await ProgressService.instance.isSeOn();
    final vo = await ProgressService.instance.isVoiceOn();
    if (!mounted) return;
    setState(() {
      _se = se;
      _voice = vo;
    });
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncMsg = 'こうしんちゅう…';
    });
    final ok = await ContentRepository.instance.syncRemotePacks();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncMsg = ok
          ? 'もんだいデータをこうしんしたよ'
          : 'リモートURLが未設定のため、アプリ内データをつかっています';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'せってい  Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              _row(
                'こうかおん',
                _se,
                (v) async {
                  await ProgressService.instance.setSeOn(v);
                  setState(() => _se = v);
                },
              ),
              _row(
                'えいごの こえ',
                _voice,
                (v) async {
                  await ProgressService.instance.setVoiceOn(v);
                  setState(() => _voice = v);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _syncing ? null : _sync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(_syncing ? 'こうしんちゅう…' : 'もんだいデータをこうしん'),
              ),
              if (_syncMsg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_syncMsg, style: const TextStyle(color: AppColors.cream), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              const Text(
                '※ クライアントが manifest の url にJSONを公開すると、ストア再申請なしで問題を更新できます。',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, bool on, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
          Switch(value: on, onChanged: onChanged, activeThumbColor: AppColors.purple),
          Text(on ? 'ON' : 'OFF', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _ctrl = TextEditingController();
  int _friends = 0;
  int _bestV = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await ProgressService.instance.getPlayerName();
    final friends = await ProgressService.instance.friends();
    final best = await ProgressService.instance.bestScore(ProgressKeys.bestVocabulary);
    if (!mounted) return;
    setState(() {
      _ctrl.text = name;
      _friends = friends.length;
      _bestV = best;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'マイページ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              const Text('なまえ', style: TextStyle(color: AppColors.cream)),
              TextField(
                controller: _ctrl,
                maxLength: 12,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  counterStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                ),
                onSubmitted: (v) => ProgressService.instance.setPlayerName(v),
              ),
              const SizedBox(height: 16),
              Text('なかま $_friends / 4', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('ボキャブラリー ベスト $_bestV', style: const TextStyle(color: AppColors.gold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await ProgressService.instance.setPlayerName(_ctrl.text);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('ほぞん'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<String> _friends = [];

  static const _mons = [
    ('vocamon', 'ボキャモン', 'assets/images/monsters/vocamon/vocamon-friend.png'),
    ('lismon', 'リスモン', 'assets/images/monsters/lismon/lismon-friend.png'),
    ('talkmon', 'トークモン', 'assets/images/monsters/talkmon/talkmon-friend.png'),
    ('gramon', 'グラモン', 'assets/images/monsters/gramon/gramon-friend.png'),
  ];

  @override
  void initState() {
    super.initState();
    ProgressService.instance.friends().then((f) {
      if (mounted) setState(() => _friends = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'ずかん  Collection',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  children: _mons.map((m) {
                    final unlocked = _friends.contains(m.$1);
                    return Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: unlocked ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: unlocked ? AppColors.blue : Colors.white38,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: unlocked ? 1 : 0.35,
                            child: Image.asset(
                              m.$3,
                              height: 80,
                              errorBuilder: (_, _, _) =>
                                  Icon(unlocked ? Icons.pets : Icons.lock, size: 48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            unlocked ? m.$2 : '？？？',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: unlocked ? AppColors.ink : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
