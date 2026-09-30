/// 元素组合技表。两张牌的元素不分顺序，都能对上一个名字和效果。
class ArenaCombo {
  const ArenaCombo({
    required this.name,
    required this.formula,
    required this.blurb,
    this.bonusDamage = 0,
    this.heal = 0,
    this.energy = 0,
    this.splash = 0,
  });

  final String name;
  final String formula;
  final String blurb;
  final int bonusDamage;
  final int heal;
  final int energy;
  final int splash;

  int get score => bonusDamage + heal + energy * 6 + splash;
}

class ArenaCombos {
  const ArenaCombos._();

  static const List<String> elements = ['星', '刃', '霜', '月', '潮', '炎', '光', '影'];

  static const Map<String, String> heroElements = {
    'lanxing': '星',
    'tutu': '刃',
    'maoying': '霜',
    'huhuo': '炎',
    'linglan': '月',
    'yuebai': '光',
    'taoyin': '潮',
    'xueli': '霜',
    'ziyuan': '影',
  };

  static List<String> forHero(String? heroId, {String? cardName}) {
    if (cardName == '流光合击') return const ['光', '星'];
    final primary = heroElements[heroId] ?? '星';
    switch (heroId) {
      case 'maoying':
        return const ['霜', '影'];
      case 'huhuo':
        return const ['炎', '刃'];
      case 'yuebai':
        return const ['光', '月'];
      case 'taoyin':
        return const ['潮', '月'];
      case 'xueli':
        return const ['霜', '潮'];
      case 'ziyuan':
        return const ['影', '星'];
      default:
        return [primary];
    }
  }

  static ArenaCombo? bestPair(List<String> left, List<String> right) {
    ArenaCombo? best;
    for (final a in left) {
      for (final b in right) {
        final hit = pair(a, b);
        if (best == null || hit.score > best.score) best = hit;
      }
    }
    return best;
  }

  static ArenaCombo pair(String a, String b) {
    final key = _pairKey(a, b);
    return _pairs[key] ??
        ArenaCombo(
          name: '$a$b交锋',
          formula: _formula([a, b]),
          blurb: '临时撞出来的连段',
          bonusDamage: 10,
        );
  }

  static ArenaCombo triple(String a, String b, String c) {
    final key = _tripleKey(a, b, c);
    final crafted = _triples[key];
    if (crafted != null) return crafted;
    final marks = [a, b, c];
    final distinct = marks.toSet().length;
    final hasMoon = marks.contains('月');
    final hasFlame = marks.contains('炎');
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) % _verbs.length;
    }
    final verb = _verbs[hash];
    return ArenaCombo(
      name: '${marks.join()}$verb',
      formula: _formula(marks),
      blurb: '三元素自由连段',
      bonusDamage: 8 + distinct * 4,
      heal: hasMoon ? 10 : 0,
      energy: marks.contains('潮') ? 1 : 0,
      splash: hasFlame ? 12 : 0,
    );
  }

  static String _pairKey(String a, String b) {
    final marks = [a, b]..sort();
    return marks.join();
  }

  static String _tripleKey(String a, String b, String c) {
    final marks = [a, b, c]..sort();
    return marks.join();
  }

  static String _formula(List<String> marks) => marks.join(' + ');

  static const List<String> _verbs = [
    '乱舞',
    '交响',
    '回响',
    '崩解',
    '咏唱',
    '轮舞',
    '断罪',
    '夜行',
  ];

  static final Map<String, ArenaCombo> _pairs = {
    for (final row in _pairRows) _pairKey(row.$1, row.$2): row.$3,
  };

  static final Map<String, ArenaCombo> _triples = {
    for (final row in _tripleRows) _tripleKey(row.$1, row.$2, row.$3): row.$4,
  };
}

