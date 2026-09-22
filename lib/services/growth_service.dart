import '../models/achievement_unlock.dart';
import '../models/checkin_record.dart';
import '../models/checkin_status.dart';
import '../models/daily_exp_claim_result.dart';
import '../models/exp_log.dart';
import '../models/user_level.dart';
import 'api_service.dart';

class GrowthService {
  GrowthService._();

  static Future<CheckInStatus> getCheckInStatus(String userId) =>
      ApiService.getCheckInStatus(userId);

  static Future<CheckInResult> checkInWithUnlocks(String userId) =>
      ApiService.checkInWithUnlocks(userId);

  static Future<({List<CheckInRecord> records, int total})> getCheckInHistory(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await ApiService.getCheckInHistory(
      userId,
      page: page,
      pageSize: pageSize,
    );
    return (
      records: result['records'] as List<CheckInRecord>,
      total: result['total'] as int,
    );
  }

  static Future<({List<ExpLogRecord> logs, int total})> getExpLogs(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await ApiService.getExpLogs(
      userId,
      page: page,
      pageSize: pageSize,
    );
    return (
      logs: result['logs'] as List<ExpLogRecord>,
      total: result['total'] as int,
    );
  }

  static Future<UserLevelInfo> getUserLevel(String userId) =>
      ApiService.getUserLevel(userId);

  static Future<DailyExpClaimResult> claimDailyBrowseExp(String userId) =>
      ApiService.claimDailyBrowseExp(userId);
}
