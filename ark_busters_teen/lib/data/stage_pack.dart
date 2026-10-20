import 'dart:convert';

import 'package:ark_core/content.dart';

/// Every stage's question pack, keyed by the web page name. The JSON files
/// are produced by tools/export_teen_packs.py and served through
/// [ArkContent] (bundled copy, or a newer one synced from the Google Sheet).
const stagePackIds = [
  'm-seifu', 'm-keisu', 'm-shisu', 'm-zukei', 'm-kansu',
  'e-goi', 'e-bunpou', 'e-choubun', 'e-hyougen',
  'k-kanji', 'k-kotoba', 'k-bunpou', 'k-koten',
  'r-genso', 'r-inochi', 'r-daichi', 'r-rikigaku',
  's-chizu', 's-rekishi', 's-jidai', 's-seigi',
];

/// Bump when a release changes the pack JSON format; sheets can then
/// require it with the manifest's `minAppBuild` column.
const contentFormatBuild = 1;

Map<String, String> get bundledStagePacks => {
      for (final id in stagePackIds) id: 'assets/data/$id.json',
    };

/// One question: web `{q, a, choices, e}`.
class Problem {
  const Problem({
    required this.q,
    required this.a,
    required this.choices,
    this.e,
    this.free = true,
  });

  final String q;
  final String a;
  final List<String> choices;
  final String? e;

  /// Playable without the purchase (sheet column `free`).
  final bool free;

  factory Problem.fromJson(Map<String, dynamic> j) => Problem(
        q: _plain('${j['q'] ?? ''}'),
        // The web compares `val === p.a` on strings; a sheet may send numbers.
        a: '${j['a'] ?? ''}',
        choices: [
          for (final c in (j['choices'] as List<dynamic>? ?? const [])) '$c',
        ],
        e: j['e'] == null || '${j['e']}'.isEmpty ? null : _plain('${j['e']}'),
        free: j['free'] != false,
      );
}

/// The web sets `innerHTML`; packs are plain text today, but keep a sheet
/// edit with simple markup (`<br>`, `<sup>`, entities) readable.
String _plain(String s) {
  if (!s.contains('<') && !s.contains('&')) return s;
  return s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<sup>.*?</sup>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&minus;', '−')
      .replaceAll('&times;', '×')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');
}

/// Images a stage uses (file names without extension; see sync_images.py).
class StageImages {
  const StageImages({
    this.art,
    this.boss,
    required this.chara,
    this.win,
    this.lose,
  });

  /// Full-screen title illustration (start screen "artmode"); null → the
  /// web's plain title layout (balloon + character + title text).
  final String? art;

  /// Enemy shown faintly behind the plain title layout.
  final String? boss;

  /// Character set: 'uta' (英語・国語・社会) or 'kanade' (数学・理科).
  final String chara;
  final String? win;
  final String? lose;

  String? get artAsset => art == null ? null : 'assets/images/title/$art.webp';
  String? get bossAsset => boss == null ? null : 'assets/images/boss/$boss.webp';
  String charaAsset(String mood) => 'assets/images/chara/$chara-$mood.webp';
  String? get winAsset => win == null ? null : 'assets/images/result/$win.webp';
  String? get loseAsset =>
      lose == null ? null : 'assets/images/result/$lose.webp';

  factory StageImages.fromJson(Map<String, dynamic>? j) => StageImages(
        art: j?['art'] as String?,
        boss: j?['boss'] as String?,
        chara: (j?['chara'] as String?) ?? 'uta',
        win: j?['win'] as String?,
        lose: j?['lose'] as String?,
      );
}

/// A stage page (e.g. 文法の要塞): settings + questions per level.
class StagePack {
  const StagePack({
    required this.id,
    required this.subject,
    required this.title,
    required this.label,
    required this.timeLimitMs,
    required this.maxQuestions,
    required this.images,
    required this.levels,
  });

  final String id;
  final String subject;
  final String title;

  /// One character on the title balloon (web `.balloon-label`).
  final String label;

  /// Web `TIME_LIMIT` (5000 ms per question).
  final int timeLimitMs;

  /// Web `TOTAL_Q = Math.min(15, ACTIVE_PROBLEMS.length)`.
  final int maxQuestions;
  final StageImages images;

  /// Levels in web order (Lv1…Lv4), only those with questions.
  final Map<String, List<Problem>> levels;

  static const levelOrder = ['Lv1', 'Lv2', 'Lv3', 'Lv4'];

  int get questionCount =>
      levels.values.fold(0, (sum, list) => sum + list.length);

  factory StagePack.fromJson(Map<String, dynamic> j) {
    final raw = (j['levels'] as Map<String, dynamic>?) ?? const {};
    final levels = <String, List<Problem>>{};
    for (final lv in levelOrder) {
      final list = raw[lv] as List<dynamic>?;
      if (list == null || list.isEmpty) continue;
      levels[lv] = [
        for (final p in list) Problem.fromJson(p as Map<String, dynamic>),
      ];
    }
    return StagePack(
      id: '${j['id']}',
      subject: '${j['subject'] ?? ''}',
      title: '${j['title'] ?? ''}',
      label: '${j['label'] ?? ''}',
      timeLimitMs: (j['timeLimitMs'] as num?)?.toInt() ?? 5000,
      maxQuestions: (j['maxQuestions'] as num?)?.toInt() ?? 15,
      images: StageImages.fromJson(j['images'] as Map<String, dynamic>?),
      levels: levels,
    );
  }

  static Future<StagePack> load(String id) async {
    final text = await ArkContent.instance.loadPack(id);
    return StagePack.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