const List<(String, String, ArenaCombo)> _pairRows = [
  (
    '星',
    '星',
    ArenaCombo(
        name: '双星共鸣',
        formula: '星 + 星',
        blurb: '同元素回能',
        bonusDamage: 14,
        energy: 1)
  ),
  (
    '刃',
    '刃',
    ArenaCombo(name: '连斩', formula: '刃 + 刃', blurb: '连续斩击', bonusDamage: 22)
  ),
  (
    '霜',
    '霜',
    ArenaCombo(
        name: '霜锁', formula: '霜 + 霜', blurb: '冻住节奏', bonusDamage: 12, energy: 1)
  ),
  (
    '月',
    '月',
    ArenaCombo(
        name: '双月', formula: '月 + 月', blurb: '月光回血', heal: 18, bonusDamage: 6)
  ),
  (
    '潮',
    '潮',
    ArenaCombo(
        name: '潮汐回卷',
        formula: '潮 + 潮',
        blurb: '抽回节奏',
        bonusDamage: 10,
        energy: 2)
  ),
  (
    '炎',
    '炎',
    ArenaCombo(
        name: '燎原',
        formula: '炎 + 炎',
        blurb: '溅射全场',
        bonusDamage: 12,
        splash: 16)
  ),
  (
    '光',
    '光',
    ArenaCombo(name: '光爆', formula: '光 + 光', blurb: '强光直击', bonusDamage: 20)
  ),
  (
    '影',
    '影',
    ArenaCombo(
        name: '影袭', formula: '影 + 影', blurb: '暗处补刀', bonusDamage: 16, energy: 1)
  ),
  (
    '星',
    '刃',
    ArenaCombo(name: '星刃斩', formula: '星 + 刃', blurb: '星光附刃', bonusDamage: 20)
  ),
  (
    '星',
    '霜',
    ArenaCombo(
        name: '星霜', formula: '星 + 霜', blurb: '寒星', bonusDamage: 14, energy: 1)
  ),
  (
    '星',
    '月',
    ArenaCombo(
        name: '星月祈', formula: '星 + 月', blurb: '祈愿', bonusDamage: 8, heal: 12)
  ),
  (
    '星',
    '潮',
    ArenaCombo(
        name: '星潮', formula: '星 + 潮', blurb: '潮里的星', bonusDamage: 12, energy: 1)
  ),
  (
    '星',
    '炎',
    ArenaCombo(name: '星炎', formula: '星 + 炎', blurb: '燃烧的星', bonusDamage: 24)
  ),
  (
    '星',
    '光',
    ArenaCombo(name: '星辉', formula: '星 + 光', blurb: '星辉直射', bonusDamage: 18)
  ),
  (
    '星',
    '影',
    ArenaCombo(name: '星影', formula: '星 + 影', blurb: '星落入影', bonusDamage: 16)
  ),
  (
    '刃',
    '霜',
    ArenaCombo(name: '霜刃', formula: '刃 + 霜', blurb: '寒铁', bonusDamage: 20)
  ),
  (
    '刃',
    '月',
    ArenaCombo(
        name: '月刃', formula: '刃 + 月', blurb: '月下出刀', bonusDamage: 12, heal: 8)
  ),
  (
    '刃',
    '潮',
    ArenaCombo(name: '潮刃', formula: '刃 + 潮', blurb: '潮水送刃', bonusDamage: 18)
  ),
  (
    '刃',
    '炎',
    ArenaCombo(name: '炎刃', formula: '刃 + 炎', blurb: '灼热斩', bonusDamage: 26)
  ),
  (
    '刃',
    '光',
    ArenaCombo(name: '光刃', formula: '刃 + 光', blurb: '光之刃', bonusDamage: 22)
  ),
  (
    '刃',
    '影',
    ArenaCombo(name: '影刃', formula: '刃 + 影', blurb: '无声一刀', bonusDamage: 20)
  ),
  (
    '霜',
    '月',
    ArenaCombo(
        name: '霜月', formula: '霜 + 月', blurb: '冷月光', heal: 16, bonusDamage: 8)
  ),
  (
    '霜',
    '潮',
    ArenaCombo(name: '霜潮', formula: '霜 + 潮', blurb: '冰潮', bonusDamage: 16)
  ),
  (
    '霜',
    '炎',
    ArenaCombo(
        name: '霜火',
        formula: '霜 + 炎',
        blurb: '蒸汽爆发',
        bonusDamage: 10,
        heal: 8,
        splash: 8)
  ),
  (
    '霜',
    '光',
    ArenaCombo(name: '霜光', formula: '霜 + 光', blurb: '折射', bonusDamage: 18)
  ),
  (
    '霜',
    '影',
    ArenaCombo(name: '霜影', formula: '霜 + 影', blurb: '暗霜', bonusDamage: 16)
  ),
  (
    '月',
    '潮',
    ArenaCombo(
        name: '月潮',
        formula: '月 + 潮',
        blurb: '涨潮',
        heal: 12,
        energy: 1,
        bonusDamage: 6)
  ),
  (
    '月',
    '炎',
    ArenaCombo(
        name: '月炎', formula: '月 + 炎', blurb: '暖月', bonusDamage: 10, heal: 10)
  ),
  (
    '月',
    '光',
    ArenaCombo(
        name: '月光', formula: '月 + 光', blurb: '满月', heal: 10, bonusDamage: 12)
  ),
  (
    '月',
    '影',
    ArenaCombo(name: '月影', formula: '月 + 影', blurb: '残月', bonusDamage: 14)
  ),
  (
    '潮',
    '炎',
    ArenaCombo(
        name: '沸潮', formula: '潮 + 炎', blurb: '沸腾溅射', bonusDamage: 8, splash: 14)
  ),
  (
    '潮',
    '光',
    ArenaCombo(
        name: '潮光', formula: '潮 + 光', blurb: '浪尖反光', bonusDamage: 12, energy: 1)
  ),
  (
    '潮',
    '影',
    ArenaCombo(name: '暗潮', formula: '潮 + 影', blurb: '暗流', bonusDamage: 18)
  ),
  (
    '炎',
    '光',
    ArenaCombo(
        name: '炎光', formula: '炎 + 光', blurb: '灼目', bonusDamage: 10, splash: 16)
  ),
  (
    '炎',
    '影',
    ArenaCombo(name: '炎影', formula: '炎 + 影', blurb: '黑焰', bonusDamage: 22)
  ),
  (
    '光',
    '影',
    ArenaCombo(
        name: '光影', formula: '光 + 影', blurb: '明暗交界', bonusDamage: 16, energy: 1)
  ),
];

