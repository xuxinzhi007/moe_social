/// 图鉴卡牌原料。元素用来搭配组合技，附加效果在出牌时额外结算。
class ArenaCatalogEntry {
  const ArenaCatalogEntry({
    required this.name,
    required this.element,
    required this.cost,
    required this.damage,
    required this.icon,
    required this.color,
    required this.trait,
    required this.targeting,
  });

  final String name;
  final String element;
  final int cost;
  final int damage;
  final String icon;
  final int color;
  final String trait;

  /// single_enemy / all_enemies / ally_team
  final String targeting;

  String get description {
    final aim = switch (targeting) {
      'all_enemies' => '全体',
      'ally_team' => '治疗',
      _ => '单体',
    };
    final rider = trait == '无' ? '' : ' · 附加$trait';
    return '$element · $aim$rider';
  }
}

class ArenaCardCatalog {
  const ArenaCardCatalog._();

  static const List<String> traits = ['无', '破甲', '连击', '回能', '溅射', '续航'];

  static final List<ArenaCatalogEntry> entries = [
    for (final element in _elementNames.keys)
      for (var index = 0; index < _patterns.length; index++)
        _build(element, index),
  ];

  static List<ArenaCatalogEntry> ofElement(String element) {
    if (element == '全部') return entries;
    return entries.where((entry) => entry.element == element).toList();
  }

  static ArenaCatalogEntry _build(String element, int index) {
    final pattern = _patterns[index];
    final style = _elementStyle[element]!;
    return ArenaCatalogEntry(
      name: _elementNames[element]![index],
      element: element,
      cost: pattern.$1,
      damage: pattern.$2,
      icon: style.$1,
      color: style.$2,
      trait: pattern.$3,
      targeting: pattern.$4,
    );
  }
}

/// cost, damage, trait, targeting
const List<(int, int, String, String)> _patterns = [
  (1, 12, '连击', 'single_enemy'),
  (1, -14, '续航', 'ally_team'),
  (2, 22, '破甲', 'single_enemy'),
  (2, 18, '回能', 'single_enemy'),
  (2, 16, '溅射', 'single_enemy'),
  (3, 34, '无', 'single_enemy'),
  (3, 18, '无', 'all_enemies'),
  (4, 26, '破甲', 'all_enemies'),
];

const Map<String, List<String>> _elementNames = {
  '星': ['星屑', '星幕', '星刺', '星环', '星瀑', '星爆', '星雨', '星陨'],
  '刃': ['快斩', '磨刃', '断切', '回刃', '横斩', '居合', '刃风', '终斩'],
  '霜': ['霜针', '霜息', '霜切', '霜返', '霜溅', '霜封', '霜暴', '霜潮'],
  '月': ['月牙', '月抚', '月斩', '月回流', '月溅', '满月斩', '月瀑', '月陨'],
  '潮': ['潮点', '潮息', '潮刺', '潮返', '潮溅', '怒潮', '潮啸', '潮决'],
  '炎': ['火星', '暖炎', '炎刺', '回火', '炎溅', '烈焰', '炎雨', '焚天斩'],
  '光': ['光点', '光愈', '光刺', '光返', '光溅', '闪光', '光雨', '光裁'],
  '影': ['影针', '影息', '影切', '影返', '影溅', '暗袭', '影雨', '影决'],
};

const Map<String, (String, int)> _elementStyle = {
  '星': ('✦', 0xFF69C5E3),
  '刃': ('⚔', 0xFFE6B64F),
  '霜': ('❄', 0xFF79B9B0),
  '月': ('☽', 0xFFB08BD1),
  '潮': ('❈', 0xFF5B8DEF),
  '炎': ('✹', 0xFFD4476A),
  '光': ('✧', 0xFFF0D78C),
  '影': ('☾', 0xFF6B5B95),
};
