import 'package:flutter/material.dart';

import '../app/deferred_route.dart';
import '../auth_service.dart';
import '../models/community_group.dart';
import '../models/post.dart';
import '../models/topic_tag.dart';
import '../pages/achievements/achievements_page.dart' deferred as achievements;
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/auth/verify_code_page.dart';
import '../pages/chat/conversations_page.dart';
import '../pages/chat/direct_chat_page.dart';
import '../pages/checkin/checkin_page.dart';
import '../pages/commerce/gacha_page.dart' deferred as gacha;
import '../pages/commerce/order_center_page.dart' deferred as order_center;
import '../pages/commerce/recharge_page.dart' deferred as recharge;
import '../pages/commerce/vip_center_page.dart' deferred as vip_center;
import '../pages/commerce/vip_history_page.dart' deferred as vip_history;
import '../pages/commerce/vip_orders_page.dart' deferred as vip_orders;
import '../pages/commerce/vip_purchase_page.dart' deferred as vip_purchase;
import '../pages/commerce/wallet_page.dart' deferred as wallet;
import '../pages/community/community_home_page.dart';
import '../pages/community/community_post_detail_page.dart';
import '../pages/community/interest_group_detail_page.dart';
import '../pages/discover/explore_match_redirect_page.dart';
import '../pages/feed/comments_page.dart';
import '../pages/feed/create_post_page.dart';
import '../pages/feed/topic_posts_page.dart';
import '../pages/gallery/cloud_gallery_page.dart' deferred as cloud_gallery;
import '../pages/announcements/announcements_page.dart';
import '../pages/notifications/notification_center_page.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/profile/friends_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/user_profile_page.dart';
import '../pages/profile/user_qr_code_page.dart';
import '../pages/scan/scan_page.dart' deferred as scan;
import '../pages/settings/message_retention_settings_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/virtual_avatar_settings_page.dart'
    deferred as virtual_avatar_settings;
import 'main_shell.dart' show MainPage;

Widget _deferred(
  Future<void> Function() loadLibrary,
  Widget Function() builder, {
  String message = '加载中…',
}) {
  return DeferredRoute(
    loadLibrary: loadLibrary,
    message: message,
    builder: builder,
  );
}

