import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// 兴趣社区搜索框。圈子和讨论共用这一套，避免两套输入样式。
class CommunitySearchField extends StatelessWidget {
  const CommunitySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        color: MoeTokens.titleText,
        fontSize: MoeTokens.textBase,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: MoeTokens.hintText,
          fontSize: MoeTokens.textBase,
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        isCollapsed: true,
      ),
      onSubmitted: onSubmitted,
    );
  }
}

/// 搜索页空态和未输入时的提示。
class CommunitySearchHint extends StatelessWidget {
  const CommunitySearchHint({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: MoeTokens.hintText),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.textLg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
