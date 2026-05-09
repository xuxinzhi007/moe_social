import 'dart:async';
import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'avatar_image.dart';

/// 首页关注好友横向活跃条
/// 展示当前用户关注的人，提供快速跳转入口
class HomeStoriesBar extends StatefulWidget {
  final Future<void> Function(dynamic result)? onCreatePostSuccess;

  const HomeStoriesBar({
    super.key,
    this.onCreatePostSuccess,
  });

  @override
  State<HomeStoriesBar> createState() => _HomeStoriesBarState();
}

class _HomeStoriesBarState extends State<HomeStoriesBar> {
  List<User> _followings = [];
  bool _isLoading = true;

  static const _ringGradients = [
    [Color(0xFF7F7FD5), Color(0xFFf093fb)],
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
      final result = await ApiService.getFollowings(
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
    final itemCount = _isLoading ? 5 : _followings.length;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildCreateItem(context, scheme);
          if (_isLoading) return _buildSkeletonItem(scheme);
          return _buildUserItem(context, _followings[index - 1], scheme);
        },
      ),
    );
  }

  Widget _buildCreateItem(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/create-post');
            if (result != null) {
              await widget.onCreatePostSuccess?.call(result);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7F7FD5).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '发动态',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserItem(
      BuildContext context, User user, ColorScheme scheme) {
    final gradientIdx = user.id.hashCode.abs() % _ringGradients.length;
    final gradient = _ringGradients[gradientIdx];

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.pushNamed(
            context,
            '/user-profile',
            arguments: {
              'userId': user.id,
              'userName': user.username,
              'userAvatar': user.avatar,
            },
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatarImage(
                    imageUrl: user.avatar,
                    radius: 22,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 54,
                child: Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 38,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
