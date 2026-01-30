import 'package:flutter/foundation.dart';
import '../models/checkin_status.dart';
import '../models/checkin_record.dart';
import '../models/checkin_data.dart';
import '../models/exp_log.dart';
import '../services/api_service.dart';

/// 签到系统状态管理Provider
/// 管理签到状态、历史记录、经验日志等功能
class CheckInProvider extends ChangeNotifier {
  // 签到状态
  CheckInStatus? _checkInStatus;
  CheckInStatus? get checkInStatus => _checkInStatus;

  // 签到历史记录
  List<CheckInRecord> _checkInHistory = [];
  List<CheckInRecord> get checkInHistory => List.unmodifiable(_checkInHistory);

  // 经验日志
  List<ExpLogRecord> _expLogs = [];
  List<ExpLogRecord> get expLogs => List.unmodifiable(_expLogs);

  // 分页信息
  int _historyPage = 1;
  int _historyTotal = 0;
  bool _hasMoreHistory = true;
  bool get hasMoreHistory => _hasMoreHistory;

  int _expLogPage = 1;
  int _expLogTotal = 0;
  bool _hasMoreExpLogs = true;
  bool get hasMoreExpLogs => _hasMoreExpLogs;

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCheckingIn = false;
  bool get isCheckingIn => _isCheckingIn;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  bool _isLoadingExpLogs = false;
  bool get isLoadingExpLogs => _isLoadingExpLogs;

  // 错误状态
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 成功消息
  String? _successMessage;
  String? get successMessage => _successMessage;

  /// 清除错误和成功消息
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// 设置错误消息
  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  /// 设置成功消息
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  /// 获取签到状态
  Future<void> loadCheckInStatus(String userId) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final status = await ApiService.getCheckInStatus(userId);
      _checkInStatus = status;

      debugPrint('✅ 签到状态加载成功: ${status.statusText}');
    } catch (e) {
      final message = e is ApiException ? e.message : '获取签到状态失败: $e';
      _setError(message);
      debugPrint('❌ 获取签到状态失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 执行签到操作
  Future<bool> performCheckIn(String userId) async {
    if (_isCheckingIn || (_checkInStatus?.hasCheckedToday == true)) return false;

    try {
      _isCheckingIn = true;
      _errorMessage = null;
      notifyListeners();

      final checkInData = await ApiService.checkIn(userId);

      // 更新签到状态
      _checkInStatus = _checkInStatus?.copyWith(
        hasCheckedToday: true,
        consecutiveDays: checkInData.consecutiveDays,
        canCheckIn: false,
      );

      // 添加新的签到记录到历史记录顶部
      final newRecord = CheckInRecord(
        checkInDate: DateTime.now().toString().split(' ')[0], // yyyy-MM-dd格式
        consecutiveDays: checkInData.consecutiveDays,
        expReward: checkInData.expGained,
        isSpecialReward: checkInData.hasSpecialReward,
        specialRewardDesc: checkInData.specialReward,
      );
      _checkInHistory.insert(0, newRecord);

      _setSuccess(checkInData.successText);
      debugPrint('✅ 签到成功: ${checkInData.successText}');

      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : '签到失败: $e';
      _setError(message);
      debugPrint('❌ 签到失败: $e');
      return false;
    } finally {
      _isCheckingIn = false;
      notifyListeners();
    }
  }

  /// 加载签到历史记录
  Future<void> loadCheckInHistory(String userId, {bool refresh = false}) async {
    if (_isLoadingHistory && !refresh) return;

    try {
      _isLoadingHistory = true;
      if (refresh) {
        _historyPage = 1;
        _hasMoreHistory = true;
        _checkInHistory.clear();
      }
      _errorMessage = null;
      notifyListeners();

      final result = await ApiService.getCheckInHistory(userId,
          page: _historyPage, pageSize: 20);

      final records = result['records'] as List<CheckInRecord>;
      final total = result['total'] as int;

      if (refresh) {
        _checkInHistory = records;
      } else {
        _checkInHistory.addAll(records);
      }

      _historyTotal = total;
      _hasMoreHistory = _checkInHistory.length < total;
      _historyPage++;

      debugPrint('✅ 签到历史加载成功: ${records.length} 条记录');
    } catch (e) {
      final message = e is ApiException ? e.message : '获取签到历史失败: $e';
      _setError(message);
      debugPrint('❌ 获取签到历史失败: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// 加载经验日志
  Future<void> loadExpLogs(String userId, {bool refresh = false}) async {
    if (_isLoadingExpLogs && !refresh) return;

    try {
      _isLoadingExpLogs = true;
      if (refresh) {
        _expLogPage = 1;
        _hasMoreExpLogs = true;
        _expLogs.clear();
      }
      _errorMessage = null;
      notifyListeners();

      final result = await ApiService.getExpLogs(userId,
          page: _expLogPage, pageSize: 20);

      final logs = result['logs'] as List<ExpLogRecord>;
      final total = result['total'] as int;

      if (refresh) {
        _expLogs = logs;
      } else {
        _expLogs.addAll(logs);
      }

      _expLogTotal = total;
      _hasMoreExpLogs = _expLogs.length < total;
      _expLogPage++;

      debugPrint('✅ 经验日志加载成功: ${logs.length} 条记录');
    } catch (e) {
      final message = e is ApiException ? e.message : '获取经验日志失败: $e';
      _setError(message);
      debugPrint('❌ 获取经验日志失败: $e');
    } finally {
      _isLoadingExpLogs = false;
      notifyListeners();
    }
  }

  /// 获取今日是否已签到
  bool get hasCheckedToday => _checkInStatus?.hasCheckedToday ?? false;

  /// 获取是否可以签到
  bool get canCheckIn => _checkInStatus?.canCheckIn ?? false;

  /// 获取连续签到天数
  int get consecutiveDays => _checkInStatus?.consecutiveDays ?? 0;

  /// 获取今日签到奖励
  int get todayReward => _checkInStatus?.todayReward ?? 0;

  /// 获取明日签到奖励
  int get nextDayReward => _checkInStatus?.nextDayReward ?? 10;

  /// 获取本周签到记录
  List<CheckInRecord> get thisWeekRecords {
    return _checkInHistory.where((record) => record.isThisWeek).toList();
  }

  /// 获取今日签到经验日志
  List<ExpLogRecord> get todayExpLogs {
    return _expLogs.where((log) => log.isToday).toList();
  }

  /// 获取特定来源的经验日志
  List<ExpLogRecord> getExpLogsBySource(String source) {
    return _expLogs.where((log) => log.source == source).toList();
  }

  /// 清除所有数据（用于用户登出时）
  void clear() {
    _checkInStatus = null;
    _checkInHistory.clear();
    _expLogs.clear();
    _historyPage = 1;
    _historyTotal = 0;
    _hasMoreHistory = true;
    _expLogPage = 1;
    _expLogTotal = 0;
    _hasMoreExpLogs = true;
    _isLoading = false;
    _isCheckingIn = false;
    _isLoadingHistory = false;
    _isLoadingExpLogs = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}