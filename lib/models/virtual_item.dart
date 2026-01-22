enum ItemRarity {
  n, // 普通
  r, // 稀有
  sr, // 史诗
  ssr, // 传说
}

enum ItemType {
  avatarFrame, // 头像框
  enterEffect, // 进场特效
  gift, // 礼物
  post, // 心情（原有的功能）
}

class VirtualItem {
  final String id;
  final String name;
  final String description;
  final String iconUrl; // 预览图
  final ItemType type;
  final ItemRarity rarity;
  final Map<String, dynamic>? metadata; // 额外数据，比如特效的参数

  const VirtualItem({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.type,
    required this.rarity,
    this.metadata,
  });

  // 辅助方法：获取稀有度颜色
  int get rarityColor {
    switch (rarity) {
      case ItemRarity.n: return 0xFFB0B0B0; // 灰/白
      case ItemRarity.r: return 0xFF42A5F5; // 蓝
      case ItemRarity.sr: return 0xFFAB47BC; // 紫
      case ItemRarity.ssr: return 0xFFFFD700; // 金
    }
  }
  
  // 辅助方法：获取稀有度文本
  String get rarityLabel {
    switch (rarity) {
      case ItemRarity.n: return 'N';
      case ItemRarity.r: return 'R';
      case ItemRarity.sr: return 'SR';
      case ItemRarity.ssr: return 'SSR';
    }
  }

  // 模拟一些预设物品
  static List<VirtualItem> get mockItems => [
    const VirtualItem(
      id: 'frame_cyber_01',
      name: '赛博流光',
      description: '来自2077年的霓虹光圈',
      iconUrl: '', // 实际开发中填入资源路径
      type: ItemType.avatarFrame,
      rarity: ItemRarity.ssr,
    ),
    const VirtualItem(
      id: 'frame_sakura_01',
      name: '樱花飞舞',
      description: '春天到了，去赏樱吧',
      iconUrl: '',
      type: ItemType.avatarFrame,
      rarity: ItemRarity.ssr,
    ),
    const VirtualItem(
      id: 'frame_lottie_test',
      name: '动态测试',
      description: 'Lottie 动画测试专用',
      iconUrl: '',
      type: ItemType.avatarFrame,
      rarity: ItemRarity.ssr,
    ),
    const VirtualItem(
      id: 'effect_vip_entry',
      name: '至尊降临',
      description: '进场时自带BGM和闪光灯',
      iconUrl: '',
      type: ItemType.enterEffect,
      rarity: ItemRarity.sr,
    ),
    const VirtualItem(
      id: 'gift_coffee',
      name: '热咖啡',
      description: '给熬夜的Ta一杯温暖',
      iconUrl: '',
      type: ItemType.gift,
      rarity: ItemRarity.n,
    ),
  ];
}
