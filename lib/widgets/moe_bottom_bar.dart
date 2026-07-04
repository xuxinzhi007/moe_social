import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 360;
        final ultraCompact = width < 330;
        final labelFontSize = ultraCompact ? 10.0 : (compact ? 11.0 : 12.0);

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ultraCompact ? 8 : 12,
                vertical: compact ? 6 : 8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.15)
                                : Colors.transparent,
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
                                                  const Duration(milliseconds: 300),
                                              curve: Curves.elasticOut,
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
          ),
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
