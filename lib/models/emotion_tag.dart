import 'package:flutter/material.dart';

/// 情绪标签模型
class EmotionTag {
  final String id;
  final String name;
  final Color color;
  final String description;
  final String category; // 标签分类
  final IconData icon; // 使用Material图标

  const EmotionTag({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.category,
    required this.icon,
  });

  // 预定义的情绪标签
  static const List<EmotionTag> defaultTags = [
    EmotionTag(
      id: 'happy',
      name: '开心',
      emoji: '😊',
      color: Color(0xFFFFB74D),
      description: '心情愉悦，充满正能量',
    ),
    EmotionTag(
      id: 'excited',
      name: '兴奋',
      emoji: '🤩',
      color: Color(0xFFFF7043),
      description: '激动不已，兴奋满分',
    ),
    EmotionTag(
      id: 'love',
      name: '恋爱',
      emoji: '🥰',
      color: Color(0xFFE91E63),
      description: '甜蜜浪漫，爱意满满',
    ),
    EmotionTag(
      id: 'calm',
      name: '平静',
      emoji: '😌',
      color: Color(0xFF66BB6A),
      description: '内心宁静，岁月静好',
    ),
    EmotionTag(
      id: 'thoughtful',
      name: '思考',
      emoji: '🤔',
      color: Color(0xFF9C27B0),
      description: '深度思考，哲学时刻',
    ),
    EmotionTag(
      id: 'tired',
      name: '疲惫',
      emoji: '😴',
      color: Color(0xFF78909C),
      description: '身心俱疲，需要休息',
    ),
    EmotionTag(
      id: 'sad',
      name: '难过',
      emoji: '😢',
      color: Color(0xFF5C6BC0),
      description: '心情低落，需要安慰',
    ),
    EmotionTag(
      id: 'angry',
      name: '生气',
      emoji: '😠',
      color: Color(0xFFF44336),
      description: '愤怒情绪，需要发泄',
    ),
    EmotionTag(
      id: 'surprised',
      name: '惊讶',
      emoji: '😱',
      color: Color(0xFF00BCD4),
      description: '出乎意料，大吃一惊',
    ),
    EmotionTag(
      id: 'grateful',
      name: '感谢',
      emoji: '🙏',
      color: Color(0xFF8BC34A),
      description: '心怀感恩，感谢生活',
    ),
  ];

  // 从JSON创建实例
  factory EmotionTag.fromJson(Map<String, dynamic> json) {
    return EmotionTag(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      color: Color(json['color'] as int),
      description: json['description'] as String,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color': color.value,
      'description': description,
    };
  }

  // 根据ID查找标签
  static EmotionTag? findById(String id) {
    try {
      return defaultTags.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  // 获取热门标签（前6个）
  static List<EmotionTag> getPopularTags() {
    return defaultTags.take(6).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmotionTag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}