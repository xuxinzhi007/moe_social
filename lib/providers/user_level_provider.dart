import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_level.dart';
import '../services/api_service.dart';

/// 用户等级系统状态管理Provider
/// 管理用户等级信息、经验值、升级状态等功能
class UserLevelProvider extends ChangeNotifier {
  // 用户等级信息
  UserLevelInfo? _userLevel;
  UserLevelInfo? get userLevel => _userLevel;

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 错误状态
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 升级动画状态
  bool _isLevelingUp = false;
  bool get isLevelingUp => _isLevelingUp;

  int? _previousLevel;
  int? get previousLevel => _previousLevel;

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 设置错误消息
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 获取用户等级信息
  Future<void> loadUserLevel(String userId) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final levelInfo = await ApiService.getUserLevel(userId);

      // 检查是否升级
      if (_userLevel != null && levelInfo.level > _userLevel!.level) {
        _previousLevel = _userLevel!.level;
        _isLevelingUp = true;
        debugPrint('🎉 用户升级: Lv.${_previousLevel} → Lv.${levelInfo.level}');
      }

      _userLevel = levelInfo;
      debugPrint('✅ 用户等级信息加载成功: Lv.${levelInfo.level} (${levelInfo.experience}/${levelInfo.nextLevelExp})');
    } catch (e) {
      final message = e is ApiException ? e.message : '获取用户等级信息失败: $e';
      _setError(message);
      debugPrint('❌ 获取用户等级信息失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新用户经验值（不发起网络请求，用于本地状态更新）
  void updateExperience(int expGained) {
    if (_userLevel == null || expGained <= 0) return;

    final currentLevel = _userLevel!.level;
    final newExperience = _userLevel!.experience + expGained;
    final newTotalExp = _userLevel!.totalExp + expGained;

    // 简单的等级计算（实际应该与后端保持一致）
    int newLevel = currentLevel;
    int nextLevelExp = _userLevel!.nextLevelExp;
    double progress = _userLevel!.progress;

    // 如果经验值超过了升级所需经验，可能升级了
    if (newExperience >= nextLevelExp) {
      // 这里简化处理，实际应该查询等级配置
      newLevel = _calculateLevel(newTotalExp);
      if (newLevel > currentLevel) {
        _previousLevel = currentLevel;
        _isLevelingUp = true;
        debugPrint('🎉 本地检测到等级提升: Lv.$currentLevel → Lv.$newLevel');
      }
      nextLevelExp = _calculateNextLevelExp(newLevel);
    }

    // 计算新的进度
    final expInCurrentLevel = newExperience - _calculateLevelStartExp(newLevel);
    final expNeededForNextLevel = nextLevelExp - _calculateLevelStartExp(newLevel);
    progress = expNeededForNextLevel > 0 ? expInCurrentLevel / expNeededForNextLevel : 1.0;

    _userLevel = _userLevel!.copyWith(
      level: newLevel,
      experience: newExperience,
      totalExp: newTotalExp,
      nextLevelExp: nextLevelExp,
      progress: progress,
    );

    notifyListeners();
  }

  /// 完成升级动画
  void completeLevelUp() {
    _isLevelingUp = false;
    _previousLevel = null;
    notifyListeners();
  }

  /// 简化的等级计算（应与后端逻辑保持一致）
  int _calculateLevel(int totalExp) {
    if (totalExp < 100) return 1;
    if (totalExp < 500) return 2;
    if (totalExp < 2000) return 3;
    if (totalExp < 5000) return 4;
    return 5; // 最高等级
  }

  /// 计算等级开始所需的经验值
  int _calculateLevelStartExp(int level) {
    switch (level) {
      case 1: return 0;
      case 2: return 100;
      case 3: return 500;
      case 4: return 2000;
      case 5: return 5000;
      default: return 5000;
    }
  }

  /// 计算升级到下一等级所需的经验值
  int _calculateNextLevelExp(int level) {
    switch (level) {
      case 1: return 100;
      case 2: return 500;
      case 3: return 2000;
      case 4: return 5000;
      case 5: return 5000; // 最高等级，不再升级
      default: return 5000;
    }
  }

  /// 获取等级标题
  String getLevelTitle(int level) {
    switch (level) {
      case 1: return '萌新菜鸟';
      case 2: return '活跃新手';
      case 3: return '社区中坚';
      case 4: return '资深达人';
      case 5: return '社区大师';
      default: return '未知等级';
    }
  }

  /// 获取等级徽章URL
  String getLevelBadgeUrl(int level) {
    // 这里可以返回对应等级的徽章图片URL
    return '/assets/images/badges/level_$level.png';
  }

  /// 获取当前等级
  int get currentLevel => _userLevel?.level ?? 1;

  /// 获取当前经验值
  int get currentExperience => _userLevel?.experience ?? 0;

  /// 获取总经验值
  int get totalExperience => _userLevel?.totalExp ?? 0;

  /// 获取到下一级所需经验
  int get expToNext => _userLevel?.expToNext ?? 100;

  /// 获取等级进度（0-1）
  double get progress => _userLevel?.progress ?? 0.0;

  /// 获取等级进度百分比（0-100）
  double get progressPercentage => _userLevel?.progressPercentage ?? 0.0;

  /// 获取等级标题
  String get levelTitle => _userLevel?.levelTitle ?? '萌新菜鸟';

  /// 获取是否为最高等级
  bool get isMaxLevel => _userLevel?.isMaxLevel ?? false;

  /// 获取等级颜色
  Color getLevelColor(int level) {
    switch (level) {
      case 1: return const Color(0xFF91EAE4); // 萌新菜鸟 - 青色
      case 2: return const Color(0xFF7F7FD5); // 活跃新手 - 紫色
      case 3: return const Color(0xFF86A8E7); // 社区中坚 - 蓝紫色
      case 4: return const Color(0xFFFFB347); // 资深达人 - 橙色
      case 5: return const Color(0xFFFFD700); // 社区大师 - 金色
      default: return const Color(0xFF91EAE4);
    }
  }

  /// 获取等级渐变色
  List<Color> getLevelGradient(int level) {
    switch (level) {
      case 1:
        return [const Color(0xFF91EAE4), const Color(0xFF7F7FD5)];
      case 2:
        return [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)];
      case 3:
        return [const Color(0xFF86A8E7), const Color(0xFFFFB347)];
      case 4:
        return [const Color(0xFFFFB347), const Color(0xFFFFD700)];
      case 5:
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      default:
        return [const Color(0xFF91EAE4), const Color(0xFF7F7FD5)];
    }
  }

  /// 获取等级特权列表
  List<String> getLevelPrivileges(int level) {
    switch (level) {
      case 1:
        return ['基础发帖功能', '基础评论功能'];
      case 2:
        return ['基础发帖功能', '基础评论功能', '点赞功能', '关注功能'];
      case 3:
        return ['基础发帖功能', '基础评论功能', '点赞功能', '关注功能', '创建话题', '上传图片'];
      case 4:
        return ['基础发帖功能', '基础评论功能', '点赞功能', '关注功能', '创建话题', '上传图片', '专属徽章', 'VIP购买优惠'];
      case 5:
        return ['基础发帖功能', '基础评论功能', '点赞功能', '关注功能', '创建话题', '上传图片', '专属徽章', 'VIP购买优惠', '管理权限申请', '社区活动优先参与'];
      default:
        return ['基础功能'];
    }
  }

  /// 清除所有数据（用于用户登出时）
  void clear() {
    _userLevel = null;
    _isLoading = false;
    _errorMessage = null;
    _isLevelingUp = false;
    _previousLevel = null;
    notifyListeners();
  }
}