import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';
import 'motion/moe_pressable.dart';

/// 底部分段切换。选中块沿轨道滑过去，页面不要各自淡出一块底色。
class MoeSegmentItem {
  const MoeSegmentItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class MoeSegmentBar extends StatelessWidget {
  const MoeSegmentBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<MoeSegmentItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionMedium;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / count;
          final safeIndex = index.clamp(0, count - 1);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: motion,
                curve: Curves.easeOutCubic,
                left: slot * safeIndex,
                width: slot,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MoeTokens.softChipBg,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: MoePressable(
                        onTap: () => onChanged(i),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                        child: _SegmentLabel(
                          item: items[i],
                          selected: i == safeIndex,
                          duration: motion,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.item,
    required this.selected,
    required this.duration,
  });

  final MoeSegmentItem item;
  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = selected ? MoeTokens.primary : MoeTokens.hintText;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: duration,
      builder: (context, color, _) {
        final ink = color ?? target;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 16, color: ink),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        );
      },
    );
  }
}
