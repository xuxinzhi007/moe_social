import 'package:flutter/material.dart';

class MoeBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<NavigationDestination> destinations;

  const MoeBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.destinations,
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
                color: Colors.black.withOpacity(0.05),
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
                      color: primaryColor.withOpacity(0.1),
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

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onItemSelected(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 3 : 5,
                              vertical: compact ? 5 : 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: compact ? 26 : 30,
                                  height: compact ? 26 : 30,
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
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
                                            isSelected
                                                ? (destination.selectedIcon
                                                        as Icon)
                                                    .icon
                                                : (destination.icon as Icon)
                                                    .icon,
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.grey[400],
                                            size: compact ? 21 : 24,
                                          ),
                                        );
                                      },
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
}
