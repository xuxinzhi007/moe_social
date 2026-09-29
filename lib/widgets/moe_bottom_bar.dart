import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/feature_flags.dart';
import '../theme/moe_tokens.dart';
import 'moe_glass_surface.dart';
import 'motion/moe_motion.dart';

/// 选中图标相对未选中的缩放。只表达当前项，不改变点击区域。
const double _selectedIconScale = 1.06;

class MoeBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<NavigationDestination> destinations;
  final List<int> badgeCounts;

  const MoeBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.destinations,
    this.badgeCounts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = MoeTokens.primary;
    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final iconSize = compact ? MoeTokens.textLg : MoeTokens.textXl;

        final innerContent = SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceMd,
              MoeTokens.spaceXs,
              MoeTokens.spaceMd,
              MoeTokens.spaceXs,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MoeTokens.surface1.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                border: Border.all(color: MoeTokens.surfaceBorder),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MoeTokens.spaceXs),
                child: LayoutBuilder(
                  builder: (context, barConstraints) {
                    final count = destinations.length;
                    final itemWidth =
                        count == 0 ? 0.0 : barConstraints.maxWidth / count;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (count > 0)
                          AnimatedPositioned(
                            duration: motion,
                            curve: Curves.easeOutCubic,
                            left: itemWidth * selectedIndex,
                            top: 0,
                            bottom: 0,
                            width: itemWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MoeTokens.spaceXs,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    MoeTokens.radiusFull,
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        Row(
                          children: List.generate(count, (index) {
                            final isSelected = selectedIndex == index;
                            final destination = destinations[index];
                            final iconData = _resolveIconData(
                              isSelected
                                  ? (destination.selectedIcon ??
                                      destination.icon)
                                  : destination.icon,
                            );
                            final badgeCount = index < badgeCounts.length
                                ? badgeCounts[index]
                                : 0;
                            return Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (index == selectedIndex) return;
                                    HapticFeedback.selectionClick();
                                    onItemSelected(index);
                                  },
                                  borderRadius: BorderRadius.circular(
                                    MoeTokens.radiusFull,
                                  ),
                                  splashColor:
                                      primaryColor.withValues(alpha: 0.1),
                                  highlightColor:
                                      primaryColor.withValues(alpha: 0.04),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: MoeTokens.spaceXs,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: iconSize + MoeTokens.spaceSm,
                                          height: iconSize,
                                          child: Center(
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                AnimatedScale(
                                                  scale: isSelected
                                                      ? _selectedIconScale
                                                      : 1,
                                                  duration: motion,
                                                  curve: Curves.easeOutCubic,
                                                  child: AnimatedSwitcher(
                                                    duration: motion,
                                                    switchInCurve:
                                                        Curves.easeOutCubic,
                                                    switchOutCurve:
                                                        Curves.easeInCubic,
                                                    transitionBuilder:
                                                        (child, animation) {
                                                      return FadeTransition(
                                                        opacity: animation,
                                                        child: ScaleTransition(
                                                          scale: animation,
                                                          child: child,
                                                        ),
                                                      );
                                                    },
                                                    child: Icon(
                                                      iconData,
                                                      key: ValueKey(iconData),
                                                      color: isSelected
                                                          ? primaryColor
                                                          : MoeTokens.hintText,
                                                      size: iconSize,
                                                    ),
                                                  ),
                                                ),
                                                if (badgeCount > 0)
                                                  Positioned(
                                                    right: -2,
                                                    top: -4,
                                                    child: _Badge(
                                                      count: badgeCount,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        AnimatedDefaultTextStyle(
                                          duration: motion,
                                          curve: Curves.easeOutCubic,
                                          style: TextStyle(
                                            color: isSelected
                                                ? primaryColor
                                                : MoeTokens.hintText,
                                            fontWeight: isSelected
                                                ? MoeTokens.fontWeightTitle
                                                : MoeTokens.fontWeightSubtitle,
                                            fontSize: compact
                                                ? MoeTokens.textXs
                                                : MoeTokens.textSm,
                                            height: 1.1,
                                          ),
                                          child: Text(
                                            destination.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        if (FeatureFlags.glassNavigation) {
          return MoeGlassSurface(
            sigma: MoeTokens.blurLight,
            tint: MoeTokens.surface0.withValues(alpha: 0.72),
            showBorder: false,
            child: innerContent,
          );
        }

        return ColoredBox(
          color: MoeTokens.surface0,
          child: innerContent,
        );
      },
    );
  }

  IconData _resolveIconData(Widget? iconWidget) {
    if (iconWidget is Icon) {
      final resolved = iconWidget.icon;
      if (resolved != null) return resolved;
    }
    return Icons.circle_rounded;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceXs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: MoeTokens.danger,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: MoeTokens.textXs,
          fontWeight: MoeTokens.fontWeightSubtitle,
          height: 1.1,
        ),
      ),
    );
  }
}
