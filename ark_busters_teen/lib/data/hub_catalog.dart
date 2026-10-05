import 'package:flutter/material.dart';

/// Balloon colours of the top-page cards (`.card-balloon.red` …):
/// radial-gradient(circle at 32% 30%, c0 0%, c1 s1, c2 s2, c3 100%), and the
/// tail colour (`currentColor`).
enum BalloonColor {
  red([Color(0xFFFF97B1), Color(0xFFFF6B8A), Color(0xFFE63946), Color(0xFF8B1A24)],
      [0, .25, .65, 1], Color(0xFF8B1A24)),
  blue([Color(0xFF9CC9F2), Color(0xFF5D9BD1), Color(0xFF1F4E8C), Color(0xFF0F2A4D)],
      [0, .30, .70, 1], Color(0xFF0F2A4D)),
  green([Color(0xFF7FE3C4), Color(0xFF3CC79E), Color(0xFF069F70), Color(0xFF04654A)],
      [0, .30, .70, 1], Color(0xFF04654A)),
  purple([Color(0xFFC9A3E8), Color(0xFFA06FCC), Color(0xFF6B3FA0), Color(0xFF3F1F66)],
      [0, .30, .70, 1], Color(0xFF3F1F66)),
  orange([Color(0xFFFFCC8A), Color(0xFFFF9F40), Color(0xFFE5751A), Color(0xFF8B4400)],
      [0, .30, .70, 1], Color(0xFF8B4400));

  const BalloonColor(this.colors, this.stops, this.tail);
  final List<Color> colors;
  final List<double> stops;
  final Color tail;
}

class StageCard {
  const StageCard({
    required this.title,
    required this.sub,
    required this.letter,
    required this.color,
    this.packId,
    this.isNew = true,
  });

  final String title;
  final String sub;
  final String letter;
  final BalloonColor color;

  /// null → greyed-out "準備中" card (paid stages not released yet).
  final String? packId;
  final bool isNew;
}

class Enemy {
  const Enemy({
    required this.image,
    required this.fallback,
    required this.name,
    required this.en,
    required this.title,
    required this.quote,
  });

  final String image;
  final String fallback;
  final String name;
  final String en;
  final String title;
  final String quote;
}

class SubjectTab {
  const SubjectTab({
    required this.id,
    required this.ja,
    required this.en,
    required this.enemy,
    required this.cards,
  });

  final String id;
  final String ja;
  final String en;
  final Enemy enemy;
  final List<StageCard> cards;
}

