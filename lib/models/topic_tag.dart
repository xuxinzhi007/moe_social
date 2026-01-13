import 'package:flutter/material.dart';

/// 话题标签模型 - 支持用户自定义创建
class TopicTag {
  final String id;
  final String name;
  final String? createdBy; // 创建者ID
  final DateTime createdAt;
  final int usageCount; // 使用次数
  final Color color; // 标签颜色（自动生成或用户选择）
  final String? description;
  final bool isOfficial; // 是否为官方标签
  final List<String> relatedTags; // 相关标签

  const TopicTag({
    required this.id,
    required this.name,
    this.createdBy,
    required this.createdAt,
    this.usageCount = 0,
    required this.color,
    this.description,
    this.isOfficial = false,
    this.relatedTags = const [],
  });

  /// 从用户输入创建新标签
  factory TopicTag.createFromInput({
    required String name,
    required String userId,
    String? description,
  }) {
    return TopicTag(
      id: _generateTagId(name),
      name: name.trim(),
      createdBy: userId,
      createdAt: DateTime.now(),
      usageCount: 1,
      color: _generateColorFromString(name),
      description: description?.trim(),
      isOfficial: false,
    );
  }

  /// 生成标签ID（基于名称的哈希）
  static String _generateTagId(String name) {
    final cleanName = name.trim().toLowerCase().replaceAll(' ', '_');
    return 'tag_${cleanName}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 根据字符串生成颜色
  static Color _generateColorFromString(String input) {
    final colors = [
      const Color(0xFF42A5F5), // 蓝色
      const Color(0xFF66BB6A), // 绿色
      const Color(0xFFFF7043), // 橙色
      const Color(0xFFAB47BC), // 紫色
      const Color(0xFF26C6DA), // 青色
      const Color(0xFFFFCA28), // 黄色
      const Color(0xFFEF5350), // 红色
      const Color(0xFF78909C), // 灰蓝
      const Color(0xFFFFB74D), // 橘黄
      const Color(0xFF9CCC65), // 浅绿
    ];

    final hash = input.toLowerCase().hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// 一些官方推荐的热门标签
  static List<TopicTag> get officialTags => [
    TopicTag(
      id: 'daily_life',
      name: '日常生活',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      usageCount: 1250,
      color: const Color(0xFF42A5F5),
      description: '分享日常生活的点点滴滴',
      isOfficial: true,
    ),
    TopicTag(
      id: 'mood',
      name: '心情随笔',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      usageCount: 980,
      color: const Color(0xFFAB47BC),
      description: '记录内心的感受和想法',
      isOfficial: true,
    ),
    TopicTag(
      id: 'food',
      name: '美食分享',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      usageCount: 750,
      color: const Color(0xFFFF7043),
      description: '晒出你的美食时刻',
      isOfficial: true,
    ),
    TopicTag(
      id: 'travel',
      name: '旅行记录',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      usageCount: 650,
      color: const Color(0xFF66BB6A),
      description: '记录旅途中的美好瞬间',
      isOfficial: true,
    ),
    TopicTag(
      id: 'work',
      name: '工作日志',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      usageCount: 420,
      color: const Color(0xFF78909C),
      description: '职场生活和工作感悟',
      isOfficial: true,
    ),
    TopicTag(
      id: 'study',
      name: '学习笔记',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      usageCount: 380,
      color: const Color(0xFF26C6DA),
      description: '知识学习和成长记录',
      isOfficial: true,
    ),
  ];

  /// 复制并更新使用次数
  TopicTag copyWithIncrementUsage() {
    return TopicTag(
      id: id,
      name: name,
      createdBy: createdBy,
      createdAt: createdAt,
      usageCount: usageCount + 1,
      color: color,
      description: description,
      isOfficial: isOfficial,
      relatedTags: relatedTags,
    );
  }

  /// 从JSON创建实例
  factory TopicTag.fromJson(Map<String, dynamic> json) {
    try {
      print('🏷️ 解析话题标签JSON: $json');
      
      // 解析颜色，支持十六进制字符串和整数
      Color color;
      final colorValue = json['color'];
      if (colorValue is String) {
        // 处理十六进制颜色字符串
        try {
          final hexString = colorValue.replaceAll('#', '');
          final colorInt = int.parse(hexString, radix: 16);
          color = Color(colorInt | 0xFF000000); // 添加alpha通道
        } catch (e) {
          print('⚠️ 颜色解析失败: $e，使用默认颜色');
          // 如果解析失败，使用默认颜色
          color = const Color(0xFF42A5F5);
        }
      } else if (colorValue is int) {
        // 处理整数颜色值
        color = Color(colorValue);
      } else {
        // 默认为蓝色
        color = const Color(0xFF42A5F5);
      }

      // 处理下划线命名和驼峰命名的兼容，确保即使没有日期字段也能正常解析
      DateTime createdAt;
      final createdAtStr = json['created_at'] as String? ?? json['createdAt'] as String?;
      if (createdAtStr != null && createdAtStr.isNotEmpty) {
        try {
          createdAt = DateTime.parse(createdAtStr);
        } catch (e) {
          print('⚠️ 日期解析失败: $e，使用当前时间');
          createdAt = DateTime.now();
        }
      } else {
        // 如果没有日期字段或日期字段为空，使用当前时间
        print('⚠️ 没有日期字段，使用当前时间');
        createdAt = DateTime.now();
      }
      
      final usageCount = (json['usage_count'] as int?) ?? (json['usageCount'] as int?) ?? 0;
      final isOfficial = (json['is_official'] as bool?) ?? (json['isOfficial'] as bool?) ?? false;
      final createdBy = json['created_by'] as String? ?? json['createdBy'] as String?;
      final description = json['description'] as String?;
      final relatedTags = (json['related_tags'] as List<dynamic>?)?.cast<String>() ?? 
                        (json['relatedTags'] as List<dynamic>?)?.cast<String>() ?? [];

      // 确保id和name字段存在，支持数字和字符串格式
      final idValue = json['id'];
      final id = idValue?.toString() ?? '';
      final name = json['name']?.toString() ?? '';
      
      print('🏷️ 解析标签字段: id=$idValue (${idValue.runtimeType}) -> "$id", name="$name"');
      
      if (id.isEmpty || name.isEmpty) {
        throw Exception('话题标签缺少必要字段: id=$id, name=$name');
      }

      final tag = TopicTag(
        id: id,
        name: name,
        createdBy: createdBy,
        createdAt: createdAt,
        usageCount: usageCount,
        color: color,
        description: description,
        isOfficial: isOfficial,
        relatedTags: relatedTags,
      );
      
      print('✅ 成功解析话题标签: $name (ID: $id)');
      return tag;
    } catch (e, stackTrace) {
      print('❌ TopicTag.fromJson错误: $e');
      print('❌ JSON数据: $json');
      print('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'usageCount': usageCount,
      'color': '#${color.value.toRadixString(16).substring(2).padLeft(6, '0')}', // 转换为十六进制颜色字符串
      'description': description,
      'isOfficial': isOfficial,
      'relatedTags': relatedTags,
    };
  }

  /// 验证标签名称是否合法
  static bool isValidTagName(String name) {
    final trimmed = name.trim();

    // 长度检查
    if (trimmed.isEmpty || trimmed.length > 20) return false;

    // 字符检查（只允许中英文、数字、部分符号）
    final validPattern = RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9\s\-_#@]+$');
    if (!validPattern.hasMatch(trimmed)) return false;

    // 不允许纯数字或纯符号
    if (RegExp(r'^[\d\s\-_#@]+$').hasMatch(trimmed)) return false;

    return true;
  }

  /// 清理标签名称（去除多余空格，统一格式）
  static String cleanTagName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // 合并多个空格为一个
        .replaceAll('#', '') // 去除#号
        .replaceAll('@', ''); // 去除@号
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicTag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 标签服务类 - 管理标签的创建、搜索等
class TopicTagService {
  static final TopicTagService _instance = TopicTagService._internal();
  factory TopicTagService() => _instance;
  TopicTagService._internal();

  // 内存缓存
  final List<TopicTag> _allTags = [...TopicTag.officialTags];
  final Map<String, int> _searchHistory = {};

  /// 搜索标签
  List<TopicTag> searchTags(String query, {int limit = 10}) {
    if (query.trim().isEmpty) {
      return getPopularTags(limit: limit);
    }

    final lowerQuery = query.toLowerCase();

    // 记录搜索历史
    _searchHistory[lowerQuery] = (_searchHistory[lowerQuery] ?? 0) + 1;

    // 搜索匹配的标签
    final matches = _allTags.where((tag) {
      return tag.name.toLowerCase().contains(lowerQuery) ||
             (tag.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    // 按相关度排序（使用次数 + 名称匹配度）
    matches.sort((a, b) {
      final aScore = _calculateRelevanceScore(a, lowerQuery);
      final bScore = _calculateRelevanceScore(b, lowerQuery);
      return bScore.compareTo(aScore);
    });

    return matches.take(limit).toList();
  }

  /// 计算标签相关度得分
  int _calculateRelevanceScore(TopicTag tag, String query) {
    int score = tag.usageCount;

    // 名称完全匹配加分
    if (tag.name.toLowerCase() == query) {
      score += 1000;
    }
    // 名称开头匹配加分
    else if (tag.name.toLowerCase().startsWith(query)) {
      score += 500;
    }
    // 官方标签加分
    if (tag.isOfficial) {
      score += 200;
    }

    return score;
  }

  /// 获取热门标签
  List<TopicTag> getPopularTags({int limit = 6}) {
    final sorted = List<TopicTag>.from(_allTags);
    sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(limit).toList();
  }

  /// 获取最近使用的标签
  List<TopicTag> getRecentTags(String userId, {int limit = 5}) {
    // TODO: 这里应该从本地存储或API获取用户的使用历史
    // 暂时返回热门标签作为示例
    return getPopularTags(limit: limit);
  }

  /// 创建或获取标签
  TopicTag getOrCreateTag(String name, String userId) {
    final cleanName = TopicTag.cleanTagName(name);

    // 查找已存在的标签（不区分大小写）
    try {
      final existing = _allTags.firstWhere(
        (tag) => tag.name.toLowerCase() == cleanName.toLowerCase(),
      );

      // 增加使用次数
      final updated = existing.copyWithIncrementUsage();
      final index = _allTags.indexOf(existing);
      _allTags[index] = updated;

      return updated;
    } catch (e) {
      // 标签不存在，创建新标签
      final newTag = TopicTag.createFromInput(
        name: cleanName,
        userId: userId,
      );

      _allTags.add(newTag);
      return newTag;
    }
  }

  /// 获取推荐标签（基于用户历史）
  List<TopicTag> getRecommendedTags(String userId, {int limit = 8}) {
    // TODO: 实现基于用户历史的智能推荐算法
    // 这里暂时返回热门标签和一些变化
    final popular = getPopularTags(limit: limit ~/ 2);
    final recent = getRecentTags(userId, limit: limit - popular.length);

    return [...popular, ...recent].take(limit).toList();
  }
}