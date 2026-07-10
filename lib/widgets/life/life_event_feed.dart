import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// 事件流组件 — 反向滚动列表，最新事件在上。
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
        return _EventTile(event: event, index: index);
      },
    );
  }
}

class _EventTile extends StatefulWidget {
  final LifeEvent event;
  final int index;

  const _EventTile({required this.event, required this.index});

  @override
  State<_EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<_EventTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 判断是否为成长事件。
  bool get _isGrowthEvent => widget.event.type == 'growth';

  /// 判断是否为社交/关系事件。
  bool get _isSocialEvent {
    final t = widget.event.type.toLowerCase();
    return t.contains('social') || t.contains('relationship') || t.contains('bond');
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final timeStr = _formatTime(event.timestamp);
    final isGrowth = _isGrowthEvent;
    final isSocial = _isSocialEvent;
    final isImportant = event.isImportant;

    // 重要事件：微高亮琥珀色背景 + 左侧金色竖条
    // 成长事件使用金色，社交事件使用绿色
    final Color bgColor;
    final Color borderColor;
    if (isImportant) {
      bgColor = Colors.amber.withValues(alpha: 0.08);
      borderColor = const Color(0xFFFFC107).withValues(alpha: 0.4);
    } else if (isGrowth) {
      bgColor = const Color(0xFFFFF8E1);
      borderColor = const Color(0xFFFFC107).withValues(alpha: 0.3);
    } else if (isSocial) {
      bgColor = const Color(0xFFE8F5E9);
      borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.3);
    } else {
      bgColor = Colors.white;
      borderColor = Colors.transparent;
    }

    // 重要事件左侧 2px 金色竖条装饰
    final leftBarDecoration = isImportant
        ? const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFFFC107), width: 2),
            ),
          )
        : null;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: leftBarDecoration != null
              ? BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: const BorderSide(color: Color(0xFFFFC107), width: 2),
                    top: BorderSide(color: borderColor, width: 1),
                    right: BorderSide(color: borderColor, width: 1),
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: (isGrowth || isSocial)
                      ? Border.all(color: borderColor, width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isGrowth
                          ? const Color(0xFFFFC107).withValues(alpha: 0.08)
                          : isSocial
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标：重要事件显示星标
              if (isImportant)
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 2),
                  child: Icon(
                    Icons.star,
                    size: 14,
                    color: Color(0xFFFFC107),
                  ),
                )
              else if (isGrowth)
                const Padding(
                  padding: EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFFFFC107),
                  ),
                )
              else if (isSocial)
                const Padding(
                  padding: EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    Icons.hub_outlined,
                    size: 16,
                    color: Color(0xFF4CAF50),
                  ),
                )
              else if (event.entityType.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Text(
                    event.entityType,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              // 中间描述 + 时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: isImportant
                            ? const Color(0xFF6D4C00)
                            : isGrowth
                                ? const Color(0xFF795548)
                                : isSocial
                                    ? const Color(0xFF2E7D32)
                                    : Colors.black87,
                        fontWeight: (isImportant || isGrowth || isSocial)
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
