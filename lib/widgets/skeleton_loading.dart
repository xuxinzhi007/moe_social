import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/moe_tokens.dart';

/// 统一的骨架屏基础 building blocks。
abstract final class _SkeletonBase {
  static const Color _baseColor = Color(0xFFE0E0E0);
  static const Color _highlightColor = Color(0xFFF5F5F5);

  static Shimmer shimmer({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: child,
    );
  }

  static Widget circle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget rect({
    required double height,
    double? width,
    double radius = MoeTokens.radiusSm,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static Widget line({double? width}) {
    return Container(
      width: width ?? double.infinity,
      height: MoeTokens.textBase,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
      ),
    );
  }
}

// ─── PostSkeleton ─────────────────────────────────────────────────────────────

/// 帖子列表骨架屏。
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.spaceLg),
        child: _SkeletonBase.shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户信息骨架
              Row(
                children: [
                  _SkeletonBase.circle(size: 48),
                  SizedBox(width: MoeTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBase.line(width: 120),
                        SizedBox(height: MoeTokens.spaceSm),
                        _SkeletonBase.line(width: 80),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: MoeTokens.spaceLg),

              // 帖子内容骨架 (三行)
              _SkeletonBase.line(),
              SizedBox(height: MoeTokens.spaceSm),
              _SkeletonBase.line(),
              SizedBox(height: MoeTokens.spaceSm),
              _SkeletonBase.line(width: 200),
              SizedBox(height: MoeTokens.spaceLg),

              // 图片骨架
              _SkeletonBase.rect(height: 200, radius: MoeTokens.radiusMd),
              SizedBox(height: MoeTokens.spaceLg),

              // 底部按钮骨架
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SkeletonBase.rect(width: 60, height: 24),
                  _SkeletonBase.rect(width: 60, height: 24),
                  _SkeletonBase.rect(width: 60, height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── UserListSkeleton ─────────────────────────────────────────────────────────

/// 用户列表骨架屏 — 头像 + 昵称 + 签名。
class UserListSkeleton extends StatelessWidget {
  const UserListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => _buildItem(),
    );
  }

  Widget _buildItem() {
    return Container(
      margin: EdgeInsets.only(bottom: MoeTokens.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: _SkeletonBase.shimmer(
        child: Row(
          children: [
            _SkeletonBase.circle(size: 48),
            SizedBox(width: MoeTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBase.line(width: 100),
                  SizedBox(height: MoeTokens.spaceSm),
                  _SkeletonBase.line(width: 160),
                ],
              ),
            ),
            _SkeletonBase.rect(
              width: 64,
              height: 32,
              radius: MoeTokens.radiusButton,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MessageSkeleton ──────────────────────────────────────────────────────────

/// 消息列表骨架屏 — 头像/图标 + 标题 + 内容 + 时间。
class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => _buildItem(),
    );
  }

  Widget _buildItem() {
    return Container(
      margin: EdgeInsets.only(bottom: MoeTokens.spaceMd),
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: _SkeletonBase.shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBase.circle(size: 44),
            SizedBox(width: MoeTokens.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SkeletonBase.line(width: 120),
                      _SkeletonBase.line(width: 50),
                    ],
                  ),
                  SizedBox(height: MoeTokens.spaceSm),
                  _SkeletonBase.line(),
                  SizedBox(height: MoeTokens.spaceXs),
                  _SkeletonBase.line(width: 180),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
