import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_assistant_mock_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_activity_card.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_recommendation_card.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_input_field.dart';

/// AI 助手独立入口页 — 对话式 UI 风格。
///
/// 页面结构：
/// 1. 助手形象区域（渐变头像 + 功能标签）
/// 2. 最近互动列表（AiActivityCard）
/// 3. 为你推荐横向滚动（AiRecommendationList）
/// 4. 底部对话入口（MoeInputField + 发送按钮）
class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key});

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _onSendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    // 纯 mock：清空输入，显示 SnackBar 反馈
    _chatController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('小萌收到了你的消息："$text"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: _buildAppBar(context),
      body: Consumer<AiAssistantMockProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: MoeTokens.spaceLg),
                      _buildHeroSection(context),
                      const SizedBox(height: MoeTokens.space2xl),
                      _buildRecentInteractions(context, provider),
                      const SizedBox(height: MoeTokens.space2xl),
                      _buildRecommendations(context, provider),
                      const SizedBox(height: MoeTokens.space4xl),
                    ],
                  ),
                ),
              ),
              _buildChatEntry(context),
            ],
          );
        },
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI 小头像
          Container(
            width: 30,
            height: 30,
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
                  color: AiBrandTokens.gradientPink.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              AiAssistantMockProvider.assistantAvatar,
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          const Text(
            'AI 助手',
            style: TextStyle(
              fontSize: MoeTokens.textLg,
              fontWeight: MoeTokens.fontWeightTitle,
              color: MoeTokens.titleText,
            ),
          ),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: MoeTokens.pageBackground,
      foregroundColor: MoeTokens.titleText,
    );
  }

  // ─── 助手形象区域 ────────────────────────────────────────────────────────────

  Widget _buildHeroSection(BuildContext context) {
    return MoeReveal(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.space2xl,
            vertical: MoeTokens.space3xl,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AiBrandTokens.gradientPink,
                AiBrandTokens.gradientCoral,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            boxShadow: [
              BoxShadow(
                color: AiBrandTokens.gradientPink.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 大头像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  AiAssistantMockProvider.assistantAvatar,
                  style: TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: MoeTokens.spaceLg),
              // 名称与介绍
              const Text(
                '我是${AiAssistantMockProvider.assistantName}，你的 AI 助手',
                style: TextStyle(
                  fontSize: MoeTokens.textXl,
                  fontWeight: MoeTokens.fontWeightTitle,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              Text(
                '随时为你提供帮助与陪伴',
                style: TextStyle(
                  fontSize: MoeTokens.textBase,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: MoeTokens.spaceXl),
              // 功能标签行
              Wrap(
                spacing: MoeTokens.spaceSm,
                runSpacing: MoeTokens.spaceSm,
                alignment: WrapAlignment.center,
                children: const [
                  _FeatureChip(
                      icon: Icons.notifications_active_rounded, label: '互动提醒'),
                  _FeatureChip(icon: Icons.auto_awesome_rounded, label: '智能推荐'),
                  _FeatureChip(icon: Icons.chat_bubble_rounded, label: '聊天陪伴'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 最近互动 ─────────────────────────────────────────────────────────────

  Widget _buildRecentInteractions(
    BuildContext context,
    AiAssistantMockProvider provider,
  ) {
    final activities = provider.activities.take(5).toList();

    return MoeReveal(
      delay: MoeTokens.motionStaggerStep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
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
                  '最近互动',
                  style: TextStyle(
                    fontSize: MoeTokens.textMd,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                    color: MoeTokens.titleText,
                  ),
                ),
                const Spacer(),
                if (provider.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MoeTokens.spaceSm,
                      vertical: MoeTokens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: AiBrandTokens.gradientCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: Text(
                      '${provider.unreadCount} 条未读',
                      style: TextStyle(
                        fontSize: MoeTokens.textXs,
                        fontWeight: FontWeight.w600,
                        color: AiBrandTokens.gradientCoral,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
              child: MoeEmptyState(
                title: '暂时没有互动记录',
                subtitle: '小萌正在关注你的动态，有新互动会第一时间通知你~',
                icon: Icons.notifications_none_rounded,
                compact: true,
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              return MoeStaggerReveal(
                index: index + 2,
                maxAnimated: 10,
                child: AiActivityCard(
                  activity: activity,
                  onTap: () {
                    provider.markAsRead(activity.id);
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── 为你推荐 ─────────────────────────────────────────────────────────────

  Widget _buildRecommendations(
    BuildContext context,
    AiAssistantMockProvider provider,
  ) {
    if (provider.recommendations.isEmpty) return const SizedBox.shrink();

    return AiRecommendationList(
      recommendations: provider.recommendations,
      onTap: (rec) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开了推荐：${rec.title}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  // ─── 底部对话入口 ──────────────────────────────────────────────────────────

  Widget _buildChatEntry(BuildContext context) {
    return MoeReveal(
      delay: const Duration(milliseconds: 240),
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          border: Border(
            top: BorderSide(
              color: AiBrandTokens.gradientPink.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AiBrandTokens.gradientPink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceLg,
              MoeTokens.spaceMd,
              MoeTokens.spaceLg,
              MoeTokens.spaceMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // "和小萌聊聊" 标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoeTokens.spaceSm,
                    vertical: MoeTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AiBrandTokens.gradientPink.withValues(alpha: 0.1),
                        AiBrandTokens.gradientCoral.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: AiBrandTokens.gradientPink,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '和小萌聊聊',
                        style: TextStyle(
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w600,
                          color: AiBrandTokens.gradientPink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MoeTokens.spaceSm),
                // 输入框
                Expanded(
                  child: MoeInputField(
                    controller: _chatController,
                    hintText: '说点什么...',
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _onSendMessage(),
                    fillColor: MoeTokens.pageBackground,
                  ),
                ),
                const SizedBox(width: MoeTokens.spaceSm),
                // 发送按钮
                GestureDetector(
                  onTap: _onSendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AiBrandTokens.gradientPink,
                          AiBrandTokens.gradientCoral,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AiBrandTokens.gradientPink.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 功能标签 Chip ──────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceMd,
        vertical: MoeTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: MoeTokens.spaceXs),
          Text(
            label,
            style: const TextStyle(
              fontSize: MoeTokens.textSm,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
