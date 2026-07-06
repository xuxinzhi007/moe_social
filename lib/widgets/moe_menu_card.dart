import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_pressable.dart';

class MoeMenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  MoeMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });
}

class MoeMenuCard extends StatelessWidget {
  final List<MoeMenuItem> items;

  const MoeMenuCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCardLarge),
        boxShadow: MoeTokens.cardShadow(),
      ),
      child: Column(
        children: items.map((item) {
          final isFirst = items.first == item;
          final isLast = items.last == item;
          return Column(
            children: [
              MoePressable(
                onTap: item.onTap,
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? const Radius.circular(24) : Radius.zero,
                  topRight: isFirst ? const Radius.circular(24) : Radius.zero,
                  bottomLeft: isLast ? const Radius.circular(24) : Radius.zero,
                  bottomRight: isLast ? const Radius.circular(24) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: item.isDestructive
                                    ? Colors.redAccent
                                    : const Color(0xFF333333),
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.trailing != null)
                        item.trailing!
                      else
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.grey[300],
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 68, right: 20),
                  child: Divider(
                      height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
