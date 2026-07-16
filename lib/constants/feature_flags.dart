/// 产品能力开关（与 [docs/product/product-positioning.md] 对齐）。
class FeatureFlags {
  const FeatureFlags._();

  // ── 产品定性（2026-06）：社交为主 ─────────────────────────────────────

  /// 小游戏、游戏大厅、扫雷等玩法入口。
  static const bool showGameFeatures = false;

  /// 抽卡 / gacha 演示页。
  static const bool showGachaFeatures = false;

  // ── 实验 / 开发者向 ───────────────────────────────────────────────────

  static const bool showExperimentalFeatures = false;

  /// AutoGLM 自动化（自用）；入口在「设置 → 高级选项」。
  static const bool showAutoGlm = showExperimentalFeatures;

  static const bool showLocalModelSettings = showExperimentalFeatures;

  /// AI 伙伴 — 用户的陪伴角色与持续状态（增强型功能 P1）
  static const bool showLifeEngine = true;
}
