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
}
