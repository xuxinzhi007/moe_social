import 'package:shared_preferences/shared_preferences.dart';

/// 兴趣 onboarding：按用户记录是否已完成与已选兴趣（规则版冷启动，仅存本地）。
class OnboardingPreferences {
  static const _kCompletedPrefix = 'onboarding_completed_';
  static const _kInterestsPrefix = 'onboarding_interests_';

  static Future<bool> isCompleted(String userId) async {
    if (userId.isEmpty) return true;
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_kCompletedPrefix$userId') ?? false;
  }

  static Future<void> markCompleted(
    String userId,
    List<String> interestNames,
  ) async {
    if (userId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_kCompletedPrefix$userId', true);
    await p.setStringList('$_kInterestsPrefix$userId', interestNames);
  }

  static Future<List<String>> getInterests(String userId) async {
    if (userId.isEmpty) return const [];
    final p = await SharedPreferences.getInstance();
    return p.getStringList('$_kInterestsPrefix$userId') ?? const [];
  }
}
