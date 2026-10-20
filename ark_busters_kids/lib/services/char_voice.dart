import 'dart:math';

import 'audio_service.dart';

/// The two guide characters' recorded lines (詩 = uta, 奏 = kanade), see
/// assets/audio/charvoice/README.md. One character accompanies each game:
/// picked at random when the game starts, and the same one reacts to the
/// result and to もう一回.
///
/// Lines: *_start (game start), *_win / *_lose (result), kanade_retry
/// (もう一回; 詩 reuses her start line), *_greet (first hub visit per launch).
class CharVoice {
  CharVoice._();

  static final _rng = Random();
  static String _current = 'uta';
  static bool _greeted = false;
  static bool _skipStart = false;

  /// Current character id ('uta' | 'kanade').
  static String get current => _current;

  /// 「今日も一緒に頑張ろう！」 once per app launch, when the hub shows.
  static void greet() {
    if (_greeted) return;
    _greeted = true;
    _current = _rng.nextBool() ? 'uta' : 'kanade';
    AudioService.instance.playCharVoice('${_current}_greet', delay: const Duration(milliseconds: 500));
  }

  /// Game start (after the encounter pop). Picks the character for this game.
  /// Skipped right after [retry], which already spoke.
  static void start() {
    if (_skipStart) {
      _skipStart = false;
      return;
    }
    _current = _rng.nextBool() ? 'uta' : 'kanade';
    AudioService.instance.playCharVoice('${_current}_start', delay: const Duration(milliseconds: 700));
  }

  /// Result: after the clear / game-over jingle.
  static void result(bool win) => AudioService.instance.playCharVoice(
        '${_current}_${win ? 'win' : 'lose'}',
        delay: const Duration(milliseconds: 1100),
      );

  /// もう一回: 「ぼくたちならできるよ！もういっかい！」 (詩: 「よし、あたしならできる…」).
  static void retry() {
    _skipStart = true;
    AudioService.instance.playCharVoice(_current == 'kanade' ? 'kanade_retry' : 'uta_start');
  }
}
