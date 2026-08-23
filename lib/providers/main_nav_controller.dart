import 'package:flutter/foundation.dart';

/// 用于从子页面请求切换 [MainPage] 底栏 Tab（避免仅靠 Navigator 无法切换 IndexedStack）。
///
/// Tab 索引与 [MainPage] 中 `_pageBuilders` 顺序一致：
/// 0 首页 · 1 好友 · 2 AI伙伴 · 3 社区 · 4 我的
class MainNavController extends ChangeNotifier {
  int? _pendingTabIndex;

  /// 取出并消费一次 Tab 跳转请求；若无请求返回 `null`。
  int? consumeTabRequest() {
    final v = _pendingTabIndex;
    _pendingTabIndex = null;
    return v;
  }

  /// 请求切换到指定底栏索引；[MainPage] 应在监听中调用 [consumeTabRequest]。
  void requestTab(int index) {
    if (index < 0) return;
    _pendingTabIndex = index;
    notifyListeners();
  }

  /// 兼容旧探索入口；探索内容统一回到首页，避免创建重复主入口。
  void requestExplore({int subTab = 0}) {
    requestTab(0);
  }
}
