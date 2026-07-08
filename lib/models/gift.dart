import 'package:flutter/material.dart';

/// 礼物展示模型（目录与价格来自后端，客户端不做商品定义）。
class Gift {
  final String id;
  final String name;
  /// 后端 `icon` 原值（URL、emoji 遗留或空）。
  final String icon;
  final String emoji;
  final String description;
  final double price;
  final Color color;
  final GiftCategory category;
  final int sortOrder;
  final int ownedQuantity;

  const Gift({
    required this.id,
    required this.name,
    this.icon = '',
    required this.emoji,
    required this.description,
    required this.price,
    required this.color,
    required this.category,
    this.sortOrder = 0,
    this.ownedQuantity = 0,
  });

  Gift copyWith({
    String? id,
    String? name,
    String? icon,
    String? emoji,
    String? description,
    double? price,
    Color? color,
    GiftCategory? category,
    int? sortOrder,
    int? ownedQuantity,
  }) {
    return Gift(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      price: price ?? this.price,
      color: color ?? this.color,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      ownedQuantity: ownedQuantity ?? this.ownedQuantity,
    );
  }

  /// 后端送礼/购买接口使用数据库主键字符串。
  bool get canSendViaBackendApi {
    final n = int.tryParse(id);
    return n != null && n > 0;
  }

  /// `icon` 为 http(s) 时使用网络图。
  String? get iconUrl {
    final raw = icon.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  static String _legacyEmojiFromIcon(String rawIcon) {
    if (rawIcon.startsWith('http') || rawIcon.isEmpty) return '🎁';
    return rawIcon;
  }

  /// `GET /api/gifts` 条目
  factory Gift.fromCatalogApi(Map<String, dynamic> json) {
    final rawIcon = json['icon'] as String? ?? '';
    final emoji = _legacyEmojiFromIcon(rawIcon);
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    final category = GiftCategory.fromApi(json['category'] as String?);

    return Gift(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : '礼物',
      icon: rawIcon,
      emoji: emoji,
      description: json['description'] as String? ?? '',
      price: price,
      color: colorForCategory(category),
      category: category,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      ownedQuantity: (json['owned_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  factory Gift.fromJson(Map<String, dynamic> json) {
    final category = GiftCategory.fromApi(json['category'] as String?);
    final rawIcon = json['emoji'] as String? ?? json['icon'] as String? ?? '';
    final emoji = _legacyEmojiFromIcon(rawIcon);

    return Gift(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '礼物',
      icon: rawIcon,
      emoji: emoji,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      color: json['color'] is int
          ? Color(json['color'] as int)
          : colorForCategory(category),
      category: category,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      ownedQuantity: (json['owned_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'emoji': emoji,
      'description': description,
      'price': price,
      'category': category.apiValue,
      'sort_order': sortOrder,
      'owned_quantity': ownedQuantity,
    };
  }

  static Color colorForCategory(GiftCategory category) {
    switch (category) {
      case GiftCategory.emotion:
        return const Color(0xFFE91E63);
      case GiftCategory.food:
        return const Color(0xFF8D6E63);
      case GiftCategory.luxury:
        return const Color(0xFFFFD700);
      case GiftCategory.special:
        return const Color(0xFF9C27B0);
    }
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

  /// 动效档位按后端整数价格划分。
  GiftLevel get level {
    if (price < 5) return GiftLevel.basic;
    if (price < 20) return GiftLevel.medium;
    if (price < 50) return GiftLevel.advanced;
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

enum GiftLevel {
  basic('基础', 0),
  medium('中等', 1),
  advanced('高级', 2),
  luxury('奢华', 3);

  const GiftLevel(this.displayName, this.priority);

  final String displayName;
  final int priority;
}

enum GiftCategory {
  emotion('情感', 'emotion'),
  food('美食', 'food'),
  luxury('奢华', 'luxury'),
  special('特殊', 'special');

  const GiftCategory(this.displayName, this.apiValue);

  final String displayName;
  final String apiValue;

  String get icon {
    switch (this) {
      case GiftCategory.emotion:
        return '❤️';
      case GiftCategory.food:
        return '🍰';
      case GiftCategory.luxury:
        return '💎';
      case GiftCategory.special:
        return '🌟';
    }
  }

  static GiftCategory fromApi(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    for (final c in GiftCategory.values) {
      if (c.apiValue == key) return c;
    }
    return GiftCategory.special;
  }
}

/// 礼物赠送记录（若接口嵌套 gift 对象则一并解析）。
class GiftRecord {
  final String id;
  final String giftId;
  final String senderId;
  final String receiverId;
  final String targetType;
  final String targetId;
  final double amount;
  final DateTime createdAt;
  final Gift? giftDetail;

  GiftRecord({
    required this.id,
    required this.giftId,
    required this.senderId,
    required this.receiverId,
    required this.targetType,
    required this.targetId,
    required this.amount,
    required this.createdAt,
    this.giftDetail,
  });

  Gift? get gift => giftDetail;

  factory GiftRecord.fromJson(Map<String, dynamic> json) {
    Gift? nested;
    final rawGift = json['gift'];
    if (rawGift is Map) {
      nested = Gift.fromCatalogApi(Map<String, dynamic>.from(rawGift));
    }

    return GiftRecord(
      id: json['id']?.toString() ?? '',
      giftId: json['gift_id']?.toString() ?? nested?.id ?? '',
      senderId: json['sender_id']?.toString() ?? json['from_user_id']?.toString() ?? '',
      receiverId:
          json['receiver_id']?.toString() ?? json['to_user_id']?.toString() ?? '',
      targetType: json['target_type'] as String? ?? 'user',
      targetId: json['target_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      giftDetail: nested,
    );
  }

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
