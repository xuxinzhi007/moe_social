import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'avatar_image.dart';

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
    final visibleUsers = _followings.take(8).toList();

    if (!_isLoading && visibleUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: _buildCreateOnlyCard(context, scheme),
      );
    }

    final itemCount = _isLoading ? 5 : visibleUsers.length;

    return Container(
      height: 94,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildCreateItem(context, scheme, compact: true);
          if (_isLoading) return _buildSkeletonItem(scheme);
          return _buildUserItem(context, visibleUsers[index - 1], scheme);
        },
      ),
    );
  }

  Widget _buildCreateOnlyCard(BuildContext context, ColorScheme scheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/create-post');
          if (result != null) {
            await widget.onCreatePostSuccess?.call(result);
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '发一条新动态',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '把这一刻记录下来，首页就会开始真正活起来',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: scheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateItem(BuildContext context, ColorScheme scheme, {bool compact = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/create-post');
            if (result != null) {
              await widget.onCreatePostSuccess?.call(result);
            }
          },
          child: SizedBox(
            width: compact ? 68 : 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 48 : 54,
                  height: compact ? 48 : 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7F7FD5).withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '发动态',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surface,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: NetworkAvatarImage(
                      imageUrl: user.avatar,
                      radius: 20,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 10,
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
      padding: const EdgeInsets.only(right: 14),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 9,
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