const List<(String, String, String, ArenaCombo)> _tripleRows = [
  (
    '星',
    '刃',
    '霜',
    ArenaCombo(
        name: '三色极光',
        formula: '星 + 刃 + 霜',
        blurb: '三色齐射',
        bonusDamage: 28,
        energy: 1)
  ),
  (
    '星',
    '月',
    '潮',
    ArenaCombo(
        name: '潮汐祈愿',
        formula: '星 + 月 + 潮',
        blurb: '潮与月一起托住星',
        heal: 18,
        energy: 1,
        bonusDamage: 8)
  ),
  (
    '刃',
    '炎',
    '影',
    ArenaCombo(
        name: '终焉三连', formula: '刃 + 炎 + 影', blurb: '收束斩', bonusDamage: 36)
  ),
  (
    '霜',
    '月',
    '光',
    ArenaCombo(
        name: '霜月光华',
        formula: '霜 + 月 + 光',
        blurb: '冷光回血',
        heal: 16,
        bonusDamage: 12)
  ),
  (
    '潮',
    '炎',
    '光',
    ArenaCombo(
        name: '沸腾星潮',
        formula: '潮 + 炎 + 光',
        blurb: '全场沸腾',
        splash: 18,
        bonusDamage: 12)
  ),
  (
    '星',
    '光',
    '影',
    ArenaCombo(
        name: '昼夜交界',
        formula: '星 + 光 + 影',
        blurb: '明暗同时落下',
        bonusDamage: 24,
        energy: 1)
  ),
  (
    '刃',
    '刃',
    '刃',
    ArenaCombo(
        name: '无尽连斩', formula: '刃 + 刃 + 刃', blurb: '同一把刀砍到底', bonusDamage: 34)
  ),
  (
    '月',
    '月',
    '月',
    ArenaCombo(name: '满月结界', formula: '月 + 月 + 月', blurb: '三轮月', heal: 28)
  ),
  (
    '炎',
    '炎',
    '炎',
    ArenaCombo(
        name: '焚天',
        formula: '炎 + 炎 + 炎',
        blurb: '场子烧起来',
        bonusDamage: 16,
        splash: 22)
  ),
  (
    '星',
    '星',
    '星',
    ArenaCombo(
        name: '星河倾泻',
        formula: '星 + 星 + 星',
        blurb: '星河',
        bonusDamage: 22,
        energy: 2)
  ),
  (
    '霜',
    '潮',
    '影',
    ArenaCombo(
        name: '永夜冰潮',
        formula: '霜 + 潮 + 影',
        blurb: '夜里的冰潮',
        bonusDamage: 20,
        energy: 1)
  ),
  (
    '刃',
    '月',
    '光',
    ArenaCombo(
        name: '月下光刃',
        formula: '刃 + 月 + 光',
        blurb: '月照见刀',
        bonusDamage: 18,
        heal: 12)
  ),
];
