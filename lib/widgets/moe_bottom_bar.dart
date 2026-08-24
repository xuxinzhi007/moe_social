import 'package:flutter/material.dart';

import '../constants/feature_flags.dart';
import '../theme/moe_tokens.dart';
import 'moe_glass_surface.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 360;
        final ultraCompact = width < 330;
        final labelFontSize = ultraCompact ? 10.0 : (compact ? 11.0 : 12.0);

        final glassNav = FeatureFlags.chatGlassNav;

        final Widget innerContent = SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ultraCompact ? 8 : 12,
              vertical: compact ? 6 : 8,
            ),
            child: Container(
                decoration: BoxDecoration(
                  color: MoeTokens.surface1.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: MoeTokens.surfaceBorder,
                    width: 1,
                  ),
                  boxShadow: MoeTokens.shadowCard(),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
                  child: Row(
                    children: List.generate(destinations.length, (index) {
                      final isSelected = selectedIndex == index;
                      final destination = destinations[index];
                      final currentIconWidget = isSelected
                          ? (destination.selectedIcon ?? destination.icon)
                          : destination.icon;
                      final iconData = _resolveIconData(
                        currentIconWidget,
                      );
                      final badgeCount =
                          index < badgeCounts.length ? badgeCounts[index] : 0;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      primaryColor.withValues(alpha: 0.16),
                                      primaryColor.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => onItemSelected(index),
                              borderRadius: BorderRadius.circular(20),
                              splashColor: primaryColor.withValues(alpha: 0.12),
                              highlightColor:
                                  primaryColor.withValues(alpha: 0.06),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 3 : 5,
                                  vertical: compact ? 5 : 7,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: compact ? 26 : 30,
                                      height: compact ? 26 : 30,
                                      child: Center(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(
                                                begin: 1.0,
                                                end: isSelected ? 1.12 : 1.0,
                                              ),
                                              duration:
                                                  const Duration(milliseconds: 200),
                                              curve: Curves.easeOut,
                                              builder: (context, scale, child) {
                                                return Transform.scale(
                                                  scale: scale,
                                                  child: Icon(
                                                    iconData,
                                                    color: isSelected
                                                        ? primaryColor
                                                        : Colors.grey[400],
                                                    size: compact ? 21 : 24,
                                                  ),
                                                );
                                              },
                                            ),
                                            if (badgeCount > 0)
                                              Positioned(
                                                right: -10,
                                                top: -6,
                                                child: _Badge(count: badgeCount),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      height: labelFontSize * 1.25,
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            destination.label,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? primaryColor
                                                  : Colors.grey[500],
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              fontSize: labelFontSize,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          );

        if (glassNav) {
          return MoeGlassSurface(
            sigma: MoeTokens.blurLight,
            tint: MoeTokens.surface0.withValues(alpha: 0.75),
            showBorder: false,
            child: innerContent,
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: MoeTokens.surface0,
            boxShadow: MoeTokens.shadowCard(),
          ),
          child: innerContent,
        );
      },
    );
  }

  IconData _resolveIconData(Widget? iconWidget) {
    if (iconWidget is Icon) {
      final resolved = iconWidget.icon;
      if (resolved != null) {
        return resolved;
      }
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
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D6D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
