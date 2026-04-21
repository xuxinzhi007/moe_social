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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final isSelected = selectedIndex == index;
                  final destination = destinations[index];
                  
                  return GestureDetector(
                    onTap: () => onItemSelected(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 16 : 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? primaryColor.withOpacity(0.15) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 图标动画
                          // 固定占位避免 Transform.scale 在 Row 里撑破布局（小屏约 4~5px 溢出）
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 1.0,
                                  end: isSelected ? 1.15 : 1.0,
                                ),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Icon(
                                      isSelected
                                          ? (destination.selectedIcon as Icon).icon
                                          : (destination.icon as Icon).icon,
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.grey[400],
                                      size: 24,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // 文字标签动画
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            clipBehavior: Clip.none,
                            child: SizedBox(
                              width: isSelected ? null : 0,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  destination.label,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }
}
