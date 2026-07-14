import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import 'life_event_tile.dart';

/// 事件流组件 — 反向滚动列表，最新事件在上。
///
/// 使用时间线 + 类型图标 + 颜色编码增强展示。
/// 仅最新 3 条事件播放入场动画（隐式动画，无手动 Controller）。
class LifeEventFeed extends StatelessWidget {
  final List<LifeEvent> events;

  const LifeEventFeed({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('暂无事件', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    // 最新事件在前
    final reversed = events.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final event = reversed[index];
        // 仅最新 3 条播放入场动画
        final shouldAnimate = index < 3;
        return LifeEventTile(
          event: event,
          showTimeline: true,
          isLast: index == reversed.length - 1,
          animate: shouldAnimate,
        );
      },
    );
  }
}
