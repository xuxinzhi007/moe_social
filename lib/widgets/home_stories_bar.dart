import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import 'avatar_image.dart';

class HomeStoriesBar extends StatefulWidget {
  const HomeStoriesBar({super.key});

  @override
  State<HomeStoriesBar> createState() => _HomeStoriesBarState();
}

class _HomeStoriesBarState extends State<HomeStoriesBar> {
  List<User> _followings = [];
  bool _isLoading = true;

  static const _ringGradients = [
    [Color(0xFF7F7FD5), Color(0xFFF093FB)],
    [Color(0xFFFF6B6B), Color(0xFFFFB347)],
    [Color(0xFF4ECDC4), Color(0xFF44A08D)],
    [Color(0xFF86A8E7), Color(0xFF7F7FD5)],
    [Color(0xFFFFCA28), Color(0xFFFF8F00)],
    [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFollowings());
  }

  Future<void> _loadFollowings() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final result = await UserService.getFollowings(
        userId,
        page: 1,
        pageSize: 12,
      );
      final users = result['followings'] as List<User>;
      if (mounted) {
        setState(() {
          _followings = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleUsers = _followings.take(6).toList();
    // 始终细条：左侧「发动态」为唯一创作入口（对标 IG Stories），不做大海报 CTA。
    final itemCount = _isLoading ? 5 : visibleUsers.length;
    if (!_isLoading && itemCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (_isLoading) return _buildSkeletonItem(scheme);
          return _buildUserItem(context, visibleUsers[index], scheme);
        },
      ),
    );
  }

  Widget _buildUserItem(BuildContext context, User user, ColorScheme scheme) {
    final gradientIdx = user.id.hashCode.abs() % _ringGradients.length;
    final gradient = _ringGradients[gradientIdx];

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.pushNamed(
            context,
            '/user-profile',
            arguments: {
              'userId': user.id,
              'userName': user.username,
              'userAvatar': user.avatar,
            },
          ),
          child: SizedBox(
            width: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.surface,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: NetworkAvatarImage(
                      imageUrl: user.avatar,
                      radius: 18,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 36,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
