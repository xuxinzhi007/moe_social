import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../ai/ai_brand_tokens.dart';
import '../motion/moe_reveal.dart';
import '../../providers/ai_assistant_mock_provider.dart';

/// AI 互动卡片 — 展示在 Feed 流中，显示 AI 助手的点赞/评论等互动。
class AiActivityCard extends StatelessWidget {
  final AiActivity activity;
  final VoidCallback? onTap;

  const AiActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MoeReveal(
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: MoeTokens.spaceLg,
          vertical: MoeTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          boxShadow: MoeTokens.shadowSm(),
          // 渐变边框效果
          border: Border.all(
            color: AiBrandTokens.gradientPink.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          child: InkWell(
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            onTap: onTap,
            child: Stack(
              children: [
                // 左侧渐变装饰条
                Positioned(
                  left: 0,
                  top: MoeTokens.spaceSm,
                  bottom: MoeTokens.spaceSm,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AiBrandTokens.gradientPink,
                          AiBrandTokens.gradientCoral,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 主内容
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MoeTokens.spaceLg + MoeTokens.spaceSm, // 16 + 8 = 24
                    MoeTokens.spaceMd,
                    MoeTokens.spaceLg,
                    MoeTokens.spaceMd,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI 头像
                      _buildAiAvatar(),
                      const SizedBox(width: MoeTokens.spaceMd),
                      // 中间区域
                      Expanded(child: _buildContent()),
                      const SizedBox(width: MoeTokens.spaceSm),
                      // AI 标签
                      _buildAiBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// AI 头像 — 圆形渐变背景 + emoji
  Widget _buildAiAvatar() {
    final size = MoeTokens.space4xl; // 40px
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            AiBrandTokens.gradientPink,
            AiBrandTokens.gradientCoral,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.gradientPink.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        AiAssistantMockProvider.assistantAvatar,
        style: const TextStyle(fontSize: MoeTokens.textLg),
      ),
    );
  }

  /// 中间文本区域
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // summary（主文本）
        Text(
          activity.summary,
          style: const TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: MoeTokens.fontWeightSubtitle,
            color: MoeTokens.titleText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MoeTokens.spaceXs),
        // targetTitle（副文本，灰色）
        Text(
          activity.targetTitle,
          style: TextStyle(
            fontSize: MoeTokens.textSm,
            fontWeight: MoeTokens.fontWeightCaption,
            color: MoeTokens.hintText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // commentText（引号样式，仅 comment 类型显示）
        if (activity.commentText != null) ...[
          const SizedBox(height: MoeTokens.spaceSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: MoeTokens.spaceMd,
              vertical: MoeTokens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AiBrandTokens.identityGradient.colors.first
                  .withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
              border: Border(
                left: BorderSide(
                  color: AiBrandTokens.gradientPink.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 14,
                  color: AiBrandTokens.gradientPink.withValues(alpha: 0.5),
                ),
                const SizedBox(width: MoeTokens.spaceXs),
                Expanded(
                  child: Text(
                    activity.commentText!,
                    style: TextStyle(
                      fontSize: MoeTokens.textSm,
                      fontWeight: MoeTokens.fontWeightBody,
                      color: MoeTokens.bodyText.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MoeTokens.spaceXs),
        // 时间戳
        Text(
          _formatRelativeTime(activity.timestamp),
          style: TextStyle(
            fontSize: MoeTokens.textXs,
            color: MoeTokens.hintText.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 右上角 AI 标签
  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceSm,
        vertical: MoeTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AiBrandTokens.gradientPink,
            AiBrandTokens.gradientCoral,
          ],
        ),
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          fontSize: MoeTokens.textXs,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
