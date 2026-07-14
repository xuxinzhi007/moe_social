import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';

/// 事件类型 → (图标, 颜色) 映射。
class _EventTypeStyle {
  final IconData icon;
  final Color color;
  const _EventTypeStyle(this.icon, this.color);
}

/// 根据事件 type 字段获取对应的图标与颜色。
_EventTypeStyle _resolveEventTypeStyle(String type) {
  final t = type.toLowerCase();
  if (t.contains('feed') || t.contains('eat')) {
    return _EventTypeStyle(Icons.restaurant, const Color(0xFFFF9800)); // 橙色
  }
  if (t.contains('sleep')) {
    return _EventTypeStyle(Icons.bedtime, const Color(0xFF2196F3)); // 蓝色
  }
  if (t.contains('growth')) {
    return _EventTypeStyle(Icons.auto_awesome, const Color(0xFFFFC107)); // 金色
  }
  if (t.contains('social') || t.contains('bond') || t.contains('relationship')) {
    return _EventTypeStyle(Icons.favorite, const Color(0xFFE53935)); // 红色
  }
  if (t.contains('user_feed') || t.contains('user_pet') || t.contains('pet')) {
    return _EventTypeStyle(Icons.touch_app, const Color(0xFF9C27B0)); // 紫色
  }
  if (t.contains('death')) {
    return _EventTypeStyle(Icons.sentiment_very_dissatisfied, const Color(0xFF9E9E9E)); // 灰色
  }
  if (t.contains('birth')) {
    return _EventTypeStyle(Icons.cake, const Color(0xFFE91E63)); // 粉色
  }
  // 默认
  return _EventTypeStyle(Icons.circle, const Color(0xFF9E9E9E));
}

/// 相对时间格式化（不引入额外依赖）。
String formatRelativeTime(DateTime eventTime) {
  final now = DateTime.now();
  final diff = now.difference(eventTime);
  if (diff.isNegative) {
    // 未来时间，直接显示绝对时间
    final mm = eventTime.month.toString().padLeft(2, '0');
    final dd = eventTime.day.toString().padLeft(2, '0');
    final hh = eventTime.hour.toString().padLeft(2, '0');
    final mi = eventTime.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  final mm = eventTime.month.toString().padLeft(2, '0');
  final dd = eventTime.day.toString().padLeft(2, '0');
  final hh = eventTime.hour.toString().padLeft(2, '0');
  final mi = eventTime.minute.toString().padLeft(2, '0');
  return '$mm-$dd $hh:$mi';
}

/// 公共事件 Tile 组件 — 供事件流和详情页复用。
///
/// - [compact] 控制间距（详情页用紧凑模式）
/// - [showTimeline] 是否显示左侧时间线竖线
/// - [isLast] 是否为最后一条（控制时间线是否向下延伸）
/// - [animate] 是否播放入场动画（仅最新 3 条建议开启）
class LifeEventTile extends StatelessWidget {
  final LifeEvent event;
  final bool compact;
  final bool showTimeline;
  final bool isLast;
  final bool animate;

  const LifeEventTile({
    super.key,
    required this.event,
    this.compact = false,
    this.showTimeline = false,
    this.isLast = false,
    this.animate = false,
  });

  /// 判断是否为重要事件。
  bool get _isImportant => event.isImportant;

  /// 判断是否为成长事件。
  bool get _isGrowthEvent => event.type.toLowerCase().contains('growth');

  /// 判断是否为社交/关系事件。
  bool get _isSocialEvent {
    final t = event.type.toLowerCase();
    return t.contains('social') || t.contains('relationship') || t.contains('bond');
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = formatRelativeTime(event.timestamp);
    final isImportant = _isImportant;
    final isGrowth = _isGrowthEvent;
    final isSocial = _isSocialEvent;
    final typeStyle = _resolveEventTypeStyle(event.type);

    // 事件类型颜色（用于时间线竖线和图标）
    final Color timelineColor = isImportant
        ? const Color(0xFFFFC107)
        : typeStyle.color;

    // 背景与边框颜色
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
      bgColor = MoeTokens.cardBackground;
      borderColor = Colors.transparent;
    }

    // 卡片装饰
    final BoxDecoration cardDecoration;
    if (isImportant) {
      cardDecoration = BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
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
      );
    } else {
      cardDecoration = BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
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
      );
    }

    final double hPad = compact ? MoeTokens.spaceMd : MoeTokens.spaceSm + 2;
    final double vPad = compact ? MoeTokens.spaceSm : MoeTokens.spaceSm;
    final double bottomMargin = compact ? MoeTokens.spaceXs : 6;

    // 卡片内容
    final card = Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: cardDecoration,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧图标
          _buildIcon(isImportant, isGrowth, isSocial, typeStyle),
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
                                : MoeTokens.bodyText,
                    fontWeight: (isImportant || isGrowth || isSocial)
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: MoeTokens.textXs, color: MoeTokens.hintText),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 时间线包裹
    Widget content = card;
    if (showTimeline) {
      content = _TimelineWrapper(
        color: timelineColor,
        isLast: isLast,
        child: card,
      );
    }

    // 入场动画（仅对最新条目使用隐式动画）
    if (animate) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: MoeTokens.motionFadeDuration,
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * MoeTokens.motionFadeOffset * 0.3),
              child: child,
            ),
          );
        },
        child: content,
      );
    }

    return content;
  }

  /// 构建左侧图标。
  Widget _buildIcon(
    bool isImportant,
    bool isGrowth,
    bool isSocial,
    _EventTypeStyle typeStyle,
  ) {
    if (isImportant) {
      return const Padding(
        padding: EdgeInsets.only(right: 6, top: 2),
        child: Icon(Icons.star, size: 14, color: Color(0xFFFFC107)),
      );
    }
    // 使用事件类型图标
    return Padding(
      padding: EdgeInsets.only(right: compact ? 6 : 8, top: 2),
      child: Icon(typeStyle.icon, size: 16, color: typeStyle.color),
    );
  }
}

/// 时间线竖线包裹器 — 在子组件左侧绘制 2px 竖线。
class _TimelineWrapper extends StatelessWidget {
  final Color color;
  final bool isLast;
  final Widget child;

  const _TimelineWrapper({
    required this.color,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线区域
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // 圆点
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                // 竖线（最后一条不向下延伸）
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧卡片
          Expanded(child: child),
        ],
      ),
    );
  }
}
