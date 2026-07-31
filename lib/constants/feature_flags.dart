/// 产品能力开关（与 [docs/product/product-positioning.md] 对齐）。
class FeatureFlags {
  const FeatureFlags._();

  // ── 产品定性（2026-06）：社交为主 ─────────────────────────────────────

  /// 小游戏、互动故事（GamePlay）等玩法入口。默认关闭。
  static const bool showGameFeatures = false;

  /// 抽卡 / gacha 演示页。
  static const bool showGachaFeatures = false;

  // ── 实验 / 开发者向 ───────────────────────────────────────────────────

  static const bool showExperimentalFeatures = false;

  /// AutoGLM 自动化（自用）；入口在「设置 → 高级选项」。
  static const bool showAutoGlm = showExperimentalFeatures;

  static const bool showLocalModelSettings = showExperimentalFeatures;

  /// AI 伙伴 — 数字生命个人小世界（P1）。主 Tab「AI伙伴」始终可见；
  /// 本开关只控制数字生命入口，不隐藏 Companion 聊天。
  static const bool showLifeEngine = true;

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
}