/// Named routes for [MaterialApp]. Heavy modules use deferred imports.
Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
    '/home': (context) => const MainPage(),
    '/profile': (context) => const ProfilePage(),
    '/achievements': (context) => _deferred(
          achievements.loadLibrary,
          () => achievements.AchievementsPage(),
        ),
    '/settings': (context) => const SettingsPage(),
    '/virtual-avatar-settings': (context) => _deferred(
          virtual_avatar_settings.loadLibrary,
          () => virtual_avatar_settings.VirtualAvatarSettingsPage(),
          message: '正在加载虚拟形象…',
        ),
    '/message-retention-settings': (context) =>
        const MessageRetentionSettingsPage(),
    '/checkin': (context) {
      final userId = AuthService.currentUser;
      if (userId == null || userId.isEmpty) {
        return const Scaffold(
          body: Center(child: Text('请先登录后再签到')),
        );
      }
      return CheckInPage(userId: userId);
    },
    '/create-post': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      Post? initialPost;
      String? groupId;
      if (args is Map) {
        if (args['initialPost'] is Post) {
          initialPost = args['initialPost'] as Post;
        }
        groupId = args['groupId'] as String?;
      } else if (args is Post) {
        initialPost = args;
      }
      return CreatePostPage(initialPost: initialPost, groupId: groupId);
    },
    '/comments': (context) => CommentsPage(
          postId: ModalRoute.of(context)!.settings.arguments as String,
        ),
    '/edit-profile': (context) => EditProfilePage(
          user: ModalRoute.of(context)!.settings.arguments as dynamic,
        ),
    '/vip-center': (context) => _deferred(
          vip_center.loadLibrary,
          () => vip_center.VipCenterPage(),
        ),
    '/vip-purchase': (context) => _deferred(
          vip_purchase.loadLibrary,
          () => vip_purchase.VipPurchasePage(),
        ),
    '/vip-orders': (context) => _deferred(
          vip_orders.loadLibrary,
          () => vip_orders.VipOrdersPage(),
        ),
    '/orders': (context) => _deferred(
          order_center.loadLibrary,
          () => order_center.OrderCenterPage(),
        ),
    '/vip-history': (context) => _deferred(
          vip_history.loadLibrary,
          () => vip_history.VipHistoryPage(),
        ),
    '/forgot-password': (context) => const ForgotPasswordPage(),
    '/verify-code': (context) => VerifyCodePage(
          email: ModalRoute.of(context)!.settings.arguments as String,
        ),
    '/reset-password': (context) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return ResetPasswordPage(
        email: args['email'] as String,
        code: args['code'] as String,
      );
    },
    '/notifications': (context) => const NotificationCenterPage(),
    '/announcements': (context) => const AnnouncementsPage(),
    '/wallet': (context) => _deferred(
          wallet.loadLibrary,
          () => wallet.WalletPage(),
        ),
    '/recharge': (context) => _deferred(
          recharge.loadLibrary,
          () => recharge.RechargePage(),
        ),
    '/gacha': (context) => _deferred(
          gacha.loadLibrary,
          () => gacha.GachaPage(),
          message: '正在加载扭蛋…',
        ),
    '/user-profile': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Map<String, dynamic>) {
        return const Scaffold(
          body: Center(child: Text('页面参数丢失，请返回首页重新进入')),
        );
      }
      return UserProfilePage(
        userId: args['userId'] as String,
        userName: args['userName'] as String?,
        userAvatar: args['userAvatar'] as String?,
        heroTag: args['heroTag'] as String?,
      );
    },
    '/cloud-gallery': (context) => _deferred(
          cloud_gallery.loadLibrary,
          () => cloud_gallery.CloudGalleryPage(),
        ),
    '/topic-posts': (context) {
      final tag = ModalRoute.of(context)!.settings.arguments as TopicTag;
      return TopicPostsPage(topicTag: tag);
    },
    '/friends': (context) => const FriendsPage(),
    '/community': (context) => const CommunityHomePage(),
    '/community/group': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Map) {
        return const Scaffold(
          body: Center(child: Text('缺少群组参数')),
        );
      }
      final groupId = args['groupId'] as String?;
      if (groupId == null || groupId.isEmpty) {
        return const Scaffold(
          body: Center(child: Text('无效的群组 ID')),
        );
      }
      final initial = args['group'] is CommunityGroup
          ? args['group'] as CommunityGroup
          : null;
      return InterestGroupDetailPage(
        groupId: groupId,
        initialGroup: initial,
      );
    },
    '/post-detail': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Map) {
        return const Scaffold(body: Center(child: Text('缺少动态参数')));
      }
      final postId = args['postId'] as String?;
      if (postId == null || postId.isEmpty) {
        return const Scaffold(body: Center(child: Text('无效的动态 ID')));
      }
      final initial = args['post'] is Post ? args['post'] as Post : null;
      return CommunityPostDetailPage(postId: postId, initialPost: initial);
    },
    '/match': (context) => const ExploreMatchRedirectPage(),
    '/messages': (context) => const ConversationsPage(),
    '/direct-chat': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Map<String, dynamic>) {
        return const Scaffold(body: Center(child: Text('页面参数丢失，请返回重试')));
      }
      return DirectChatPage(
        userId: args['userId'] as String,
        username: args['username'] as String,
        avatar: args['avatar'] as String,
      );
    },
    '/scan': (context) => _deferred(
          scan.loadLibrary,
          () => scan.ScanPage(),
          message: '正在加载扫码模块…',
        ),
    '/user-qr-code': (context) => const UserQrCodePage(),
    '/interaction': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      var hub = 1;
      if (args is Map && args['tab'] is int) {
        final t = (args['tab'] as int).clamp(0, 1);
        hub = t == 0 ? 1 : 2;
      }
      return FriendsPage(initialHubTabIndex: hub);
    },
  };
}
