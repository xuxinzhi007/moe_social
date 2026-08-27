import 'package:flutter/material.dart';
import '../../models/achievement_badge.dart';

/// 成就 ID → 个性化图标（替代列表里单纯 emoji 展示）
IconData achievementIconForId(String id) {
  switch (id) {
    case 'welcome_aboard':
      return Icons.waving_hand_rounded;
    case 'first_post':
      return Icons.eco_rounded;
    case 'post_master':
      return Icons.article_rounded;
    case 'like_magnet':
      return Icons.favorite_rounded;
    case 'social_butterfly':
      return Icons.forum_rounded;
    case 'generous_giver':
      return Icons.card_giftcard_rounded;
    case 'gift_tycoon':
      return Icons.savings_rounded;
    case 'emotion_expert':
      return Icons.theater_comedy_rounded;
    case 'early_bird':
      return Icons.wb_sunny_rounded;
    case 'night_owl':
      return Icons.nights_stay_rounded;
    case 'loyal_user':
      return Icons.verified_rounded;
    case 'daily_task_keeper':
      return Icons.event_available_rounded;
    case 'weekly_task_keeper':
      return Icons.date_range_rounded;
    case 'vip_member':
      return Icons.diamond_rounded;
    case 'trendsetter':
      return Icons.local_fire_department_rounded;
    case 'photographer':
      return Icons.photo_camera_rounded;
    case 'influencer':
      return Icons.record_voice_over_rounded;
    case 'creative_genius':
      return Icons.lightbulb_rounded;
    case 'storyteller':
      return Icons.menu_book_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

extension AchievementBadgeVisualX on AchievementBadge {
  IconData get badgeSymbol => achievementIconForId(id);
}

/// 徽章 id → `MoeIcon` name 映射表（阶段4：emoji/占位图标 → 统一 SVG 图标）。
///
/// 不改模型字段与数据源：仅在 UI 渲染层按服务端驱动的徽章 id 查表；
/// 能映射的走 MoeIcon（assets/icons/ui/ 定制 SVG），映射不到的
/// 保留 [achievementIconForId] 的 Material 图标渲染兜底（不白屏）。
const Map<String, String> kBadgeMoeIconNames = {
  'welcome_aboard': 'sparkle', // ✨ 初来乍到
  'like_magnet': 'heart', // 🧲 点赞收割机（点赞≈爱心）
  'generous_giver': 'gift', // 🎁 慷慨之星
  'gift_tycoon': 'trophy', // 💰 礼物大亨（礼物成就≈奖杯）
  'loyal_user': 'star', // ⭐ 忠实用户
  'daily_task_keeper': 'calendar', // 📅 日常打卡王
  'weekly_task_keeper': 'calendar', // 🗓️ 周常执行官
  'vip_member': 'crown', // 👑 VIP会员
  'trendsetter': 'flame', // 🔥 潮流引领者
  'creative_genius': 'sparkle', // 💡 创意天才（灵感闪光）
  // 未映射（9 枚：first_post/post_master/social_butterfly/emotion_expert/
  // early_bird/night_owl/photographer/influencer/storyteller）：
  // 现有 12 枚 SVG 中无近义图形（medal/diamond/bolt 语义不合），待图标集扩充后补录。
};

/// 查徽章对应的 MoeIcon name；返回 null 表示未映射，调用方应保留原渲染。
String? moeIconNameForBadge(AchievementBadge badge) =>
    kBadgeMoeIconNames[badge.id];
