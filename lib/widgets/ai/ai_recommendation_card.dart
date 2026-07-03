import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../ai/ai_brand_tokens.dart';
import '../fade_in_up.dart';
import '../../providers/ai_assistant_mock_provider.dart';

/// AI 推荐卡片 — 横向滚动列表中单个推荐项。
class AiRecommendationCard extends StatelessWidget {
  final AiRecommendation recommendation;
  final VoidCallback? onTap;

  const AiRecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          margin: const EdgeInsets.only(right: MoeTokens.spaceMd),
          decoration: BoxDecoration(
            color: MoeTokens.cardBackground,
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            boxShadow: MoeTokens.shadowSm(),
            border: Border.all(
              color: AiBrandTokens.gradientCoral.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部渐变装饰条
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AiBrandTokens.gradientPink,
                        AiBrandTokens.gradientCoral,
                      ],
                    ),
                  ),
                ),
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(MoeTokens.spaceMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧图标
                      _buildTypeIcon(),
                      const SizedBox(width: MoeTokens.spaceSm),
                      // 标题 + 副标题
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              recommendation.title,
                              style: const TextStyle(
                                fontSize: MoeTokens.textBase,
                                fontWeight: MoeTokens.fontWeightSubtitle,
                                color: MoeTokens.titleText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: MoeTokens.spaceXs),
                            Text(
                              recommendation.subtitle,
                              style: TextStyle(
                                fontSize: MoeTokens.textSm,
                                fontWeight: MoeTokens.fontWeightCaption,
                                color: MoeTokens.hintText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部 AI 推荐标签
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MoeTokens.spaceMd,
                    0,
                    MoeTokens.spaceMd,
                    MoeTokens.spaceMd,
                  ),
                  child: _buildAiRecommendBadge(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 根据推荐类型显示不同图标
  Widget _buildTypeIcon() {
    final IconData icon;
    final Color color;

    switch (recommendation.type) {
      case 'user':
        icon = Icons.person_outline_rounded;
        color = AiBrandTokens.gradientPink;
      case 'topic':
        icon = Icons.tag_rounded;
        color = AiBrandTokens.gradientCoral;
      case 'content':
      default:
        icon = Icons.auto_awesome_rounded;
        color = MoeTokens.primary;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }

  /// "AI 推荐" 标签
  Widget _buildAiRecommendBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AiBrandTokens.gradientPink.withValues(alpha: 0.1),
            AiBrandTokens.gradientCoral.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
        border: Border.all(
          color: AiBrandTokens.gradientPink.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 11,
            color: AiBrandTokens.gradientPink,
          ),
          const SizedBox(width: 3),
          Text(
            'AI 推荐',
            style: TextStyle(
              fontSize: MoeTokens.textXs,
              fontWeight: FontWeight.w600,
              color: AiBrandTokens.gradientPink,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 推荐横向滚动列表 — 可嵌入 Feed 中。
class AiRecommendationList extends StatelessWidget {
  final List<AiRecommendation> recommendations;
  final ValueChanged<AiRecommendation>? onTap;

  const AiRecommendationList({
    super.key,
    required this.recommendations,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
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
                  const SizedBox(width: MoeTokens.spaceSm),
                  const Text(
                    '为你推荐',
                    style: TextStyle(
                      fontSize: MoeTokens.textMd,
                      fontWeight: MoeTokens.fontWeightSubtitle,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            // 横向滚动
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: MoeTokens.spaceLg,
                ),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  return AiRecommendationCard(
                    recommendation: recommendations[index],
                    onTap: () => onTap?.call(recommendations[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
