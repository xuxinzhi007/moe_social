import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/companion_service.dart';

/// AI 伙伴主页（GameHub）仪表盘加载状态。
class CompanionHubViewModel extends ChangeNotifier {
  CompanionHubViewModel({CompanionService? companionService})
      : _companion = companionService ?? CompanionService();

  final CompanionService _companion;

  bool _isLoading = true;
  String? _loadError;
  CompanionProfileData _profile = const CompanionProfileData();
  CompanionStateData _state = const CompanionStateData();
  CompanionCommunityIdentityData? _communityIdentity;
  List<CompanionMemoryData> _memories = const [];
  List<CompanionChatLogData> _chatHistory = const [];
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  CompanionProfileData get profile => _profile;
  CompanionStateData get state => _state;
  CompanionCommunityIdentityData? get communityIdentity => _communityIdentity;
  List<CompanionMemoryData> get memories => _memories;
  List<CompanionChatLogData> get chatHistory => _chatHistory;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _loadError = null;
    _notify();

    try {
      final snapshot = await _companion.getSnapshot();
      List<CompanionMemoryData> memories = const [];
      List<CompanionChatLogData> history = const [];

      try {
        memories = await _companion.listMemories(limit: 6);
      } catch (_) {}

      try {
        history = await _companion.listChatHistory(limit: 8);
      } catch (_) {}

      CompanionCommunityIdentityData? identity;
      if (snapshot.profile.agentId.trim().isNotEmpty) {
        try {
          identity = await _companion.getCommunityIdentity();
        } catch (_) {}
      }

      if (_disposed) return;
      _profile = snapshot.profile;
      _state = snapshot.state;
      _communityIdentity = identity;
      _memories = memories;
      _chatHistory = history;
      _isLoading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _loadError = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      _notify();
    }
  }

  Future<void> applyUpdatedProfile(CompanionProfileData profile) async {
    final result = await _companion.updateProfile(profile);
    if (_disposed) return;
    _profile = result;
    _notify();
    await loadDashboard();
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