/// The five tabs of ark-top.html, in web order (数学 is selected first).
const subjectTabs = [
  SubjectTab(
    id: 'math',
    ja: '数学',
    en: 'MATH',
    enemy: Enemy(
      image: 'assets/images/boss/m-boss.webp',
      fallback: '∞',
      name: 'ゼロディウス',
      en: 'LORD INFINITY ZERODIUS',
      title: '無限を支配する数学卿',
      quote: '「その答え、我が無限に届くか。」',
    ),
    cards: [
      StageCard(title: '正負の境界線', sub: 'SEIFU', letter: '正', color: BalloonColor.red, packId: 'm-seifu'),
      StageCard(title: '係数の暗号室', sub: 'KEISU', letter: '係', color: BalloonColor.red, packId: 'm-keisu'),
      StageCard(title: '指数の増幅炉', sub: 'SHISU', letter: '指', color: BalloonColor.red, packId: 'm-shisu'),
      StageCard(title: '図形の幾何回廊', sub: 'ZUKEI', letter: '図', color: BalloonColor.red, packId: 'm-zukei'),
      StageCard(title: '関数の座標宮', sub: 'KANSU', letter: '関', color: BalloonColor.red, packId: 'm-kansu'),
      StageCard(title: '移項の転移門', sub: '有料 / 準備中', letter: '移', color: BalloonColor.purple, isNew: false),
      StageCard(title: 'ルートの結晶域', sub: '有料 / 準備中', letter: '√', color: BalloonColor.purple, isNew: false),
    ],
  ),
  SubjectTab(
    id: 'english',
    ja: '英語',
    en: 'ENG',
    enemy: Enemy(
      image: 'assets/images/boss/e-boss.webp',
      fallback: '∞',
      name: 'アルファ',
      en: 'GENERAL ALPHA',
      title: '英語軍を率いる総司令官',
      quote: '「戦場で、迷いは敗北だ。」',
    ),
    cards: [
      StageCard(title: '語彙の兵器庫', sub: 'GOI', letter: '語', color: BalloonColor.blue, packId: 'e-goi'),
      StageCard(title: '文法の要塞', sub: 'BUNPOU', letter: '文', color: BalloonColor.blue, packId: 'e-bunpou'),
      StageCard(title: '長文の戦場', sub: 'CHOUBUN', letter: '長', color: BalloonColor.blue, packId: 'e-choubun'),
      StageCard(title: '表現の司令室', sub: 'HYOUGEN', letter: '表', color: BalloonColor.blue, packId: 'e-hyougen'),
    ],
  ),
  SubjectTab(
    id: 'japanese',
    ja: '国語',
    en: 'JP',
    enemy: Enemy(
      image: 'assets/images/boss/k-boss.webp',
      fallback: '∞',
      name: 'かぐや',
      en: 'QUEEN KAGUYA',
      title: '言葉を支配する女王',
      quote: '「美しき言の葉に、ひざまずきなさい。」',
    ),
    cards: [
      StageCard(title: '漢字の間', sub: 'KANJI', letter: '漢', color: BalloonColor.purple, packId: 'k-kanji'),
      StageCard(title: '言葉の蔵', sub: 'KOTOBA', letter: '語', color: BalloonColor.purple, packId: 'k-kotoba'),
      StageCard(title: '文法の塔', sub: 'BUNPOU', letter: '文', color: BalloonColor.purple, packId: 'k-bunpou'),
      StageCard(title: '古典の庭', sub: 'KOTEN', letter: '古', color: BalloonColor.purple, packId: 'k-koten'),
    ],
  ),
  SubjectTab(
    id: 'science',
    ja: '理科',
    en: 'SCI',
    enemy: Enemy(
      image: 'assets/images/boss/r-boss.webp',
      fallback: '∞',
      name: 'モーガン',
      en: 'DOCTOR MORGAN',
      title: '実験と理科を操る魔術博士',
      quote: '「さあ、君たちの限界を観察しよう。」',
    ),
    cards: [
      StageCard(title: '元素の実験室', sub: 'GENSO', letter: '元', color: BalloonColor.green, packId: 'r-genso'),
      StageCard(title: '生命の培養槽', sub: 'INOCHI', letter: '生', color: BalloonColor.green, packId: 'r-inochi'),
      StageCard(title: '大地の記憶庫', sub: 'DAICHI', letter: '地', color: BalloonColor.green, packId: 'r-daichi'),
      StageCard(title: '力学の歯車塔', sub: 'RIKIGAKU', letter: '力', color: BalloonColor.green, packId: 'r-rikigaku'),
    ],
  ),
  SubjectTab(
    id: 'society',
    ja: '社会',
    en: 'SOC',
    enemy: Enemy(
      image: 'assets/images/boss/s-boss.webp',
      fallback: '∞',
      name: 'クロノス',
      en: 'KING CHRONOS',
      title: '時代と社会を支配する王',
      quote: '「我が玉座に届く知恵を示せ。」',
    ),
    cards: [
      StageCard(title: '地図の迷宮', sub: 'CHIZU', letter: '地', color: BalloonColor.orange, packId: 's-chizu'),
      StageCard(title: '歴史の回廊', sub: 'REKISHI', letter: '歴', color: BalloonColor.orange, packId: 's-rekishi'),
      StageCard(title: '時代の玉座', sub: 'JIDAI', letter: '時', color: BalloonColor.orange, packId: 's-jidai'),
      StageCard(title: '正義の評議院', sub: 'SEIGI', letter: '正', color: BalloonColor.orange, packId: 's-seigi'),
    ],
  ),
];
