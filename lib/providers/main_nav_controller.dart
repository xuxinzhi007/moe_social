import 'package:flutter/foundation.dart';

/// 用于从子页面请求切换 [MainPage] 底栏 Tab（避免仅靠 Navigator 无法切换 IndexedStack）。
///
/// Tab 索引与 [MainPage] 中 `_pageBuilders` 顺序一致：
/// 0 首页 · 1 同好与人脉 · 2 兴趣社区 · 3 探索 · 4 我的
class MainNavController extends ChangeNotifier {
  int? _pendingTabIndex;
  int? _pendingExploreSubTab;

  /// 取出并消费一次 Tab 跳转请求；若无请求返回 `null`。
  int? consumeTabRequest() {
    final v = _pendingTabIndex;
    _pendingTabIndex = null;
    return v;
  }

  /// 探索页内 Segmented 索引：0 同好 · 1 玩法。
  int? consumeExploreSubTab() {
    final v = _pendingExploreSubTab;
    _pendingExploreSubTab = null;
    return v;
  }

  /// 请求切换到指定底栏索引；[MainPage] 应在监听中调用 [consumeTabRequest]。
  void requestTab(int index) {
    if (index < 0) return;
    _pendingTabIndex = index;
    notifyListeners();
  }

  /// 进入底栏「探索」并打开指定子 Tab（如 `/match` 深链落到「同好」）。
  void requestExplore({int subTab = 0}) {
    _pendingExploreSubTab = subTab.clamp(0, 1);
    requestTab(3);
  }
}
