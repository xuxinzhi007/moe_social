/// 每日经验领取结果（发帖/浏览，服务端去重）。
class DailyExpClaimResult {
  final bool granted;
  final int expGained;
  final bool levelUp;
  final int newLevel;

  const DailyExpClaimResult({
    this.granted = false,
    this.expGained = 0,
    this.levelUp = false,
    this.newLevel = 0,
  });

  factory DailyExpClaimResult.fromJson(Map<String, dynamic> json) {
    return DailyExpClaimResult(
      granted: json['granted'] == true,
      expGained: (json['exp_gained'] as num?)?.toInt() ?? 0,
      levelUp: json['level_up'] == true,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 0,
    );
  }
}
