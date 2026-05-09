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
