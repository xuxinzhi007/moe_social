import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/feature_flags.dart';
import '../../providers/chat_theme_provider.dart';
import '../../theme/chat_skin.dart';
import '../../theme/moe_tokens.dart';

/// 聊天主题皮肤选择页（[FeatureFlags.chatThemeSkins]）。
///
/// 横向滑动卡片浏览 5 套预设皮肤；顶部实时预览当前选中皮肤的
/// 背景色与气泡效果；点击卡片即刻切换并持久化。
class ChatSkinPickerPage extends StatelessWidget {
  const ChatSkinPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // watch：切换皮肤后页面即时重建（预览区 / 选中态同步刷新）。
    final theme = context.watch<ChatThemeProvider>();
    final skin = theme.currentSkin;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: skin.backgroundFor(brightness),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _textColorFor(skin.chatBackground),
        title: const Text(
          '聊天主题',
          style: TextStyle(
            fontSize: MoeTokens.textLg,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 实时预览：当前皮肤下的对话气泡小样 ────────────────
            _SkinPreview(skin: skin, brightness: brightness),
            const SizedBox(height: MoeTokens.spaceXl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceLg,
              ),
              child: Text(
                '选择一款主题，让聊天更合心意',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  color: _textColorFor(
                    skin.chatBackground,
                  ).withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            // ── 横向滚动皮肤卡片 ─────────────────────────────────
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: MoeTokens.spaceLg,
                  vertical: MoeTokens.spaceLg,
                ),
                itemCount: ChatSkins.all.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: MoeTokens.spaceMd),
                itemBuilder: (context, index) {
                  final item = ChatSkins.all[index];
                  final selected = item.id == skin.id;
                  return _SkinCard(
                    skin: item,
                    selected: selected,
                    onTap: () => theme.setSkin(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 按背景亮度取适配文字色（暗夜等深色皮肤卡片上自动反转）。
  static Color _textColorFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : MoeTokens.titleText;
  }
}

/// 顶部实时预览：模拟两条对话气泡（对方 / 我方）。
class _SkinPreview extends StatelessWidget {
  const _SkinPreview({required this.skin, required this.brightness});

  final ChatSkin skin;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final bg = skin.backgroundFor(brightness);
    final peerColor = skin.peerColorFor(brightness);
    final peerBorder = skin.peerBorderFor(brightness);
    final textOnBg = ChatSkinPickerPage._textColorFor(skin.chatBackground);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: peerBorder),
        boxShadow: MoeTokens.shadowCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 对方气泡
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: peerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: peerBorder),
              ),
              child: Text(
                '今天的晚霞好漂亮～',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  color: ChatSkinPickerPage._textColorFor(peerColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          // 我方气泡（当前皮肤渐变）
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                gradient: skin.bubbleMeGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: skin.bubbleMeGradient.colors.first
                        .withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '走，一起去看！',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // 底部提示：预览即所得
          Padding(
            padding: const EdgeInsets.only(top: MoeTokens.spaceLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: textOnBg.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                Text(
                  '实时预览',
                  style: TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: textOnBg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张皮肤卡片：渐变预览块 + 名称 + 背景色圆点；
/// 选中态为 gradientPrimary 描边环 + 右上角 ✓ 徽标。
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final ChatSkin skin;
  final bool selected;
  final VoidCallback onTap;

  static const double _cardWidth = 150;
  static const double _ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg - _ringWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _cardWidth,
          padding: const EdgeInsets.all(MoeTokens.spaceMd),
          decoration: BoxDecoration(
            color: MoeTokens.surface1,
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg - _ringWidth),
            boxShadow: selected ? [] : MoeTokens.shadowCard(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部：我方气泡渐变预览块
              ClipRRect(
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(gradient: skin.bubbleMeGradient),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Container(
                    width: 44,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: skin.bubbleMeGradient,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Hi',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.0,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              // 中部：皮肤名称
              Text(
                skin.name,
                style: TextStyle(
                  fontSize: MoeTokens.textMd,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: MoeTokens.titleText,
                ),
              ),
              const SizedBox(height: 6),
              // 底部：背景色圆点 + 深色标记
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: skin.chatBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MoeTokens.surfaceBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      skin.isDarkSkin ? '深色皮肤' : '背景色',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: MoeTokens.textXs,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // 选中态外层：gradientPrimary 描边环 + ✓ 徽标。
    final inner = selected
        ? Container(
            padding: const EdgeInsets.all(_ringWidth),
            decoration: BoxDecoration(
              gradient: MoeTokens.gradientPrimary,
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: card,
          )
        : card;

    return AnimatedScale(
      scale: selected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          inner,
          if (selected)
            Positioned(
              top: -7,
              right: -7,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: MoeTokens.gradientPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: MoeTokens.surface1, width: 2),
                  boxShadow: MoeTokens.shadowSm(),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
