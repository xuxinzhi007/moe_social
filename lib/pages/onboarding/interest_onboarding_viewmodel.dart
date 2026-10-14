import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/community_group.dart';
import '../../services/community_service.dart';

/// 兴趣选项：name 用于展示与本地记录，keyword 用于圈子搜索匹配（规则版）。
class OnboardingInterest {
  const OnboardingInterest({
    required this.id,
    required this.name,
    required this.keyword,
    required this.icon,
  });

  final String id;
  final String name;
  final String keyword;
  final IconData icon;
}

class InterestOnboardingViewModel extends ChangeNotifier {
  static const List<OnboardingInterest> interests = [
    OnboardingInterest(
        id: 'acg', name: '二次元', keyword: '二次元', icon: Icons.auto_awesome_rounded),
    OnboardingInterest(
        id: 'anime', name: '追番', keyword: '动漫', icon: Icons.tv_rounded),
    OnboardingInterest(
        id: 'game', name: '游戏', keyword: '游戏', icon: Icons.sports_esports_rounded),
    OnboardingInterest(
        id: 'draw', name: '绘画', keyword: '绘画', icon: Icons.palette_rounded),
    OnboardingInterest(
        id: 'music', name: '音乐', keyword: '音乐', icon: Icons.music_note_rounded),
    OnboardingInterest(
        id: 'food', name: '美食', keyword: '美食', icon: Icons.cake_rounded),
    OnboardingInterest(
        id: 'travel', name: '旅行', keyword: '旅行', icon: Icons.luggage_rounded),
    OnboardingInterest(
        id: 'photo', name: '摄影', keyword: '摄影', icon: Icons.photo_camera_rounded),
    OnboardingInterest(
        id: 'read', name: '读书', keyword: '读书', icon: Icons.menu_book_rounded),
    OnboardingInterest(
        id: 'study', name: '学习', keyword: '学习', icon: Icons.school_rounded),
    OnboardingInterest(
        id: 'pet', name: '萌宠', keyword: '宠物', icon: Icons.pets_rounded),
    OnboardingInterest(
        id: 'daily', name: '日常', keyword: '日常', icon: Icons.wb_sunny_rounded),
  ];

  static const int maxSelection = 5;
  static const int _maxRecommendations = 12;

  final Set<String> _selectedIds = {};
  List<CommunityGroup> _groups = const [];
  final Set<String> _joiningIds = {};
  bool _loading = false;
  Object? _error;
  bool _disposed = false;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  List<CommunityGroup> get groups => _groups;
  bool get loading => _loading;
  Object? get error => _error;

  bool isJoining(String groupId) => _joiningIds.contains(groupId);

  bool isSelected(String id) => _selectedIds.contains(id);

  List<String> get selectedNames => [
        for (final i in interests)
          if (_selectedIds.contains(i.id)) i.name,
      ];

  void toggleInterest(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      if (_selectedIds.length >= maxSelection) return;
      _selectedIds.add(id);
    }
    _notify();
  }

  /// 规则版推荐：按已选兴趣关键词搜圈子，合并去重后按成员数排序。
  Future<void> loadRecommendations() async {
    final keywords = [
      for (final i in interests)
        if (_selectedIds.contains(i.id)) i.keyword,
    ];
    if (keywords.isEmpty) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      final userId = AuthService.currentUser;
      final results = await Future.wait([
        for (final kw in keywords)
          CommunityService.getCommunityGroups(
            page: 1,
            pageSize: 8,
            keyword: kw,
            userId: userId,
          ),
      ]);
      final byId = <String, CommunityGroup>{};
      for (final res in results) {
        final raw = res['groups'] as List<Map<String, dynamic>>;
        for (final m in raw) {
          final g = CommunityGroup.fromApi(m);
          if (g.id.isEmpty) continue;
          final prev = byId[g.id];
          if (prev == null || g.memberCount > prev.memberCount) {
            byId[g.id] = g;
          }
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.memberCount.compareTo(a.memberCount));
      if (_disposed) return;
      _groups = merged.take(_maxRecommendations).toList(growable: false);
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = e;
      _notify();
    }
  }

  /// 返回 null 表示成功，否则为错误文案。
  Future<String?> toggleJoin(CommunityGroup group) async {
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) return '请先登录';
    if (_joiningIds.contains(group.id)) return null;
    _joiningIds.add(group.id);
    _notify();
    try {
      if (group.isJoined) {
        await CommunityService.leaveCommunityGroup(
          groupId: group.id,
          userId: userId,
        );
      } else {
        await CommunityService.joinCommunityGroup(
          groupId: group.id,
          userId: userId,
        );
      }
      _groups = [
        for (final g in _groups)
          if (g.id == group.id)
            CommunityGroup(
              id: g.id,
              name: g.name,
              description: g.description,
              coverImage: g.coverImage,
              avatar: g.avatar,
              memberCount: group.isJoined
                  ? (g.memberCount > 0 ? g.memberCount - 1 : 0)
                  : g.memberCount + 1,
              isJoined: !group.isJoined,
              isPublic: g.isPublic,
              creatorId: g.creatorId,
              creatorName: g.creatorName,
              tags: g.tags,
            )
          else
            g,
      ];
      return null;
    } catch (_) {
      return group.isJoined ? '退出失败，请稍后重试' : '加入失败，请稍后重试';
    } finally {
      _joiningIds.remove(group.id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
