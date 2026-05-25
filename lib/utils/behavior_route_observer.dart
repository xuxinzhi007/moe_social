import 'package:flutter/material.dart';

import '../services/behavior_analytics_service.dart';

/// 自动采集命名路由的进入/离开与停留时长。
class BehaviorRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _trackEnter(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    BehaviorAnalyticsService.instance.onRouteEnter(name);
  }

  void _trackLeave(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    BehaviorAnalyticsService.instance.onRouteLeave(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackLeave(previousRoute);
    _trackEnter(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackLeave(route);
    _trackEnter(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackLeave(oldRoute);
    _trackEnter(newRoute);
  }
}

final BehaviorRouteObserver behaviorRouteObserver = BehaviorRouteObserver();
