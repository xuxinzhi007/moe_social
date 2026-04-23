import 'package:flutter/material.dart';

/// 虚拟礼物模型
class Gift {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final double price; // 礼物价格
  final Color color;
  final GiftCategory category;
  final int popularity; // 人气值，用于排序
  /// 当前用户在背包中拥有数量（来自 `/api/gifts?user_id=`）
  final int ownedQuantity;

  const Gift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
    required this.color,
    required this.category,
    this.popularity = 0,
    this.ownedQuantity = 0,
  });

  Gift copyWith({
    String? id,
    String? name,
    String? emoji,
    String? description,
    double? price,
    Color? color,
    GiftCategory? category,
    int? popularity,
    int? ownedQuantity,
  }) {
    return Gift(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      price: price ?? this.price,
      color: color ?? this.color,
      category: category ?? this.category,
      popularity: popularity ?? this.popularity,
      ownedQuantity: ownedQuantity ?? this.ownedQuantity,
    );
  }

  // 预定义的礼物列表
  static const List<Gift> defaultGifts = [
    // 基础礼物 (0.1 - 1.0)
    Gift(
      id: 'heart',
      name: '爱心',
      emoji: '❤️',
      description: '传递温暖的爱意',
      price: 0.1,
      color: Color(0xFFE91E63),
      category: GiftCategory.emotion,
      popularity: 100,
    ),
    Gift(
      id: 'flower',
      name: '鲜花',
      emoji: '🌹',
      description: '美丽的玫瑰花',
      price: 0.5,
      color: Color(0xFFE57373),
      category: GiftCategory.emotion,
      popularity: 95,
    ),
    Gift(
      id: 'thumbsup',
      name: '点赞',
      emoji: '👍',
      description: '给你一个大大的赞',
      price: 0.2,
      color: Color(0xFF42A5F5),
      category: GiftCategory.emotion,
      popularity: 90,
    ),
    Gift(
      id: 'clap',
      name: '掌声',
      emoji: '👏',
      description: '为你精彩的分享鼓掌',
      price: 0.3,
      color: Color(0xFFFFB74D),
      category: GiftCategory.emotion,
      popularity: 85,
    ),
    Gift(
      id: 'hug',
      name: '拥抱',
      emoji: '🤗',
      description: '给你一个温暖的拥抱',
      price: 0.8,
      color: Color(0xFF81C784),
      category: GiftCategory.emotion,
      popularity: 80,
    ),

    // 食物礼物 (1.0 - 5.0)
    Gift(
      id: 'coffee',
      name: '咖啡',
      emoji: '☕',
      description: '香浓的咖啡为你提神',
      price: 2.0,
      color: Color(0xFF8D6E63),
      category: GiftCategory.food,
      popularity: 75,
    ),
    Gift(
      id: 'cake',
      name: '蛋糕',
      emoji: '🎂',
      description: '甜蜜的生日蛋糕',
      price: 5.0,
      color: Color(0xFFBA68C8),
      category: GiftCategory.food,
      popularity: 70,
    ),
    Gift(
      id: 'ice_cream',
      name: '冰淇淋',
      emoji: '🍦',
      description: '清爽的冰淇淋',
      price: 3.0,
      color: Color(0xFF4FC3F7),
      category: GiftCategory.food,
      popularity: 65,
    ),
    Gift(
      id: 'wine',
      name: '香槟',
      emoji: '🍾',
      description: '庆祝时刻的香槟',
      price: 8.0,
      color: Color(0xFFFFD54F),
      category: GiftCategory.food,
      popularity: 60,
    ),

    // 奢华礼物 (10.0+)
    Gift(
      id: 'diamond',
      name: '钻石',
      emoji: '💎',
      description: '闪闪发光的钻石',
      price: 50.0,
      color: Color(0xFF64B5F6),
      category: GiftCategory.luxury,
      popularity: 95,
    ),
    Gift(
      id: 'crown',
      name: '皇冠',
      emoji: '👑',
      description: '尊贵的皇冠',
      price: 100.0,
      color: Color(0xFFFFD700),
      category: GiftCategory.luxury,
      popularity: 90,
    ),
    Gift(
      id: 'rocket',
      name: '火箭',
      emoji: '🚀',
      description: '让你的内容飞向太空',
      price: 200.0,
      color: Color(0xFFFF5722),
      category: GiftCategory.luxury,
      popularity: 85,
    ),
    Gift(
      id: 'rainbow',
      name: '彩虹',
      emoji: '🌈',
      description: '七彩斑斓的彩虹',
      price: 30.0,
      color: Color(0xFF9C27B0),
      category: GiftCategory.special,
      popularity: 75,
    ),
    Gift(
      id: 'fireworks',
      name: '烟花',
      emoji: '🎆',
      description: '绚烂的烟花表演',
      price: 20.0,
      color: Color(0xFFE040FB),
      category: GiftCategory.special,
      popularity: 80,
    ),
    Gift(
      id: 'unicorn',
      name: '独角兽',
      emoji: '🦄',
      description: '神奇的独角兽',
      price: 66.6,
      color: Color(0xFFAB47BC),
      category: GiftCategory.special,
      popularity: 70,
    ),
  ];

  /// 后端送礼接口按 **数据库 uint 主键** 解析 [id]；内置 [defaultGifts] 使用英文 slug，不能用于扣费送礼。
  bool get canSendViaBackendApi {
    final n = int.tryParse(id);
    return n != null && n > 0;
  }

  /// 后端 `/api/gifts` 返回的条目（无 emoji 字段，用 [icon] 或占位）
  factory Gift.fromCatalogApi(Map<String, dynamic> json) {
    final rawIcon = json['icon'] as String? ?? '';
    final emoji =
        rawIcon.startsWith('http') || rawIcon.isEmpty ? '🎁' : rawIcon;
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    return Gift(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : '礼物',
      emoji: emoji,
      description: json['description'] as String? ?? '',
      price: price,
      color: const Color(0xFFFFB347),
      category: GiftCategory.special,
      popularity: 0,
      ownedQuantity: (json['owned_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  // 从JSON创建实例
  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      color: Color(json['color'] as int),
      category: GiftCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => GiftCategory.emotion,
      ),
      popularity: json['popularity'] as int? ?? 0,
      ownedQuantity: (json['owned_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'price': price,
      'color': color.toARGB32(),
      'category': category.name,
      'popularity': popularity,
      'owned_quantity': ownedQuantity,
    };
  }

  // 根据ID查找礼物
  static Gift? findById(String id) {
    try {
      return defaultGifts.firstWhere((gift) => gift.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根据价格范围获取礼物
  static List<Gift> getGiftsByPriceRange(double minPrice, double maxPrice) {
    return defaultGifts
        .where((gift) => gift.price >= minPrice && gift.price <= maxPrice)
        .toList();
  }

  // 根据分类获取礼物
  static List<Gift> getGiftsByCategory(GiftCategory category) {
    return defaultGifts.where((gift) => gift.category == category).toList();
  }

  // 获取热门礼物
  static List<Gift> getPopularGifts({int limit = 6}) {
    final sortedGifts = List<Gift>.from(defaultGifts);
    sortedGifts.sort((a, b) => b.popularity.compareTo(a.popularity));
    return sortedGifts.take(limit).toList();
  }

  // 获取免费礼物
  static List<Gift> getFreeGifts() {
    return defaultGifts.where((gift) => gift.price == 0.0).toList();
  }

  // 获取按价格排序的礼物
  static List<Gift> getGiftsSortedByPrice({bool ascending = true}) {
    final sortedGifts = List<Gift>.from(defaultGifts);
    sortedGifts.sort((a, b) => ascending
        ? a.price.compareTo(b.price)
        : b.price.compareTo(a.price));
    return sortedGifts;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gift &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownedQuantity == other.ownedQuantity;

  @override
  int get hashCode => Object.hash(id, ownedQuantity);

  GiftLevel get level {
    if (price < 1.0) return GiftLevel.basic;
    if (price < 10.0) return GiftLevel.medium;
    if (price < 50.0) return GiftLevel.advanced;
    return GiftLevel.luxury;
  }

  Duration get animationDuration {
    switch (level) {
      case GiftLevel.basic:
        return const Duration(milliseconds: 1500);
      case GiftLevel.medium:
        return const Duration(milliseconds: 2000);
      case GiftLevel.advanced:
        return const Duration(milliseconds: 2500);
      case GiftLevel.luxury:
        return const Duration(milliseconds: 3500);
    }
  }

  int get particleCount {
    switch (level) {
      case GiftLevel.basic:
        return 8;
      case GiftLevel.medium:
        return 15;
      case GiftLevel.advanced:
        return 25;
      case GiftLevel.luxury:
        return 40;
    }
  }

  double get iconSize {
    switch (level) {
      case GiftLevel.basic:
        return 60;
      case GiftLevel.medium:
        return 80;
      case GiftLevel.advanced:
        return 100;
      case GiftLevel.luxury:
        return 120;
    }
  }

  double get glowRadius {
    switch (level) {
      case GiftLevel.basic:
        return 10;
      case GiftLevel.medium:
        return 20;
      case GiftLevel.advanced:
        return 30;
      case GiftLevel.luxury:
        return 50;
    }
  }
}

/// 礼物等级枚举
enum GiftLevel {
  basic('基础', 0),
  medium('中等', 1),
  advanced('高级', 2),
  luxury('奢华', 3);

  const GiftLevel(this.displayName, this.priority);

  final String displayName;
  final int priority;
}

/// 礼物分类枚举
enum GiftCategory {
  emotion('情感', '❤️'),
  food('美食', '🍰'),
  luxury('奢华', '💎'),
  special('特殊', '🌟');

  const GiftCategory(this.displayName, this.icon);

  final String displayName;
  final String icon;
}

/// 礼物记录模型（用于记录发送/接收礼物的历史）
class GiftRecord {
  final String id;
  final String giftId;
  final String senderId;
  final String receiverId;
  final String targetType; // 'post' 或 'user'
  final String targetId; // 帖子ID或用户ID
  final double amount; // 支付金额
  final DateTime createdAt;

  GiftRecord({
    required this.id,
    required this.giftId,
    required this.senderId,
    required this.receiverId,
    required this.targetType,
    required this.targetId,
    required this.amount,
    required this.createdAt,
  });

  // 获取礼物信息
  Gift? get gift => Gift.findById(giftId);

  // 从JSON创建实例
  factory GiftRecord.fromJson(Map<String, dynamic> json) {
    return GiftRecord(
      id: json['id'] as String,
      giftId: json['gift_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'gift_id': giftId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'target_type': targetType,
      'target_id': targetId,
      'amount': amount,
    };
  }
}