import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../providers/checkin_provider.dart';
import '../providers/user_level_provider.dart';
import '../services/api_service.dart';
import '../widgets/moe_toast.dart';

/// 登录后自动签到、每日浏览经验等成长侧效应（幂等由服务端 exp_log 保证）。
class DailyGrowthService {
  DailyGrowthService._();

  static final DailyGrowthService instance = DailyGrowthService._();

  bool _autoCheckInStarted = false;
  bool _browseExpPending = false;

  /// App 启动且已登录时静默签到（今日已签则服务端直接拒绝，不打扰用户）。
  Future<void> runAutoCheckIn(BuildContext context) async {
    if (_autoCheckInStarted) return;
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) return;
    _autoCheckInStarted = true;

    try {
      final checkIn = context.read<CheckInProvider>();
      await checkIn.loadCheckInStatus(userId);
      if (!checkIn.canCheckIn) return;

      final ok = await checkIn.performCheckIn(userId);
      if (!ok || !context.mounted) return;

      final msg = checkIn.successMessage;
      if (msg != null && msg.isNotEmpty) {
        MoeToast.success(context, msg);
      }
      if (context.mounted) {
        unawaited(context.read<UserLevelProvider>().loadUserLevel(userId));
      }
    } catch (e) {
      debugPrint('DailyGrowthService auto check-in skipped: $e');
    }
  }

  /// 打开动态详情时领取「每日首次浏览」经验（每天最多一次）。
  Future<void> claimDailyBrowseExp(BuildContext context) async {
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty || _browseExpPending) return;
    _browseExpPending = true;
    try {
      final result = await ApiService.claimDailyBrowseExp(userId);
      if (!context.mounted || !result.granted || result.expGained <= 0) return;
      MoeToast.info(context, '今日浏览奖励 +${result.expGained} 经验');
      unawaited(context.read<UserLevelProvider>().loadUserLevel(userId));
    } catch (e) {
      debugPrint('DailyGrowthService browse exp skipped: $e');
    } finally {
      _browseExpPending = false;
    }
  }

  void resetSession() {
    _autoCheckInStarted = false;
    _browseExpPending = false;
  }
}
