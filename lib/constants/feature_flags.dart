/// 产品能力开关（与 [docs/product/product-positioning.md] 对齐）。
class FeatureFlags {
  const FeatureFlags._();

  // ── 产品定性（2026-06）：社交为主 ─────────────────────────────────────

  /// 小游戏、互动故事（GamePlay）等玩法入口。默认关闭。
  static const bool showGameFeatures = false;

  /// 星辉远征主游戏（横屏卡牌 PvE）。为 true 时 Companion「小家」进入 Arena；
  /// 旧 Pet 竖屏主路径视为弃用入口（代码可留作回滚）。
  static const bool arenaGamePrototype = true;

  /// 抽卡 / gacha 演示页。
  static const bool showGachaFeatures = false;

  // ── 实验 / 开发者向 ───────────────────────────────────────────────────

  static const bool showExperimentalFeatures = false;

  /// AutoGLM 自动化（自用）；入口在「设置 → 高级选项」。
  static const bool showAutoGlm = showExperimentalFeatures;

  static const bool showLocalModelSettings = showExperimentalFeatures;

  /// AI 伙伴 — 数字生命个人小世界（「TA 的世界」多居民地图）。
  /// 养成主路径为 [arenaGamePrototype] 星辉；本开关只控制世界入口，不隐藏 Companion 聊天。
  static const bool showLifeEngine = false;

  /// Flame 小世界实验渲染（「TA 的世界」全屏 GameWidget）。
  /// true = 走 Flame；false = 回退 CustomPaint [LifeWorldMap]。
  /// 见 `.cursor/skills/flame-life-world/SKILL.md`。
  static const bool useFlameLifeWorld = true;

  // ── AI 陪伴产品约束（见 docs/dev/ai-companion-formal-decisions.md）────

  /// 一期：每用户一个「当前活跃」伙伴（后端 profile 按 user 取）。
  /// 二期多角色未定形态前，禁止据此做「永远只能一个」的 UI/死逻辑扩展；
  /// 多角色应在 Companion 域演进，不要复活酒馆大厅。
  static const bool companionSingleActiveBondPhase1 = true;

  /// AIRI 向轻量语音存在感：Companion 聊天语音输入 + 朗读回复。
  /// 不做 Live2D / 形象驱动（决策 13）；仅本机 STT/TTS。
  static const bool companionVoicePresence = true;

  /// 礼物全屏动效走 Lottie 模板 + 左侧跑道；失败 / 无障碍降级粒子。
  /// 见 `docs/dev/lottie-achievement-gift-design.md`。
  static const bool useLottieGiftEffects = true;

  /// 双人直播礼物 PK V1。开发期已开启；关闭后路由不可进入。
  static const bool liveGiftPk = true;

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
