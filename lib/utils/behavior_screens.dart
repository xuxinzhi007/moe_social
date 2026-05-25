/// 路由名 → 行为采集 screen key 映射。
class BehaviorScreens {
  static String fromRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return 'unknown';
    }
    const mapping = {
      '/login': 'login',
      '/register': 'register',
      '/home': 'home',
      '/profile': 'profile',
      '/achievements': 'achievements',
      '/settings': 'settings',
      '/virtual-avatar-settings': 'virtual_avatar',
      '/message-retention-settings': 'message_retention',
      '/checkin': 'checkin',
      '/conversations': 'conversations',
      '/direct-chat': 'chat',
      '/community': 'community',
      '/community-post-detail': 'post_detail',
      '/interest-group-detail': 'interest_group',
      '/create-post': 'create_post',
      '/comments': 'comments',
      '/topic-posts': 'topic_posts',
      '/notifications': 'notifications',
      '/edit-profile': 'edit_profile',
      '/friends': 'friends',
      '/user-profile': 'user_profile',
      '/user-qr-code': 'user_qr',
      '/scan': 'scan',
      '/cloud-gallery': 'cloud_gallery',
      '/vip-center': 'vip_center',
      '/vip-purchase': 'vip_purchase',
      '/vip-orders': 'vip_orders',
      '/vip-history': 'vip_history',
      '/wallet': 'wallet',
      '/recharge': 'recharge',
      '/order-center': 'order_center',
      '/gacha': 'gacha',
      '/explore-match': 'explore_match',
      '/forgot-password': 'forgot_password',
      '/reset-password': 'reset_password',
      '/verify-code': 'verify_code',
    };
    return mapping[routeName] ?? _fallback(routeName);
  }

  static String _fallback(String routeName) {
    var key = routeName.startsWith('/') ? routeName.substring(1) : routeName;
    key = key.replaceAll('-', '_').replaceAll('/', '_');
    if (key.isEmpty) return 'unknown';
    return key;
  }
}
