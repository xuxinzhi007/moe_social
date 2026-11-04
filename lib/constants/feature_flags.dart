/// 产品能力开关（与 [docs/product/product-positioning.md] 对齐）。
class FeatureFlags {
  const FeatureFlags._();

  // ── 产品定性（2026-06）：社交为主 ─────────────────────────────────────

  /// 星辉远征主游戏（横屏卡牌 PvE）。
  /// 2026-11-04：社交主壳收口，Arena 降权为实验（默认不可见）；
  /// 与定位「不以游戏做卖点」对齐。详见 docs/product/convergence-social-shell-2026-11-04.md
  static const bool arenaGamePrototype = false;

  // ── 实验 / 开发者向 ───────────────────────────────────────────────────

  /// 内测/侧载总开关。打开后 replyAssist / AutoGLM / liveGiftPk / GameLab 跟随露出。
  /// 商店包发布前须改回 false，避免实验入口泄漏。
  static const bool showExperimentalFeatures = true;

  /// Android 异地联机网络实验。跟随实验总开关。
  static const bool showGameNetworkLab = showExperimentalFeatures;

  /// 读屏回复参谋（路径 B：侧载/内测）。跟随实验总开关。
  static const bool replyAssistPrototype = showExperimentalFeatures;

  /// AutoGLM 自动化（自用）；入口在「设置 → 高级选项」。跟随实验总开关。
  static const bool showAutoGlm = showExperimentalFeatures;

  // ── AI 陪伴产品约束（见 docs/dev/ai-companion-formal-decisions.md）────

  /// AIRI 向轻量语音存在感：Companion 聊天语音输入 + 朗读回复。
  /// 不做 Live2D / 形象驱动（决策 13）；仅本机 STT/TTS。
  static const bool companionVoicePresence = true;

  /// 礼物全屏动效走 Lottie 模板 + 左侧跑道；失败 / 无障碍降级粒子。
  /// 见 `docs/dev/lottie-achievement-gift-design.md`。
  static const bool useLottieGiftEffects = true;

  /// 双人直播礼物 PK V1。跟随实验总开关。
  static const bool liveGiftPk = showExperimentalFeatures;

  // ── 聊天 UI 个性化升级 ─────────────────────────────────────

  /// 全站导航毛玻璃（AppBar + 底部 Tab 使用 BackdropFilter 磨砂）。
  static const bool glassNavigation = true;

  /// 窗口级连续渐变气泡（按位置偏移渐变色）。
  static const bool chatGradientBubbles = true;

  /// 聊天品牌动效（发送成功✓ / 新消息弹跳 / 表情反应）。
  static const bool chatBrandMotion = true;

  /// 语音消息（录音 + 波形可视化 + 播放）。
  /// 后端 media 上传已支持音频 Content-Type，正式开启。
  static const bool chatVoiceMessage = true;

  /// 聊天主题皮肤（用户可选背景 / 气泡配色方案）。
  static const bool chatThemeSkins = true;
}
