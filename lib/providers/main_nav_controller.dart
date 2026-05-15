import 'package:flutter/foundation.dart';

/// 用于从子页面请求切换 [MainPage] 底栏 Tab（避免仅靠 Navigator 无法切换 IndexedStack）。
///
/// Tab 索引与 [MainPage] 中 `_pageBuilders` 顺序一致：
/// 0 首页 · 1 同好与人脉 · 2 兴趣社区 · 3 发现 · 4 我的
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
}
