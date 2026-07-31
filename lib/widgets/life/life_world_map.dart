import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';
import 'life_empty_state.dart';
import 'life_world_canvas.dart';

/// 世界地图组件 — 2D 空间场景，按实体世界坐标可视化。
///
/// 正式产品路径：从关系首页「TA 的世界」进入（方案 2：陪伴第一眼，地图在世界延伸）。
/// 渲染走 [LifeWorldCanvas]（CustomPaint + 坐标插值）。
/// [edgeToEdge]=true 时全屏铺底，供 Stack 层叠信息面板。
class LifeWorldMap extends StatelessWidget {
  final List<LifeEntity> entities;
  final String weather; // clear/rain/drought/storm
  final void Function(int entityId)? onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  /// 空状态引导关闭回调（可选）
  final VoidCallback? onEmptyDismissed;

  /// 全屏铺底（无外边距 / 圆角卡片壳）
  final bool edgeToEdge;

  const LifeWorldMap({
    super.key,
    required this.entities,
    this.weather = 'clear',
    this.onEntityTap,
    this.onEntityLongPress,
    this.onEmptyDismissed,
    this.edgeToEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    final stage = AnimatedSwitcher(
      duration: MoeTokens.motionFadeDuration,
      child: entities.isEmpty
          ? LifeEmptyState(
              key: const ValueKey('empty_state'),
              onDismissed: () => onEmptyDismissed?.call(),
            )
          : LifeWorldCanvas(
              key: const ValueKey('canvas_map'),
              entities: entities,
              weather: weather,
              onEntityTap: onEntityTap,
              onEntityLongPress: onEntityLongPress,
            ),
    );

    if (edgeToEdge) {
      return SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.45, -0.72),
              radius: 1.28,
              colors: [Color(0xFFFFF6D8), Color(0xFFE2F8EA), Color(0xFFDDEBFF)],
              stops: [0, 0.52, 1],
            ),
          ),
          child: stage,
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(
            center: Alignment(-0.45, -0.72),
            radius: 1.28,
            colors: [Color(0xFFFFF6D8), Color(0xFFE2F8EA), Color(0xFFDDEBFF)],
            stops: [0, 0.52, 1],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: stage,
      ),
    );
  }
}
