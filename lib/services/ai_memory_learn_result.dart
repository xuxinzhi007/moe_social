/// 单回合记忆学习（提取写入）结果。
class AiMemoryLearnResult {
  final int savedCount;
  final String? errorMessage;

  const AiMemoryLearnResult({
    this.savedCount = 0,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

/// 供设置页展示的上回合记忆统计。
class AiMemoryTurnStats {
  final int lastInjectedCount;
  final int lastSavedCount;
  final String? lastLearnError;
  final DateTime? updatedAt;

  const AiMemoryTurnStats({
    this.lastInjectedCount = 0,
    this.lastSavedCount = 0,
    this.lastLearnError,
    this.updatedAt,
  });

  bool get hasLearnError =>
      lastLearnError != null && lastLearnError!.trim().isNotEmpty;
}
